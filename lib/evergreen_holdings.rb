require 'net/http'
require 'json'
require 'evergreen_holdings/errors'

OSRF_PATH = '/osrf-gateway-v1'

module EvergreenHoldings
    class Connection
        # Create a new object with the evergreen_domain
        # specified, e.g. http://libcat.linnbenton.edu
        #
        # Usage: `conn = EvergreenHoldings::Connection.new 'http://gapines.org'`
        def initialize evergreen_domain
            @gateway = URI evergreen_domain+OSRF_PATH
            unless fetch_statuses
                raise CouldNotConnectToEvergreenError
            end
	    fetch_ou_tree
        end

        # Fetch holdings data from the Evergreen server
        # Returns a Status object
        #
        # Usage: `stat = conn.get_holdings 23405`
        # If you just want holdings at a specific org_unit: `my_connection.get_holdings 23405, org_unit: 5`
        def get_holdings tcn, options = {}
            if options.key?(:org_unit)
                if options[:descendants]
                    params = "format=json&input_format=json&service=open-ils.cat&method=open-ils.cat.asset.copy_tree.retrieve&param=auth_token_not_needed_for_this_call&param=#{tcn}"
                    if @org_units[options[:org_unit]][:descendants]
                        @org_units[options[:org_unit]][:descendants].each do |ou|
                            params <<  + "&param=#{ou}"
                        end
                    end
                else
                    params = "format=json&input_format=json&service=open-ils.cat&method=open-ils.cat.asset.copy_tree.retrieve&param=auth_token_not_needed_for_this_call&param=#{tcn}&param=#{options[:org_unit]}"
                end
            else
                params = "format=json&input_format=json&service=open-ils.cat&method=open-ils.cat.asset.copy_tree.global.retrieve&param=auth_token_not_needed_for_this_call&param=#{tcn}"
            end
            @gateway.query = params

            res = send_query
            return Status.new res.body, self if res
        end

	# Given an ID, returns a human-readable name
        def location_name id
            params = "format=json&input_format=json&service=open-ils.circ&method=open-ils.circ.copy_location.retrieve&param=#{id}"
            @gateway.query = params
            res = send_query
            if res
                data = JSON.parse(res.body)['payload'][0]
                unless data.key? 'stacktrace'
                    return data['__p'][4]
                end
            end
            return id
        end

        def status_name id
            return @possible_item_statuses[id]
        end

	def ou_name id
            return @org_units[id][:name]
        end

        private

	def add_ou_descendants id, parent
            (@org_units[parent][:descendants] ||= []) << id
	    if @org_units[parent][:parent]
	    add_ou_descendants id, @org_units[parent][:parent]
	    end
	end

	def take_info_from_ou_tree o
	    @org_units[o[3]] = {}
	    @org_units[o[3]][:name] = o[6]
	    if o[8]
	        @org_units[o[3]][:parent] = o[8]
	        add_ou_descendants o[3], o[8]
            end
	    o[0].each do |p|
	        take_info_from_ou_tree p['__p']
	    end 
	end


        def send_query
            begin
                res = Net::HTTP.get_response(@gateway)
            rescue Errno::ECONNREFUSED, Net::ReadTimeout
                return nil
            end
            return res if res.is_a?(Net::HTTPSuccess)
            return nil
        end

        def fetch_statuses
            @possible_item_statuses = []
            params = 'format=json&input_format=json&service=open-ils.search&method=open-ils.search.config.copy_status.retrieve.all'
            @gateway.query = params
            res = send_query
            if res
                stats = JSON.parse(res.body)['payload'][0]
                stats.each do |stat|
                    @possible_item_statuses[stat['__p'][1]] = stat['__p'][2]
                end
                return true if stats.size > 0
            end
            return false
        end

        def fetch_ou_tree
            @org_units = {}
	    params = 'format=json&input_format=json&service=open-ils.actor&method=open-ils.actor.org_tree.retrieve'
            @gateway.query = params
            res = send_query
            if res
                raw_orgs = JSON.parse(res.body)['payload'][0]['__p']
		take_info_from_ou_tree raw_orgs
                return true if @org_units.size > 0
            end
            return false
        end

    end

    # Status objects represent all the holdings attached to a specific tcn
    class Status
        attr_reader :copies
        def initialize json_data, connection = nil
            @connection = connection
            @raw_data = JSON.parse(json_data)['payload'][0]
            @copies = extract_copies
            substitute_values_for_ids unless @connection.nil?
            @available_copies = []
            @next_copy_available = 'a date'
        end

        # Determines if any copies are available for your patrons
        def any_copies_available?
            @copies.each do |copy|
                return true if 0 == copy.status
                return true if 'Available' == copy.status
            end
            return false
        end

        private
        # Look through @raw_data and find the copies
        def extract_copies 
            copies = Array.new
            @raw_data.each do |vol|
                if vol['__p'][0].size > 0
                    vol['__p'][0].each do |item|
                        unless item['__p'][35].nil?
				copies.push Item.new barcode: item['__p'][2], call_number: vol['__p'][7], location: item['__p'][24], status: item['__p'][28], owning_lib: item['__p'][5]
                        else
                            begin
				    copies.push Item.new barcode: item['__p'][2], call_number: vol['__p'][7], due_date: item['__p'][35][0]['__p'][6], location: item['__p'][24], status: item['__p'][28], owning_lib: item['__p'][5]
                            rescue
				    puts item['__p'][5]
				    puts @org_units
				    copies.push Item.new barcode: item['__p'][2], call_number: vol['__p'][7], location: item['__p'][24], status: item['__p'][28], owning_lib: item['__p'][5]
                            end
                        end
                    end
                end
           end
           return copies
        end

        def substitute_values_for_ids
            @copies.each do |copy|
                if copy.location.is_a? Numeric
                    copy.location = @connection.location_name copy.location
                end
                if copy.status.is_a? Numeric
                    copy.status = @connection.status_name copy.status
                end
                if copy.owning_lib.is_a? Numeric
                    copy.owning_lib = @connection.ou_name copy.owning_lib
                end
            end
        end

    end

    # A physical copy of an item
    class Item
        attr_accessor :location, :status, :owning_lib
        attr_reader :barcode, :call_number
        def initialize data = {}
            data.each do |k,v|
                instance_variable_set("@#{k}", v) unless v.nil?
            end
        end
    end
end
