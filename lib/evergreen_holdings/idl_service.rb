# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'

DEFAULT_CLASSES = %i[acn acp acpl aou ccs circ]

module EvergreenHoldings
  # Fetches and parses the Evergreen IDL XML file
  class IdlService
    def initialize(evergreen_domain_or_xml_file)
      if evergreen_domain_or_xml_file.is_a? Nokogiri::XML::Document
        @raw_idl = evergreen_domain_or_xml_file
      else
        begin
          @raw_idl = Nokogiri::XML(open("#{evergreen_domain_or_xml_file}/reports/fm_IDL.xml"))
        rescue Errno::ECONNREFUSED, Net::ReadTimeout, OpenURI::HTTPError
          raise CouldNotConnectToEvergreenError
        end
      end
      parse_xml
    end

    def parse_xml(classes_to_process = DEFAULT_CLASSES)
      @classes = classes_to_process.map do |idl_class|
        fields = @raw_idl.xpath("//idl:class[@id='#{idl_class}']/idl:fields/idl:field", 'idl' => 'http://opensrf.org/spec/IDL/base/v1')
                     .map.with_index { |field, index| [field['name'], index] }
        [idl_class, fields.to_h]
      end.to_h
    end

    def sequence(klass, field)
      @classes[klass.to_sym][field.to_s]
    end
  end
end
