require 'rubygems'
require 'discovery_client'
require 'pp'

#dc = DiscoveryClient.new("http://zapp1.eng.proofpoint.com:4111", 2)
dc = DiscoveryClient.new(["http://localhost:8080", "http://foobar.example.com", "http://zapp1.eng.proofpoint.com:4111"], 1)

services = dc.get_services(nil, nil)
puts("All services:")
pp services
puts("\n")

services = dc.get_services("smtp_service", "general")
puts("\n smtp:general services:")
pp services
puts("\n")

services = dc.get_services("smtp_service", nil)
puts("\nAll smtp services:")
pp services
puts("\n")

services = dc.get_services(nil, "general")
puts("\nAll general services:")
pp services

static_id = dc.static_announce({
                    :environment => "zapp_integration",
                    :type => "dc_test",
                    :pool => "dc_pool",
                    :location => "dc_location",
                    :properties => {"firstProperty" => "firstValue"}})

puts("\nStatic announce ID: #{static_id}")
puts("\n")

dc.static_delete(static_id)
puts("Deleted #{static_id}\n")
