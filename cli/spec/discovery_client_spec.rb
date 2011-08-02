require 'rubygems'
require 'rspec'
require 'discovery_client'
require 'pp'


describe "DiscoverClient Tests" do

###
### Initialization
###

  
  DISCOVERY_URLS = ["http://discovery.example.com:1234", "http://zappdev1.eng.proofpoint.com:4111"]
  @logger = Logger.new(STDOUT)
  @logger.level = Logger::DEBUG

  dc = Discovery::Client.new({:DISCOVERY_URLS => DISCOVERY_URLS,
                              :LOGGER => @logger})

  it "Instantiate a discovery client" do
    dc.should_not be_nil
  end

  services = dc.get_services(nil, nil)
  @logger.debug("All services:")
  @logger.debug(services.inspect)
  it "Get the full list of services" do
    services.should_not be_nil
  end

  services = dc.get_services("smtp_service", "general")
  @logger.debug("smtp:general services:")
  @logger.debug(services.inspect)
  it "Get just smtp general pool services" do
    services.should_not be_nil
  end

  services = dc.get_services("smtp_service", nil)
  @logger.debug("All smtp services:")
  @logger.debug(services.inspect)
  it "Get all smtp services" do
    services.should_not be_nil
  end

  services = dc.get_services(nil, "general")
  @logger.debug("All general services:")
  @logger.debug(services.inspect)
  it "Get all general pool services" do
    services.should_not be_nil
  end

  static_id = dc.static_announce({
                      :environment => "zapp_ci",
                      :type => "dc_test",
                      :pool => "dc_pool",
                      :location => "dc_location",
                      :properties => {"firstProperty" => "firstValue"}})
  @logger.info("\nStatic announce ID: #{static_id}")
  it "Make a static announcement" do
    static_id.should_not be_nil
  end

  static_services = dc.get_static_services()
  it "Get static services" do
    static_services.should_not be_nil
  end

  dc.static_delete(static_id)
  @logger.info("Deleted #{static_id}\n")
  it "Delete a static announcement" do
    # If we git this far, no exceptions were raised.
    true.should be_true
  end

end