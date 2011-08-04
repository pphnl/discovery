# create by maven - leave it as is
Gem::Specification.new do |s|
  s.name = 'com.proofpoint.discovery.cli'
  s.version = "@DISCOVERY_GEM_VERSION@"

  s.summary = 'discovery'
  s.description = 'Discovery command line interface'
  s.homepage = 'https://github.com/psummers/discovery-server'

  s.authors = ['Team Zapp']
  s.email = ['x-teamzapp@proofpoint.com']

  s.rubyforge_project = 'discovery'
  s.files = Dir['bin/**/*']
  s.files += Dir['lib/**/*']
  s.executables << 'dcurl'
  s.executables << 'djconsole'
  s.executables << 'ddiscovery'
  s.executables << 'sdiscovery'
  s.add_dependency 'httpclient', '>=2.2.0'
  s.add_dependency 'json_pure', '>=1.5.1'
end
