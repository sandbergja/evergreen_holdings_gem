Gem::Specification.new do |s|
   s.name	= 'evergreen_holdings'
   s.homepage   = 'https://github.com/sandbergja/evergreen_holdings_gem'
   s.summary	= 'A ruby gem for getting information about copy availability from Evergreen ILS'
   s.version	= '0.4.0'
   s.date	= '2019-12-27'
   s.description	= 'Access holdings information from Evergreen ILS'
   s.authors	= ['Jane Sandberg']
   s.email	= 'sandbej@linnbenton.edu'
   s.files	= ['lib/evergreen_holdings.rb', 'lib/evergreen_holdings/errors.rb']
   s.test_files	= ['test/evergreen_holdings_test.rb']
   s.license	= 'MIT'
   s.add_runtime_dependency 'nokogiri', '~>1.11'
   s.add_development_dependency	'coveralls', '~>0.7.0'
   s.add_development_dependency	'minitest', '~>5.0.0'
   s.add_development_dependency	'rubocop', '>1.0.0', '<2'
end
