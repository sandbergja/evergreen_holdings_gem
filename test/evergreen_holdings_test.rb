require 'minitest/autorun'
require 'evergreen_holdings'

class EvergreenHoldingsTest < Minitest::Test
  def test_connecting_to_eg_returns_a_connection_object
    conn = EvergreenHoldings::Connection.new 'https://gapines.org'
    assert_instance_of EvergreenHoldings::Connection, conn
  end

  def test_connecting_to_a_404_throws_an_error
    assert_raises(CouldNotConnectToEvergreenError) do
      EvergreenHoldings::Connection.new('http://httpstat.us/404')
    end
  end

  def test_connecting_to_a_non_evergreen_server_throws_an_error
    assert_raises(CouldNotConnectToEvergreenError) do
      EvergreenHoldings::Connection.new('http://libfind.linnbenton.edu')
    end
  end

  def test_creates_valid_query_strings_for_accessing_the_copy_tree_api
    conn = EvergreenHoldings::Connection.new 'https://gapines.org'
    assert_equal 'format=json&input_format=json&'\
                 'service=open-ils.cat&method=open-ils.cat.asset.copy_tree.global.retrieve&'\
                 'param=auth_token_not_needed_for_this_call&param=123',
                 conn.copy_tree_query(123)
  end

end
