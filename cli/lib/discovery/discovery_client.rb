require 'rubygems'
require 'httpclient'
require 'json'
require 'uuidtools'

#
# This class mimics somewhat the structure of the Java discovery client.
#
class DiscoveryClient
  @verbose = false

  def initialize(discoveryUrl = "http://localhost:8080", verbose = false)
    @verbose = verbose
    puts "In constructor, #{discoveryUrl}, #{verbose}" if @verbose
    @discoveryUrl = discoveryUrl
    @serviceUri = URI.parse(@discoveryUrl).merge("/v1/service")
    @services = @environment = @service_data = nil
    @client = HTTPClient.new("")
  end

  #
  # Return list of services matching pool and type
  #
  def get_services (type, pool)
    query_for_services()
    result = []

    @service_data['services'].each do |service|
      if type.nil? || service['type'].eql?(type)
        result << service if pool.nil? || service['pool'].eql?(pool)
      end
    end

    return result
  end

  #
  # Return a list of HTTP paths for the given service
  #
  def get_http_services (serviceName)
    query_for_services()
    list = @services[serviceName]

    httpService = []
    list.each do |service|
      properties = service["properties"]
      if !properties.nil?()
        httpUri = properties["http"]
        httpService << httpUri unless httpUri.nil?()
      end
    end

    return httpService
  end

  #
  # Return a list of JDBC paths for the given service
  #
  def get_jdbc_services (serviceName)
    query_for_services()
    list = @services[serviceName]

    jdbcService = []
    list.each do |service|
      properties = service["properties"]
      if !properties.nil?()
        jdbcUri = properties["jdbc"]
        jdbcService << jdbcUri unless jdbcUri.nil?()
      end
    end

    return jdbcService
  end

  #
  # Return the Discovery environment name
  #
  def get_environment ()
    query_for_services()
    return @environment
  end

  #
  # announce
  #    PUT a service announcement to the discovery service in the
  #    pool "general" and environment "zapp_ci"
  #
  #    Params
  #
  #    service_type        The service type, e. g. smtp_service, user, customer, etc.
  #    service_properties  A hashmap of the service properties
  #
  #    Return
  #
  #    A UUID node ID used to identify this service.  This value can be passed to the
  #    delete method to delete the service announcement from the discovery server.
  #
  def announce(service_type, service_properties)
    announcement = {}
    service = {}
    nodeId =  UUIDTools::UUID.timestamp_create().to_s

    service["type"] = service_type
    service["properties"] = service_properties
    service["id"] = UUIDTools::UUID.timestamp_create().to_s
    serviceList = Array.new
    serviceList[0] = service

    # TODO: Parameterize pool and environment

    announcement["pool"] = "general"
    announcement["environment"] = "zapp_ci"
    announcement["services"] = serviceList

    announceUri = URI.parse(@discoveryUrl).merge("/v1/announcement/#{nodeId}")

    # Create announcement for specified service
    json = JSON.generate(announcement)
    if @verbose
      puts "Announce Request: " + announceUri.to_s
      puts "Announce Body: " + json
    end
    response = @client.put(announceUri.to_s, json, {'Content-Type' => 'application/json'})
    if @verbose
      puts "Announce response: " + response.to_s
    end
    if response.status < 200 || response.status > 300
      raise response.body
    end

    return nodeId
  end

  #
  # Delete the given nodeId from the service
  #
  def delete(nodeId)
    deleteUri = URI.parse(@discoveryUrl).merge("/v1/announcement/#{nodeId}")

    # Delete announcement for specified service
    if @verbose
      puts "Delete Request: " + deleteUri.to_s
    end
    response = @client.delete(deleteUri.to_s)
    if response.status < 200 || response.status > 300
      puts "Delete Announcement failed: " + deleteUri.to_s
      raise response
    end
  end


  private

  #
  # Do a GET against the discovery service for all services
  #
  def query_for_services()
    response = @client.get(@serviceUri.to_s, nil, nil)
    raise response.body if response.status < 200 || response.status > 300

    @service_data = JSON.parse(response.body)
    @environment = @service_data["environment"]
    @services = {}
    
    @service_data["services"].each do |service|
      serviceType = service["type"]
      if @services[serviceType].nil?
        @services[serviceType] = [service]
      else
        @services[serviceType] << service
      end
    end

  end
  
end