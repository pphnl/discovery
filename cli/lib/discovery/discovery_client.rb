require 'rubygems'
require 'httpclient'
require 'json'
require 'Logger'

#
# Provide rudimentary, one-shot access to the discovery service.
#
module Discovery
  class Client

    #
    # Constructor takes a hash of parameters:
    #
    #    :DISCOVERY_URLS    list of discovery service base URLs
    #    :LOG_LEVEL         Optional Integer logging level corresponding with the Ruby
    ##                      Logger logging levals (DEBUG = 0, INFO =1,
    #                       WARN = 2, ERROR = 3, FATAL = 4, UNKNOWN = 5)
    #                       A new Ruby Logger object will be created at the given level.
    #   :LOGGER             Optional Ruby Logger object, overrides :VERBOSITY
    #
    def initialize(params)
       @discovery_urls = params[:DISCOVERY_URLS]
       raise "Must specify list of discovery service URLS" if @discovery_urls.nil?
       @logger = params[:LOGGER]
       if @logger.nil?
         @logger = Logger.new(STDOUT)
         level = params[:VERBOSITY]
         level ||= Logger::UNKNOWN
         @logger.level = level
       end

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

      if !pool.nil? && type.nil?
        query_for_services()
        result = []

        @service_data['services'].each do |service|
          if type.nil? || service['type'].eql?(type)
            result << service if pool.nil? || service['pool'].eql?(pool)
          end
        end

        return result
      end

      query_for_services(type, pool)
      return @service_data["services"]
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
    #    POST a static service announcement to the discovery service
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

        json = announcement.to_json
        @logger.debug("Announce Request: #{announce_uri.to_s}")
        @logger.debug("Announce Body: #{json}")

        begin
          response = @client.post(announce_uri.to_s, json, {'Content-Type' => 'application/json'})
          if response.status >= 200 && response.status <= 299
            data = JSON.parse(response.body)
            return data["id"]
          end

          @logger.error("#{announce_uri.to_s}: Response Status #{response.status}")
          @logger.error(response.body)

        rescue
          @logger.error("#{announce_uri.to_s}: #{$!}")
        end
      end

      raise "Failed to do business with any of [ #{@discovery_urls.join(",")} ]"

    end

    #
    # DELETE the given nodeId from the service
    #
    def static_delete(nodeId)

      raise "NodeId must not be nil" if nodeId.nil?

      @discovery_urls.each do |discovery_url|

        delete_uri = URI.parse(discovery_url).merge("/v1/announcement/static/#{nodeId}")

        @logger.debug("Delete Request: #{delete_uri.to_s}")

        begin
          response = @client.delete(delete_uri.to_s)
          if response.status >= 200 && response.status <= 299
            return
          end

          @logger.error("#{delete_uri.to_s}: Response Status #{response.status}")
          @logger.error(response.body)

        rescue
          @logger.error("#{delete_uri.to_s}: #{$!}")
        end

      end

      raise "Failed to do business with any of [ #{@discovery_urls.join(",")} ]"

    end


    private

    #
    # GET the contents of the discovery service
    #
    # The REST API will support /type, and /type/pool queries,
    # so if type is nil, pool must not be nil
    #
    def query_for_services(type = nil, pool = nil)

      raise "Type must not be nil if pool is nil" if type.nil? && !pool.nil?

      @discovery_urls.each do |discovery_url|
        resource = "/v1/service"
        resource += "/#{type}" if ! type.nil?
        resource += "/#{pool}" if ! pool.nil?

        service_uri = URI.parse(discovery_url).merge(resource)

        @logger.debug("Get Request: #{service_uri.to_s}")

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

          @logger.error("#{service_uri.to_s}: Response Status #{response.status}")
          @logger.error(response.body)

        rescue
          @logger.error("#{service_uri.to_s}: #{$!}")
        end

    end

      raise "Failed to do business with any of [ #{@discovery_urls.join(",")} ]"

    end

  end
end