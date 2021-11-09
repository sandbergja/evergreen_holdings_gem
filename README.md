# evergreen_holdings_gem
A ruby gem for getting information about copy availability from Evergreen ILS

[![Gem Version](https://badge.fury.io/rb/evergreen_holdings.svg)](https://badge.fury.io/rb/evergreen_holdings)

Quickstart
----------
Install and load this gem in an IRB session:

    $ [sudo] gem install evergreen_holdings
    $ irb
    >> require 'evergreen_holdings'

Start up a connection:

    conn = EvergreenHoldings::Connection.new 'https://libcat.linnbenton.edu'

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

My controller grabs an instance from the cache (in-memory, memcached, or whichever cache you prefer):

    @evergreen_connection = Rails.cache.fetch('evergreen_connection', expires_in: 1.day) do
      EvergreenHoldings::Connection.new 'https://libcat.linnbenton.edu'
    end

Then, I pass around `evergreen_connection` to every place on the page that needs it, to take advantage of some internal caching that happens in the individual instance.

And of course, it's nice to cache the results too, to avoid needing to fetch them again:

    Rails.cache.fetch("evergreen-#{bib_id}", expires_in: 1.day) do
      @evergreen_connection.get_holdings bib_id
    end

Development
-----------

From within this repo:

. Run `bundle` to install the dependencies for this gem.
. Run `bin/console` to get a console with this gem loaded.
. Run `bundle exec rake test` to run the test suite.
