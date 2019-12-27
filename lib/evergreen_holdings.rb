require 'net/http'
require 'json'
require 'evergreen_holdings/errors'
require 'nokogiri'
require 'open-uri'

OSRF_PATH = '/osrf-gateway-v1'

module EvergreenHoldings
    class Connection
        attr_reader :org_units
        # Create a new object with the evergreen_domain
        # specified, e.g. http://libcat.linnbenton.edu
        #
        # Usage: `conn = EvergreenHoldings::Connection.new 'http://gapines.org'`
        def initialize evergreen_domain
            @evergreen_domain = evergreen_domain
            @gateway = URI evergreen_domain+OSRF_PATH
            fetch_idl_order
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
            return Status.new res.body, @idl_order, self if res
        end

	# Given an ID, returns a human-readable name
        def location_name id
            params = "format=json&input_format=json&service=open-ils.circ&method=open-ils.circ.copy_location.retrieve&param=#{id}"
            @gateway.query = params
            res = send_query
            if res
                data = JSON.parse(res.body)['payload'][0]
                unless data.key? 'stacktrace'
                    return data['__p'][@idl_order[:acpl]['name']]
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
            id = o[@idl_order[:aou]['id']]
	    @org_units[id] = {}
	    @org_units[id][:name] = o[@idl_order[:aou]['name']]
	    if o[@idl_order[:aou]['parent_ou']]
	        @org_units[id][:parent] = o[@idl_order[:aou]['parent_ou']]
	        add_ou_descendants id, o[@idl_order[:aou]['parent_ou']]
            end
	    o[@idl_order[:aou]['children']].each do |p|
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

        def fetch_idl_order
            @idl_order = {}

            idl = Nokogiri::XML(open(@evergreen_domain + '/reports/fm_IDL.xml'))

            [:acn, :acp, :acpl, :aou, :ccs, :circ].each do |idl_class|
                i = 0
                @idl_order[idl_class] = {}
                fields = idl.xpath("//idl:class[@id='#{idl_class}']/idl:fields/idl:field", 'idl' => 'http://opensrf.org/spec/IDL/base/v1')
                fields.each do |field|
                    @idl_order[idl_class][field['name']] = i
                    i = i + 1
                end
            end
        end

        def fetch_statuses
            @possible_item_statuses = []
            params = 'format=json&input_format=json&service=open-ils.search&method=open-ils.search.config.copy_status.retrieve.all'
            @gateway.query = params
            res = send_query
            if res
                stats = JSON.parse(res.body)['payload'][0]
                stats.each do |stat|
                    @possible_item_statuses[stat['__p'][@idl_order[:ccs]['id']]] = stat['__p'][@idl_order[:ccs]['name']]
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
        attr_reader :copies, :libraries
        def initialize json_data, idl_order, connection = nil
            @idl_order = idl_order
            @connection = connection
            @raw_data = JSON.parse(json_data)['payload'][0]
            extract_copies
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
            @copies = Array.new
            @raw_data.each do |vol|
                if vol['__p'][0].size > 0
                    vol['__p'][0].each do |item|
			i = 0
                        item_info = {
                            barcode: item['__p'][@idl_order[:acp]['barcode']],
                            call_number: vol['__p'][@idl_order[:acn]['label']],
                            location: item['__p'][@idl_order[:acp]['location']],
                            status: item['__p'][@idl_order[:acp]['status']],
                            owning_lib: item['__p'][@idl_order[:acp]['circ_lib']],
                        }
                        unless item['__p'][@idl_order[:acp]['circulations']].is_a? Array
				@copies.push Item.new item_info
                        else
                            begin
                                    item_info[:due_date] = item['__p'][@idl_order[:acp]['circulations']][0]['__p'][@idl_order[:circ]['due_date']]
                            rescue
                            end
	                    @copies.push Item.new item_info
                        end
                    end
                end
           end
        end

        def substitute_values_for_ids
	    @libraries = @connection.org_units.clone
	    @libraries.each { |key, lib| lib[:copies] = Array.new }
            @copies.each do |copy|
                if copy.location.is_a? Numeric
                    copy.location = @connection.location_name copy.location
                end
                if copy.status.is_a? Numeric
                    copy.status = @connection.status_name copy.status
                end
                if copy.owning_lib.is_a? Numeric
                    ou_id = copy.owning_lib
                    copy.owning_lib = @connection.ou_name copy.owning_lib
                    @libraries[ou_id][:copies].push copy
                end
            end
        end

    end

    # A physical copy of an item
    class Item
        attr_accessor :location, :status, :owning_lib
        attr_reader :barcode, :call_number, :due_date
        def initialize data = {}
            data.each do |k,v|
                instance_variable_set("@#{k}", v) unless v.nil?
            end
        end
    end
end
