Gem::Specification.new do |s|
  s.name	= 'evergreen_holdings'
  s.homepage = 'https://github.com/sandbergja/evergreen_holdings_gem'
  s.summary	= 'A ruby gem for getting information about copy availability from Evergreen ILS'
  s.version	= '0.5.0'
  s.date	= '2021-04-07'
  s.description	= 'Access holdings information from Evergreen ILS'
  s.authors	= ['Jane Sandberg']
  s.email	= 'sandbej@linnbenton.edu'
  s.files	= Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  s.test_files	= ['test/evergreen_holdings_test.rb']
  s.license	= 'MIT'
  s.add_runtime_dependency 'nokogiri', '~>1.11'
  s.add_development_dependency	'minitest', '~>5.0.0'
  s.add_development_dependency	'rake'
  s.add_development_dependency	'rubocop', '>1.0.0', '<2'
end
