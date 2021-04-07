# frozen_string_literal: true

require 'minitest/autorun'
require 'evergreen_holdings/idl_parser'

class IDLParserTest < Minitest::Test
  def test_parses_idl_correctly
    parser = EvergreenHoldings::IDLParser.new Nokogiri::XML(File.open('test/fixtures/idl.xml'))
    expected = { acn: {
      'copies' => 0,
      'create_date' => 1,
      'creator' => 2,
      'deleted' => 3,
      'edit_date' => 4,
      'editor' => 5,
      'id' => 6,
      'label' => 7,
      'owning_lib' => 8,
      'record' => 9,
      'notes' => 10,
      'uri_maps' => 11,
      'uris' => 12,
      'label_sortkey' => 13,
      'label_class' => 14,
      'prefix' => 15,
      'suffix' => 16
    } }
    assert_equal(parser.field_order_by_class([:acn]), expected)
  end
end
