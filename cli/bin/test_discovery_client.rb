require 'rubygems'
require 'discovery_client'
require 'pp'

#dc = DiscoveryClient.new("http://zapp1.eng.proofpoint.com:4111", 2)
dc = DiscoveryClient.new(["http://localhost:8080", "http://foobar.example.com", "http://zapp1.eng.proofpoint.com:4111"], 1)

services = dc.get_services(nil, nil)
puts("All services:")
pp services

services = dc.get_services("user", "general")
puts("\n user:general services:")
pp services

services = dc.get_services("user", nil)
puts("\n All user services:")
pp services

services = dc.get_services(nil, "general")
puts("\n All general services:")
pp services

