# frozen_string_literals: true

module EvergreenHoldings
  class IDLParser
    def initialize(idl)
      @idl = idl
    end

    def field_order_by_class(classes)
      classes.map do |idl_class|
        fields = @idl.xpath("//idl:class[@id='#{idl_class}']/idl:fields/idl:field", 'idl' => 'http://opensrf.org/spec/IDL/base/v1')
                     .map.with_index { |field, index| [field['name'], index] }
        [idl_class, fields.to_h]
      end.to_h
    end
  end
end
