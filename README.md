# evergreen_holdings_gem
A ruby gem for getting information about copy availability from Evergreen ILS

[![Build Status](https://travis-ci.org/sandbergja/evergreen_holdings_gem.svg?branch=master)](https://travis-ci.org/sandbergja/evergreen_holdings_gem)
[![Coverage Status](https://coveralls.io/repos/github/sandbergja/evergreen_holdings_gem/badge.svg?branch=master)](https://coveralls.io/github/sandbergja/evergreen_holdings_gem?branch=master)

Quickstart
----------
Install and load this gem in an IRB session:

    $ [sudo] gem install evergreen_holdings
    $ irb
    >> require 'evergreen_holdings'

Start up a connection:

    conn = EvergreenHoldings::Connection.new 'http://libcat.linnbenton.edu'

Check on the availability for the TCN of your choosing:

    status = conn.get_holdings 1234
    
See if that TCN has any copies available:

    status.any_copies_available?
    => false

Print all the barcodes for the copies:

    status.copies.each do |copy|
        puts copy.barcode
    end
