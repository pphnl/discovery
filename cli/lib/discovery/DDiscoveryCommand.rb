require 'rubygems'
require 'optparse'
require 'json'

# CLI parser for sdiscovery

class DDiscoveryCommand
  @hosts
  @help_message
  @parser
  @type
  @pool
  @help

  attr_reader :hosts, :type, :pool

  # Returns true if help was requested and there's help in help_message
  def help?()
    return @help
  end

  def help_message
    return null unless @help
    return @parser.to_s
  end

  def initialize (args)

    @parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{opts.program_name()} alias|URL [OPTIONS]"

      opts.on('-h', '--help', 'Display this screen') do
        @help = true
      end

      opts.on('--type TYPE', '-t', "Service definition: type") do |value|
        @type=value
      end

      opts.on('--pool POOL', '-p', "Service definition: pool") do |value|
        @pool=value
      end

    end

    parse_command(args)
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
    return if args[0] =~ /^-/
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

  def parse_command (args)
    #Pull host
    parse_hosts(args) || err_missing("hostname or hostname alias", @parser)

    # Pull dashed options
    begin
      @parser.parse!(args)
    rescue OptionParser::ParseError => err
      raise "#{err}\n#{@parser}"
    end

    #Check argument list is now empty
    if !args.empty?()
      err_extra_arg(args, @parser)
    end

  end

end
