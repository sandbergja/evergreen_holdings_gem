# evergreen_holdings_gem
A ruby gem for getting information about copy availability from Evergreen ILS

[![Build Status](https://travis-ci.org/sandbergja/evergreen_holdings_gem.svg?branch=master)](https://travis-ci.org/sandbergja/evergreen_holdings_gem)
[![Coverage Status](https://coveralls.io/repos/github/sandbergja/evergreen_holdings_gem/badge.svg?branch=master)](https://coveralls.io/github/sandbergja/evergreen_holdings_gem?branch=master)
[![Gem Version](https://badge.fury.io/rb/evergreen_holdings.svg)](https://badge.fury.io/rb/evergreen_holdings)

Quickstart
----------
Install and load this gem in an IRB session:

    $ [sudo] gem install evergreen_holdings
    $ irb
    >> require 'evergreen_holdings'

Start up a connection:

    conn = EvergreenHoldings::Connection.new 'http://libcat.linnbenton.edu'

Check on the availability for the Record ID of your choosing:

    status = conn.get_holdings 1234
    
You can limit results to a specific org unit (given its database ID):

    status = conn.get_holdings 1234, org_unit: 17

And you can also limit to an org unit and its descendants:

    status = conn.get_holdings 1234, org_unit: 17, descendants: true

See if that Record ID has any copies available:

    status.any_copies_available?
    => false

Print all the barcodes for the copies:

    status.copies.each do |copy|
        puts copy.barcode
    end

Using this gem in a Rails app
----------
The primary use case I had in mind for this gem is for Blacklight-based discovery layers that want to get
copy/availability information to their patrons.  Here's how I use this gem in my institution's discovery layer.

I include `gem 'evergreen_holdings'` in my Gemfile

There is no need to create a new connection for each holdings request.  I create a new Connection for each session by including the following in my application controller.  There shouldn't even be a need to create it for each session, theoretically.

      begin
          session[:evergreen_connection] = EvergreenHoldings::Connection.new 'http://libcat.linnbenton.edu'
      rescue CouldNotConnectToEvergreenError
          session[:evergreen_connection] = nil
      end
 
The rescue statement ensures that if Evergreen is down for some reason, it doesn't take my rails app down with it.  Since I store the connection object in the session variable, I have to rely on ActiveRecord sessions, rather than Rails' default cookie system.

I then make status requests as needed and create views code accordingly.

Run tests
---------

Just run `rake test`
