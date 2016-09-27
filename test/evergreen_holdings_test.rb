require 'coveralls'
Coveralls.wear!
require 'minitest/autorun'
require 'evergreen_holdings'

class EvergreenHoldingsTest < Minitest::Test
    def test_connecting_to_eg_returns_a_connection_object
        conn = EvergreenHoldings::Connection.new 'http://gapines.org'
        assert_instance_of EvergreenHoldings::Connection, conn
    end
    def test_connecting_to_a_404_throws_an_error
        assert_raises('CouldNotConnectToEvergreenError') {
            EvergreenHoldings::Connection.new('http://httpstat.us/404')
        }
    end
    def test_connecting_to_a_non_evergreen_server_throws_an_error
        assert_raises('CouldNotConnectToEvergreenError') {
            EvergreenHoldings::Connection.new('http://libfind.linnbenton.edu')
        }
    end
end
