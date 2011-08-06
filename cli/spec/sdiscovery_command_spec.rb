#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib discovery])

require 'rubygems'
require 'json'
require 'rspec'
require 'SDiscoveryCommand'

describe 'Option parsing' do

  it 'should know if the caller asked for help with a short option' do
    parser = SDiscoveryCommand.new(["-h"])
    parser.help?.should == true
  end

  it 'should know if the caller asked for help with a long option' do
    parser = SDiscoveryCommand.new(["--help"])
    parser.help?.should == true
  end

  it 'should provide help if the caller used an unknown command' do
    parser = SDiscoveryCommand.new(["this_is_not_a_command"])
    parser.help?.should == true
  end

  it 'should read aliases out of the .discoveryrc file' do
    File.should_receive(:expand_path).with("~/.discoveryrc").and_return("/path/to/.discoveryrc")
    File.should_receive(:readable?).with("/path/to/.discoveryrc").and_return(true)
    File.should_receive(:readlines).with("/path/to/.discoveryrc").and_return(
        ["alias1=http://discovery:8080", "alias2=http://discovery:8081,http://discovery:8082"])

    parser = SDiscoveryCommand.new(["show", "alias2"])
    parser.command.should == "SHOW"
    parser.hosts.should == ["http://discovery:8081", "http://discovery:8082"]

  end

  describe 'when the command is show' do
    before(:each) do
      @args = [ "show", "http://localhost:8080" ]
    end

    it 'should construct with a default hostname' do
      pending 'support default hostname' do
        parser = SDiscoveryCommand.new(["show"])
        parser.command.should == "SHOW"
        parser.hosts.should == ["http://localhost:8080"]
      end
    end

    it 'should construct and allow the command to be read' do
      parser = SDiscoveryCommand.new(@args)
      parser.command.should == "SHOW"
      parser.hosts.should == ["http://localhost:8080"]
    end

    it 'should allow the use of an output format specification for JSON' do
      parser = SDiscoveryCommand.new(@args + [ "-o", "JSON"])
      parser.command.should == "SHOW"
      parser.hosts.should == ["http://localhost:8080"]
      parser.option_map[:output].should == "JSON"
    end

    it 'should allow the use of an output format specification for ID' do
      parser = SDiscoveryCommand.new(@args + [ "-o", "ID"])
      parser.command.should == "SHOW"
      parser.hosts.should == ["http://localhost:8080"]
      parser.option_map[:output].should == "ID"
    end

    it 'should allow case insensitive strings for output types' do
      pending 'fix the case sensitivity of the output type' do
        parser = SDiscoveryCommand.new(@args + ["-o", "json"])
        parser.command.should == "SHOW"
        parser.hosts.should == ["http://localhost:8080"]
        parser.option_map[:output].should == "JSON"
      end
    end

    it 'should allow long option form for output format specification' do
      parser = SDiscoveryCommand.new(@args + [ "--output", "ID"])
      parser.command.should == "SHOW"
      parser.hosts.should == ["http://localhost:8080"]
      parser.option_map[:output].should == "ID"
    end

    it 'should allow long option form with = for output format specification' do
      parser = SDiscoveryCommand.new(@args + [ "--output=ID"])
      parser.command.should == "SHOW"
      parser.hosts.should == ["http://localhost:8080"]
      parser.option_map[:output].should == "ID"
    end

    it 'should fail to parse the environment option' do
      lambda { SDiscoveryCommand.new(@args + [ "-e", "test"])}.should raise_exception(RuntimeError, /invalid option: -e/)
    end

    it 'should fail to parse the type option' do
      lambda { SDiscoveryCommand.new(@args + [ "-t", "test"])}.should raise_exception(RuntimeError, /invalid option: -t/)
    end

    it 'should fail to parse the pool option' do
      lambda { SDiscoveryCommand.new(@args + [ "-p", "test"])}.should raise_exception(RuntimeError, /invalid option: -p/)
    end

    it 'should fail to parse the location option' do
      lambda { SDiscoveryCommand.new(@args + [ "-l", "test"])}.should raise_exception(RuntimeError, /invalid option: -l/)
    end

    it 'should fail to parse the JSON option' do
      lambda { SDiscoveryCommand.new(@args + [ "-j", "test"])}.should raise_exception(RuntimeError, /invalid option: -j/)
    end

    it 'should fail to parse the JSON file option' do
      lambda { SDiscoveryCommand.new(@args + [ "-f", "test"])}.should raise_exception(RuntimeError, /invalid option: -f/)
    end

    it 'should fail to parse defined options' do
      lambda { SDiscoveryCommand.new(@args + [ "-Dfoo=bar"])}.should raise_exception(RuntimeError, /invalid option: -D/)
    end
  end

  describe 'when the command is add' do
    before(:each) do
      @args = [ "add", "http://localhost:8080" ]
    end

    STATIC_ANNOUNCEMENT =
        {
            "type" => "user",
            "pool" => "general",
            "environment" => "dev",
            "properties" => {
                "http" => "http://user:8080"
            }
        }

    it 'should construct when the service is identified with a JSON string' do
      parser = SDiscoveryCommand.new(@args + ["-j", STATIC_ANNOUNCEMENT.to_json])
      parser.command.should == "ADD"
      parser.hosts.should == ["http://localhost:8080"]
      parser.static_announcement.should == STATIC_ANNOUNCEMENT
    end

    it 'should construct when the service is identified with a long-option JSON string' do
      parser = SDiscoveryCommand.new(@args + ["--json", STATIC_ANNOUNCEMENT.to_json])
      parser.command.should == "ADD"
      parser.hosts.should == ["http://localhost:8080"]
      parser.static_announcement.should == STATIC_ANNOUNCEMENT
    end

    it 'should allow the use of an output format specification for ID' do
      parser = SDiscoveryCommand.new(@args + ["-j", STATIC_ANNOUNCEMENT.to_json, "-o", "ID"])
      parser.command.should == "ADD"
      parser.hosts.should == ["http://localhost:8080"]
      parser.static_announcement.should == STATIC_ANNOUNCEMENT
      parser.option_map[:output].should == "ID"
    end

    it 'should construct without a hostname when the service is identified with a JSON string' do
      pending 'support default hostname' do
        parser = SDiscoveryCommand.new(["add", "-j", STATIC_ANNOUNCEMENT.to_json])
        parser.command.should == "ADD"
        parser.hosts.should == ["http://localhost:8080"]
        parser.static_announcement.should == STATIC_ANNOUNCEMENT
      end
    end

    it 'should construct when the service is identified with a JSON file' do
      full_path = File.expand_path("./discoveryrc")
      File.should_receive(:expand_path).with("~/.discoveryrc").and_return(full_path)
      File.should_receive(:expand_path).with("my_json_file").and_return("/full/path/to/my_json_file")
      IO.should_receive(:read).with("/full/path/to/my_json_file").and_return(STATIC_ANNOUNCEMENT.to_json)

      parser = SDiscoveryCommand.new(@args + ["-f", "my_json_file"])
      parser.command.should == "ADD"
      parser.hosts.should == ["http://localhost:8080"]
      parser.static_announcement.should == STATIC_ANNOUNCEMENT
    end

    it 'should construct when the service is identified with a long-option JSON file' do
      full_path = File.expand_path("./discoveryrc")
      File.should_receive(:expand_path).with("~/.discoveryrc").and_return(full_path)
      File.should_receive(:expand_path).with("my_json_file").and_return("/full/path/to/my_json_file")
      IO.should_receive(:read).with("/full/path/to/my_json_file").and_return(STATIC_ANNOUNCEMENT.to_json)

      parser = SDiscoveryCommand.new(@args + ["--jsonfile", "my_json_file"])
      parser.command.should == "ADD"
      parser.hosts.should == ["http://localhost:8080"]
      parser.static_announcement.should == STATIC_ANNOUNCEMENT
    end

    it 'should construct from individual options' do
      parser = SDiscoveryCommand.new(@args + ["-e", "dev", "-t", "user", "-p", "general", "-Dhttp=http://user:8080"])
      parser.command.should == "ADD"
      parser.hosts.should == ["http://localhost:8080"]
      pending('fix the property parsing, which seems to be broken') do
        parser.static_announcement.should == STATIC_ANNOUNCEMENT
      end
    end

    STATIC_ANNOUNCEMENT_WITH_LOCATION =
        {
            "type" => "user",
            "pool" => "general",
            "environment" => "dev",
            "location" => "here",
            "properties" => {
                "http" => "http://user:8080"
            }
        }

    it 'should construct from individual options with a location' do
      parser = SDiscoveryCommand.new(@args +
                                         ["-e", "dev", "-t", "user", "-p", "general", "-l", "here", "-Dhttp=http://user:8080"])
      parser.command.should == "ADD"
      parser.hosts.should == ["http://localhost:8080"]
      pending('fix the property parsing, which seems to be broken') do
        parser.static_announcement.should == STATIC_ANNOUNCEMENT_WITH_LOCATION
      end
    end

    it 'should construct from individual long-form options' do
      parser = SDiscoveryCommand.new(@args + ["--environment", "dev", "--type=user", "--pool", "general", "-Dhttp=http://user:8080"])
      parser.command.should == "ADD"
      parser.hosts.should == ["http://localhost:8080"]
      pending('fix the property parsing, which seems to be broken') do
        parser.static_announcement.should == STATIC_ANNOUNCEMENT
      end
    end

    it 'should fail if environment is missing' do
      lambda {
        SDiscoveryCommand.new(@args + [ "-t", "user", "-p", "general" ])
      }.should raise_exception(RuntimeError, /Missing argument --environment/)
    end

    it 'should fail if type is missing' do
      lambda {
        SDiscoveryCommand.new(@args + [ "-e", "dev", "-p", "general" ])
      }.should raise_exception(RuntimeError, /Missing argument --type/)
    end

    it 'should fail if pool is missing' do
      lambda {
        SDiscoveryCommand.new(@args + [ "-e", "dev", "-t", "user" ])
      }.should raise_exception(RuntimeError, /Missing argument --pool/)
    end

    it 'should fail if both JSON and individual options are specified' do
      pending('not sure why this test fails, but I think it should pass') do
        lambda {
          SDiscoveryCommand.new(@args + ["-e", "dev", "-t", "user", "-p", "general", "-j", STATIC_ANNOUNCEMENT.to_json])
        }.should raise_exception(RuntimeError, /Extra options/)
      end
    end

  end

  describe 'when the command is delete' do
    before(:each) do
      @args = [ "delete", "http://localhost:8080", "identifier" ]
    end

    it 'should construct with a default hostname' do
      pending 'support default hostname' do
        parser = SDiscoveryCommand.new(["delete", "identifier"])
        parser.command.should == "DELETE"
        parser.hosts.should == ["http://localhost:8080"]
        parser.id.should == "identifier"
      end
    end

    it 'should construct and allow the command to be read' do
      parser = SDiscoveryCommand.new(@args)
      parser.command.should == "DELETE"
      parser.hosts.should == ["http://localhost:8080"]
      parser.id.should == "identifier"
    end

    it 'should fail if the service id is omitted' do
      lambda { SDiscoveryCommand.new(["delete", "http://localhost:8080"])}.should raise_exception(RuntimeError, /Missing argument --service identifier/)
    end

    it 'should fail to parse the output format option' do
      lambda { SDiscoveryCommand.new(@args + [ "-o", "JSON"])}.should raise_exception(RuntimeError, /invalid option: -o/)
    end

    it 'should fail to parse the environment option' do
      lambda { SDiscoveryCommand.new(@args + [ "-e", "test"])}.should raise_exception(RuntimeError, /invalid option: -e/)
    end

    it 'should fail to parse the type option' do
      lambda { SDiscoveryCommand.new(@args + [ "-t", "test"])}.should raise_exception(RuntimeError, /invalid option: -t/)
    end

    it 'should fail to parse the pool option' do
      lambda { SDiscoveryCommand.new(@args + [ "-p", "test"])}.should raise_exception(RuntimeError, /invalid option: -p/)
    end

    it 'should fail to parse the location option' do
      lambda { SDiscoveryCommand.new(@args + [ "-l", "test"])}.should raise_exception(RuntimeError, /invalid option: -l/)
    end

    it 'should fail to parse the JSON option' do
      lambda { SDiscoveryCommand.new(@args + [ "-j", "test"])}.should raise_exception(RuntimeError, /invalid option: -j/)
    end

    it 'should fail to parse the JSON file option' do
      lambda { SDiscoveryCommand.new(@args + [ "-f", "test"])}.should raise_exception(RuntimeError, /invalid option: -f/)
    end

    it 'should fail to parse defined options' do
      lambda { SDiscoveryCommand.new(@args + [ "-Dfoo=bar"])}.should raise_exception(RuntimeError, /invalid option: -D/)
    end
  end

end
