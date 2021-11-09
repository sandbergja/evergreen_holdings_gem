# frozen_string_literal: true

require 'net/http'
require 'json'
require 'evergreen_holdings/errors'
require 'evergreen_holdings/idl_object'
require 'evergreen_holdings/idl_service'
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
    def initialize(evergreen_domain)
      @evergreen_domain = evergreen_domain
      @gateway = URI evergreen_domain + OSRF_PATH
      @acpl_cache = {}
      fetch_idl_order
      raise CouldNotConnectToEvergreenError unless fetch_statuses

      fetch_ou_tree
    end

    # Create a query string to run against an OpenSRF gateway
    # Returns a string
    def copy_tree_query(bib_id, options = {})
      method = "open-ils.cat.asset.copy_tree.#{'global.' unless options.key?(:org_unit)}retrieve"
      params = 'format=json&input_format=json&'\
               "service=open-ils.cat&method=#{method}&"\
               "param=auth_token_not_needed_for_this_call&param=#{bib_id}"
      return params unless options.key?(:org_unit)

      params << if options[:descendants]
                  @org_units[options[:org_unit]][:descendants]&.map { |ou| "&param=#{ou}" }&.join
                else
                  "&param=#{options[:org_unit]}"
                end
    end

    # Fetch holdings data from the Evergreen server
    # Returns a Status object
    #
    # Usage: `stat = conn.get_holdings 23405`
    # If you just want holdings at a specific org_unit: `my_connection.get_holdings 23405, org_unit: 5`
    def get_holdings(bib_id, options = {})
      @gateway.query = copy_tree_query(bib_id, options)
      res = send_query
      return Status.new res.body, @idl_service, self if res
    end

    # Given an ID, returns a human-readable name
    def location_name(id)
      @acpl_cache.fetch(id) { |id| fetch_new_acpl(id) || id }
    end

    def status_name(id)
      @possible_item_statuses[id]
    end

    def ou_name(id)
      @org_units[id][:name]
    end

    private

    def add_ou_descendants(id, parent)
      (@org_units[parent][:descendants] ||= []) << id
      add_ou_descendants id, @org_units[parent][:parent] if @org_units[parent][:parent]
    end

    def take_info_from_ou_tree(o)
      org = IdlObject.new(:aou, o, @idl_service)
      id = org.get 'id'
      @org_units[id] = {}
      @org_units[id][:name] = org.get 'name'
      if org.get 'parent_ou'
        @org_units[id][:parent] = org.get 'parent_ou'
        add_ou_descendants id, org.get('parent_ou')
      end
      org.get('children').each do |p|
        take_info_from_ou_tree p['__p']
      end
    end

    # Given the ID of a shelving location, this method
    # finds the name of the location, caches it, and
    # returns it
    def fetch_new_acpl(id)
      params = "format=json&input_format=json&service=open-ils.circ&method=open-ils.circ.copy_location.retrieve&param=#{id}"
      @gateway.query = params
      res = send_query
      if res
        data = JSON.parse(res.body)['payload'][0]
        name = IdlObject.new(:acpl, data['__p'], @idl_service).get('name') unless data.key? 'stacktrace'
        @acpl_cache[id] = name
        return name if name
      end
      false
    end

    def send_query
      begin
        res = Net::HTTP.get_response(@gateway)
      rescue Errno::ECONNREFUSED, Net::ReadTimeout
        return nil
      end
      return res if res.is_a?(Net::HTTPSuccess)

      nil
    end

    def fetch_idl_order
      @idl_service = EvergreenHoldings::IdlService.new(@evergreen_domain)
    end

    def fetch_statuses
      @possible_item_statuses = []
      params = 'format=json&input_format=json&service=open-ils.search&method=open-ils.search.config.copy_status.retrieve.all'
      @gateway.query = params
      res = send_query
      if res
        stats = JSON.parse(res.body)['payload'][0]
        stats.each do |stat|
          ccs = IdlObject.new(:ccs, stat['__p'], @idl_service)
          @possible_item_statuses[ccs.get('id')] = ccs.get('name')
        end
        return true unless stats.empty?
      end
      false
    end

    def fetch_ou_tree
      @org_units = {}
      params = 'format=json&input_format=json&service=open-ils.actor&method=open-ils.actor.org_tree.retrieve'
      @gateway.query = params
      res = send_query
      if res
        raw_orgs = JSON.parse(res.body)['payload'][0]['__p']
        take_info_from_ou_tree raw_orgs
        return true unless @org_units.empty?
      end
      false
    end
  end

  # Status objects represent all the holdings attached to a specific bib id
  class Status
    attr_reader :copies, :libraries

    def initialize(json_data, idl_service, connection = nil)
      @idl_service = idl_service
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
        return true if copy.status == 'Available'
      end
      false
    end

    private

    # Look through @raw_data and find the copies
    def extract_copies
      @copies = []
      @raw_data.each do |call_number|
        next if call_number['__p'][0].empty?

        call_number['__p'][0].each do |item|
          item_data = IdlObject.new :acp, item['__p'], @idl_service
          call_number_data = IdlObject.new :acn, call_number['__p'], @idl_service
          item_info = {
            barcode: item_data.get('barcode'),
            call_number: call_number_data.get('label'),
            location: item_data.get('location'),
            status: item_data.get('status'),
            owning_lib: item_data.get('circ_lib'),
            circ_modifier: item_data.get('circ_modifier')
          }
          if item_data.get('circulations').is_a? Array
            begin
              circ = IdlObject.new :circ, item_data.get('circulations').first['__p'], @idl_service
              item_info[:due_date] = circ.get 'due_date'
            rescue StandardError
            end
            @copies.push Item.new item_info
          else
            @copies.push Item.new item_info
          end
        end
      end
    end

    def substitute_values_for_ids
      @libraries = @connection.org_units.clone
      @libraries.each { |_key, lib| lib[:copies] = [] }
      @copies.each do |copy|
        copy.location = @connection.location_name copy.location if copy.location.is_a? Numeric
        copy.status = @connection.status_name copy.status if copy.status.is_a? Numeric
        next unless copy.owning_lib.is_a? Numeric

        ou_id = copy.owning_lib
        copy.owning_lib = @connection.ou_name copy.owning_lib
        @libraries[ou_id][:copies].push copy
      end
    end
  end

  # A physical copy of an item
  class Item
    attr_accessor :location, :status, :owning_lib
    attr_reader :barcode, :call_number, :circ_modifier, :due_date

    def initialize(data = {})
      data.each do |k, v|
        instance_variable_set("@#{k}", v) unless v.nil?
      end
    end
  end
end
