Gem::Specification.new do |s|
   s.name	= 'evergreen_holdings'
   s.summary	= 'A ruby gem for getting information about copy availability from Evergreen ILS'
   s.version	= '0.1.6'
   s.date	= '2017-04-18'
   s.description	= 'Access holdings information from Evergreen ILS'
   s.authors	= ['Jane Sandberg']
   s.email	= 'sandbej@linnbenton.edu'
   s.files	= ['lib/evergreen_holdings.rb', 'lib/evergreen_holdings/errors.rb']
   s.test_files	= ['test/evergreen_holdings_test.rb']
   s.license	= 'MIT'
   s.add_development_dependency	'minitest'
   s.add_development_dependency	'coveralls', '0.7.0'
end
