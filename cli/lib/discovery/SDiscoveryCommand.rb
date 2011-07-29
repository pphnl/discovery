require 'rubygems'
require 'optparse'
require 'json'

# CLI parser for sdiscovery

class SDiscoveryCommand
  @option_map
  @json_map
  @hosts
  @id
  @static_announcement
  @help_message
  @show_parser
  @add_parser
  @delete_parser

  attr_reader :option_map, :json_map, :hosts, :id, :static_announcement, :help_message
  def command ()
    return @option_map[:command]
  end

  # Returns true if help was requested and there's help in help_message
  def help?()
    return @help_message ? true : false
  end

  def initialize (args)
    @option_map = {}
    @json_map = {}

    @show_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{opts.program_name()} show alias|URL [OUTPUT_OPTION]"

      opts.on('-h', '--help', 'Display this screen') do
        @help_message= help()
      end

      opts.on('--output FMT', '-o', ['JSON', 'ID'], 'Output option: format JSON or ID') do |value|
        @option_map[:output]=value
      end
    end

    @add_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{opts.program_name()} add alias|URL [OUTPUT_OPTION] SERVICE_DEFINITION"

      opts.on('-h', '--help', 'Display this screen') do
        @help_message= help()
      end

      opts.on('--output FMT', '-o', ['JSON', 'ID'], 'Output option: format JSON or ID') do |value|
        @option_map[:output]=value
      end

      opts.on('--environment ENVIRONMENT', '-e', "Service definition: environment") do |value|
        @json_map[:environment]=value
      end

      opts.on('--type TYPE', '-t', "Service definition: type") do |value|
        @json_map[:type]=value
      end

      opts.on('--pool POOL', '-p', "Service definition: pool") do |value|
        @json_map[:pool]=value
      end

      opts.on('--location LOCATION', '-l', "Service definition: location") do |value|
        @json_map[:location]=value
      end

      opts.on('-Dkey=value', "Service definition: Add key=value property") do
        #Used only for help.  OptionParser doesn't support this format.
      end

      opts.on('--JSON JSON', '-j', "Service definition: Specify entire raw JSON data") do |value|
        @option_map[:json]=value
      end

      opts.on('--JSONFile JSONFile', '-f', "Service definition: Specify entire raw JSON data filename or '-' for stdin") do |value|
        @option_map[:jsonfile]=value
      end
    end


    @delete_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{opts.program_name()} delete alias|URL ID"

      opts.on('-h', '--help', 'Display this screen') do
        @help_message= help()
      end
    end


    @option_map[:command]= (args.shift() || "?").upcase()

    case @option_map[:command]
      when "ADD"
        parse_add_command (args)
      when "SHOW"
        parse_show_command (args)
      when "DELETE"
        parse_delete_command (args)
      else
        @help_message= "#{@show_parser}#{@add_parser}#{@delete_parser}\n"
    end
  end

  private

  # Exit for missing argument
  def err_missing (message, usage)
    raise "Missing argument --#{message}\n#{usage}"
  end

  # Exit for extra k/v arguments
  def err_extra_kv (args, usage)
    message= "Extra options:\n"
    args.each() {|k,v| message = message + "   --#{k}=#{v}\n"}
    message = message + usage
    raise message
  end

  # Exit for extra whole arguments
  def err_extra_arg (args, usage)
    message= "Extra options:\n"
    args.each() {|v| message = message + "   #{v}\n"}
    message = message + usage
    raise message
  end

  # Shift off one argument and parse it as an alias in .discoveryrc or a hostname
  # Set result in @hosts array
  def parse_hosts (args)
    hostname = args.shift()
    if !hostname.nil?()
      discoveryrc = File.expand_path("~/.discoveryrc")
      aliasmap = {}
      if File.readable?(discoveryrc)
        File.readlines(discoveryrc).each {|line| line.scan(/(\w+)\s*=\s*(.*)/) {|k,v| aliasmap[k]=v}}
      end
      @hosts = (aliasmap[hostname] || hostname).split(',').map() {|host| host.strip()};
    else
      @hosts = nil
    end
    return @hosts
  end

  def parse_add_command (args)
    #Pull host
    parse_hosts(args) || err_missing("hostname or hostname alias", @add_parser)

    # Pull -Dkey=value property arguments
    args.reject!() do |arg|
      arg =~ /-D\w+=.*/ && arg.scan(/-D(\w+)=(.*)/) do |k,v|
        if @option_map[:properties].nil?()
          @option_map[:properties] = {k => v};
        else
          @option_map[:properties][k]=v;
        end
      end
    end

    # Pull dashed options
    begin
      @add_parser.parse!(args)
    rescue OptionParser::ParseError => err
      raise "#{err}\n#{@add_parser}"
    end

    #Check argument list is now empty
    if !args.empty?()
      err_extra_arg(args, @add_parser)
    end

    # Check conflict - StaticAnnouncement options with JSON input
    if (@option_map[:jsonfile] || @option_map[:json]) && !@json_map.empty?()
      err_extra_kv(@json_map, @add_parser)
    end

    # Set output from options
    output = (@option_map[:output] == 'ID') ? :id : :json

    # Build StaticAnnouncement object from options
    if @option_map[:jsonfile]
      @static_announcement = JSON.parse(IO.read(File.expand_path(@option_map[:jsonfile])))
    elsif @option_map[:json]
      if '-' == @option_map[:json]
        @static_announcement = JSON.parse($stdin.read)
      else
        @static_announcement = JSON.parse(@option_map[:json])
      end
    else
      @static_announcement= {}
      @static_announcement['environment'] = @json_map[:environment] || err_missing(:environment, @add_parser)
      @static_announcement['type'] = @json_map[:type] || err_missing(:type, @add_parser)
      @static_announcement['pool'] = @json_map[:pool] || err_missing(:pool, @add_parser)
      @static_announcement['location'] = @json_map[:location]
      @static_announcement['properties']= @json_map[:properties]
    end

  end

  def parse_show_command (args)
    parse_hosts(args) || err_missing("hostname or hostname alias", @show_parser)

    begin
      @show_parser.parse!(args)
    rescue OptionParser::ParseError => err
      raise "#{err}\n#{@show_parser}"
    end

    if !args.empty?()
      err_extra_arg(args, @show_parser)
    end
  end

  def parse_delete_command (args)
    parse_hosts(args) || err_missing("hostname or hostname alias", @delete_parser)

    begin
      @delete_parser.parse!(args)
    rescue OptionParser::ParseError => err
      raise "#{err}\n#{@delete_parser}"
    end

    @id = args.shift() || err_missing("service identifier", @delete_parser)
  end
end
