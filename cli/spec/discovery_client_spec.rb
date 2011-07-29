require 'rubygems'
require 'rspec'
require 'discovery_client'
require 'pp'


describe "DiscoverClient Tests" do

###
### Initialization
###

  
  DISCOVERY_URLS = ["http://discovery.example.com:1234", "http://zapp1.eng.proofpoint.com:4111"]

  verbose = 1

  dc = DiscoveryClient.new(DISCOVERY_URLS, verbose)
  it "Instantiate a discovery client" do
    dc.should_not be_nil
  end

  services = dc.get_services(nil, nil)
  it "Get the full list of services" do
    services.should_not be_nil
    if verbose > 1
      puts("All services:")
      pp services
      puts("\n")
    end
  end

  services = dc.get_services("smtp_service", "general")
  it "Get just smtp general pool services" do
    services.should_not be_nil
    if verbose > 1
      puts("\n smtp:general services:")
      pp services
      puts("\n")
    end
  end

  services = dc.get_services("smtp_service", nil)
  it "Get all smtp services" do
    services.should_not be_nil
    if verbose > 1
      puts("\nAll smtp services:")
      pp services
      puts("\n")
    end
  end

  services = dc.get_services(nil, "general")
  it "Get all general pool services" do
    services.should_not be_nil
    if verbose > 1
      puts("\nAll general services:")
      pp services
      puts("\n")
    end
  end

  static_id = dc.static_announce({
                      :environment => "zapp_integration",
                      :type => "dc_test",
                      :pool => "dc_pool",
                      :location => "dc_location",
                      :properties => {"firstProperty" => "firstValue"}})
  it "Make a static announcement" do
    static_id.should_not be_nil=
    if verbose > 1
    puts("\nStatic announce ID: #{static_id}")
    puts("\n")
    end
  end

  dc.static_delete(static_id)
  it "Delete a static announcement" do
    puts("Deleted #{static_id}\n") if verbose > 1
  end

end