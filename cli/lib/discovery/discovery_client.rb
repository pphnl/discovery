require 'rubygems'
require 'httpclient'
require 'json'
require 'uuidtools'

#
# This class mimics somewhat the structure of the Java discovery client.
#
class DiscoveryClient

  #
  # Constructor takes a scalar or list of service base URLs, and a verbosity flag
  # Verbosity = 0: Run silent
  # Verbosity = 1: Print errors
  # Verbosity = 2: Print debug and errors
  #
  def initialize(discoveryUrls, verbose = 0)
     @discovery_urls = discoveryUrls.class.eql?(Array) ? discoveryUrls : [discoveryUrls]
     @verbose = verbose

     @services = nil
     @service_data = nil
     @client = HTTPClient.new("")
  end

  #
  # Return list of services matching pool and type
  # nil values for pool and type act as wild cards
  #
  def get_services (type = nil, pool = nil)

    # NOTE: query_for_services asks for everything, rather than using the
    #       more selective resource paths provided by the discovery services.
    #       This allows the user to query for all services in a given pool,
    #       which is not an available resource path
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
  def get_http_services (service_name)
    query_for_services()
    list = @services[service_name]

    http_service = []
    list.each do |service|
      properties = service["properties"]
      if !properties.nil?()
        http_uri = properties["http"]
        http_service << http_uri unless http_uri.nil?()
      end
    end

    return http_service
  end

  #
  # Return a list of JDBC paths for the given service
  #
  def get_jdbc_services (service_name)
    query_for_services()
    list = @services[service_name]

    jdbc_service = []
    list.each do |service|
      properties = service["properties"]
      if !properties.nil?()
        jdbc_uri = properties["jdbc"]
        jdbc_service << jdbc_uri unless jdbc_uri.nil?()
      end
    end

    return jdbc_service
  end

  #
  # Return the Discovery environment name
  #
  def get_environment ()
    query_for_services()
    return @service_data["environment"]
  end

  #
  # static_announce
  #    PUT a service announcement to the discovery service
  #
  #    Params - a single hash containing the following elements:
  #
  #    :pool                The pool for this service
  #    :environment         The service environment
  #    :type                The service type, e. g. smtp_service, user, customer, etc.
  #    :properties          A hashmap of the service properties
  #    :location            Service location
  #
  #    Return
  #
  #    A UUID node ID used to identify this service.  This value can be passed to the
  #    delete method to delete the service announcement from the discovery server.
  #
  def static_announce(params)
    assertion_fails = Array.new
    assertion_fails << "params[:pool] must not be nil" if params[:pool].nil?
    assertion_fails << "params[:environment] must not be nil" if params[:environment].nil?
    assertion_fails << "params[:type] must not be nil" if params[:type].nil?
    assertion_fails << "params[:properties] must not be nil" if params[:properties].nil?
    assertion_fails << "params[:location] must not be nil" if params[:location].nil?
    
    raise assertion_fails if assertion_fails.size > 0

    announcement = {}
    announcement["pool"] = params[:pool]
    announcement["environment"] = params[:environment]
    announcement["type"] = params[:type]
    announcement["properties"] = params[:properties]
    announcement["location"] = params[:location]

    @discovery_urls.each do |discovery_url|

      announce_uri = URI.parse(discovery_url).merge("/v1/announcement/static")

      json = JSON.generate(announcement)
      if @verbose > 1
        puts "Announce Request: " + announce_uri.to_s
        puts "Announce Body: " + json
      end

      begin
        response = @client.post(announce_uri.to_s, json, {'Content-Type' => 'application/json'})
        if response.status >= 200 && response.status <= 299
          data = JSON.parse(response.body)
          return data["id"]
        end

        if @verbose > 0
          $stderr.puts("#{announce_uri.to_s}: Response Status #{response.status}")
          $stderr.puts(response.body)
          $stderr.flush
        end

      rescue
        if @verbose > 0
          $stderr.puts("#{announce_uri.to_s}: #{$!}")
          $stderr.flush
        end
      end
    end

    raise "Failed to do business with any of [ #{@discovery_urls.join(",")} ]"

  end

  #
  # Delete the given nodeId from the service
  #
  def static_delete(nodeId)

    raise "NodeId must not be nil" if nodeId.nil?

    @discovery_urls.each do |discovery_url|

      delete_uri = URI.parse(discovery_url).merge("/v1/announcement/static/#{nodeId}")

      puts "Delete Request: " + delete_uri.to_s if @verbose > 1

      begin
        response = @client.delete(delete_uri.to_s)
        if response.status >= 200 && response.status <= 299
          return
        end

        if @verbose > 0
          $stderr.puts("#{delete_uri.to_s}: Response Status #{response.status}")
          $stderr.puts(response.body)
          $stderr.flush
        end

      rescue
        if @verbose > 0
          $stderr.puts("#{delete_uri.to_s}: #{$!}")
          $stderr.flush
        end
      end

    end

    raise "Failed to do business with any of [ #{@discovery_urls.join(",")} ]"

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

          if @verbose > 0
            $stderr.puts("#{service_uri.to_s}: Response Status #{response.status}")
            $stderr.puts(response.body)
            $stderr.flush
          end

        rescue
          if @verbose > 0
            $stderr.puts("#{service_uri.to_s}: #{$!}")
            $stderr.flush
          end
        end

     end

    raise "Failed to do business with any of [ #{@discovery_urls.join(",")} ]"

  end
  
end