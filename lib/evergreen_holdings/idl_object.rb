# frozen_string_literal: true

class IdlObject
  def initialize(klass, data, idl_service)
    @klass = klass
    @data = data
    @idl_service = idl_service
  end

  def get(field)
    sequence = @idl_service.sequence @klass, field
    @data[sequence]
  end
end