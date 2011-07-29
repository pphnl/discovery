require 'rubygems'
require 'httpclient'
require 'json'
require 'uuidtools'

#
# This class mimics somewhat the structure of the Java discovery client.
#
class DiscoveryClient
  @verbose = false

  #
  # Constructor takes a scalar or list of service base URLs, and a verbosity flag
  # Verbosity = 0: Run silent
  # Verbosity = 1: Print errors
  # Verbosity = 2: Print debug and errors
  #
  def initialize(discoveryUrls, verbose = 0)
     @verbose = verbose
     @discovery_urls = discoveryUrls.class.eql?(Array) ? discoveryUrls : [discoveryUrls]
     @services = @environment = @service_data = nil
     @client = HTTPClient.new("")
  end

  #
  # Return list of services matching pool and type
  # nil values for pool and type act as wild cards
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
  #    TODO: pool and environment need to be parameterized
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

     @discovery_urls.each do |discovery_url|

        announce_uri = URI.parse(discovery_url).merge("/v1/announcement/#{nodeId}")

        json = JSON.generate(announcement)
        if @verbose > 1
          puts "Announce Request: " + announce_uri.to_s
          puts "Announce Body: " + json
        end

        begin
          response = @client.put(announce_uri.to_s, json, {'Content-Type' => 'application/json'})
          if response.status >= 200 && response.status <= 299
            return nodeId
          end

          stderr.puts("#{announce_uri.to_ss}: Reponse Status #{response.status}") if @verbose > 0

        rescue
          $stderr.puts("#{announce_uri.to_s}: #{$!}") if @verbose > 0
        end
    end

    raise "Could not communicate with any of [ #{@discovery_urls.join(",")} ]"

  end

  #
  # Delete the given nodeId from the service
  #
  def delete(nodeId)

    @discovery_urls.each do |discovery_url|

      delete_uri = URI.parse(discovery_url).merge("/v1/announcement/#{nodeId}")

      puts "Delete Request: " + delete_uri.to_s if @verbose > 1

      begin
        response = @client.delete(delete_uri.to_s)
        if response.status >= 200 && response.status <= 299
          return
        end

        stderr.puts("#{delete_uri.to_s}: Response Status #{response.status}") if @verbose > 0

      rescue
        $stderr.puts("#{delete_uri.to_s}: #{$!}") if @verbose > 0
      end

    end

    raise "Could not communicate with any of [ #{@discovery_urls.join(",")} ]"

  end


  private

  #
  # Do a GET against the discovery service until one succeeds
  #
  def query_for_services()

     @discovery_urls.each do |discovery_url|
        service_uri = URI.parse(discovery_url).merge("/v1/service")

        puts "Get Request: " + service_uri.to_s if @verbose > 1

        begin
          response = @client.get(service_uri.to_s, nil, nil)

          if response.status >= 200 && response.status <= 299
             @service_data = JSON.parse(response.body)
             @environment = @service_data["environment"]
             @services = {}

             @service_data["services"].each do |service|
               service_type = service["type"]
               if @services[service_type].nil?
                 @services[service_type] = [service]
               else
                 @services[service_type] << service
               end
             end

             return
          end

          $stderr.puts("#{service_uri.to_s}: Response Status #{response.status}") if @verbose > 0

        rescue
          $stderr.puts("#{service_uri.to_s}: #{$!}") if @verbose > 0
        end

     end

    raise "Could not communicate with any of [ #{@discovery_urls.join(",")} ]"

  end
  
end