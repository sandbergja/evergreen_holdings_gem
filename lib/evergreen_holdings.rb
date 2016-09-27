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
        end

        # Fetch holdings data from the Evergreen server
        # Returns a Status object
        #
        # Usage: `stat = conn.get_holdings 23405`
        # If you just want holdings at a specific org_unit: `my_connection.get_holdings 23405, org_unit: 5`
        def get_holdings tcn, options = {}
            if options.key?(:org_unit)
                params = "format=json&input_format=json&service=open-ils.cat&method=open-ils.cat.asset.copy_tree.retrieve&param=auth_token_not_needed_for_this_call&param=#{tcn}&param=#{options[:org_unit]}"
            else
                params = "format=json&input_format=json&service=open-ils.cat&method=open-ils.cat.asset.copy_tree.global.retrieve&param=auth_token_not_needed_for_this_call&param=#{tcn}"
            end
            @gateway.query = params

            res = Net::HTTP.get_response(@gateway)
            return Status.new res.body, self if res.is_a?(Net::HTTPSuccess)
        end

        def location_name id
            params = "format=json&input_format=json&service=open-ils.circ&method=open-ils.circ.copy_location.retrieve&param=#{id}"
            @gateway.query = params
            res = Net::HTTP.get_response(@gateway)
            if res.is_a? Net::HTTPSuccess
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

        private

        def fetch_statuses
            @possible_item_statuses = []
            params = 'format=json&input_format=json&service=open-ils.search&method=open-ils.search.config.copy_status.retrieve.all'
            @gateway.query = params
            res = Net::HTTP.get_response(@gateway)
            if res.is_a?(Net::HTTPSuccess)
                stats = JSON.parse(res.body)['payload'][0]
                stats.each do |stat|
                    @possible_item_statuses[stat['__p'][1]] = stat['__p'][2]
                end
                return true if stats.size > 0
            end
            return false
        end

    end

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
        end

        private
        # Look through @raw_data and find the copies
        def extract_copies 
            copies = Array.new
            @raw_data.each do |vol|
                if vol['__p'][0].size > 0
                    vol['__p'][0].each do |item|
                        unless item['__p'][35].nil?
                            copies.push Item.new barcode: item['__p'][2], call_number: vol['__p'][7], location: item['__p'][24], status: item['__p'][28]
                        else
                            begin
                                copies.push Item.new barcode: item['__p'][2], call_number: vol['__p'][7], due_date: item['__p'][35][0]['__p'][6], location: item['__p'][24], status: item['__p'][28]
                            rescue
                                copies.push Item.new barcode: item['__p'][2], call_number: vol['__p'][7], location: item['__p'][24], status: item['__p'][28]
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
            end
        end

    end

    class Item
        attr_accessor :location, :status
        attr_reader :barcode, :call_number
        def initialize data = {}
            data.each do |k,v|
                instance_variable_set("@#{k}", v) unless v.nil?
            end
        end
    end
end
