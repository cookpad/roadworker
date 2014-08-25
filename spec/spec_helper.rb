$: << File.expand_path("#{File.dirname __FILE__}/../lib")

TEST_ELB = ENV['TEST_ELB']
TEST_CF = ENV['TEST_CF']
DNS_PORT = 5300

require 'rubygems'
require 'roadworker'
require 'fileutils'
require 'logger'
require 'rubydns'

AWS.config({
  :access_key_id => (ENV['TEST_AWS_ACCESS_KEY_ID'] || 'scott'),
  :secret_access_key => (ENV['TEST_AWS_SECRET_ACCESS_KEY'] || 'tiger'),
})

RSpec.configure do |config|
  config.before(:each) {
    routefile(:force => true) { '' }
    @route53 = AWS::Route53.new
  }

  config.after(:all) do
    routefile(:force => true) { '' }
  end
end

def run_dns(dsl, options)
  server = nil
  handler = options.fetch(:handler)

  options = {
    :logger      => Logger.new('/dev/null'),
    :nameservers => "127.0.0.1",
    :port        => DNS_PORT,
  }.merge(options)

  begin
    server = RubyDNS::RuleBasedServer.new(:logger => Logger.new('/dev/null'), &handler)

    Thread.new {
      EventMachine.run do
        server.run(
          :listen => [:udp, :tcp].map {|i| [i, "0.0.0.0", DNS_PORT] },
        )
      end
    }

    sleep 0.1 until EventMachine.reactor_running?
    tempfile = `mktemp /tmp/#{File.basename(__FILE__)}.XXXXXX`.strip
    records_length, failures = nil

    begin
      open(tempfile, 'wb') {|f| f.puts(dsl) }
      client = Roadworker::Client.new(options)

      quiet do
        records_length, failures = client.test(tempfile)
      end
    ensure
      FileUtils.rm_f(tempfile)
    end
  ensure
    EventMachine.stop if server
  end

  return failures
end

def quiet
  if ENV['DEBUG'] == '1'
    yield
    return
  end

  open('/dev/null', 'wb') do |f|
    stdout_orig = $stdout

    begin
      $stdout = f
      yield
    ensure
      $stdout = stdout_orig
    end
  end
end

def routefile(options = {})
  updated = false
  tempfile = `mktemp /tmp/#{File.basename(__FILE__)}.XXXXXX`.strip

  begin
    open(tempfile, 'wb') {|f| f.puts(yield) }
    options = {:logger => Logger.new('/dev/null')}.merge(options)
    client = Roadworker::Client.new(options)
    updated = client.apply(tempfile)
    sleep ENV['TEST_DELAY'].to_f
  ensure
    FileUtils.rm_f(tempfile)
  end

  return updated
end

def rrs_list(rrs)
  rrs.map {|i| i[:value] }
end

def fetch_health_checks(route53)
  check_list = {}

  is_truncated = true
  next_marker = nil

  while is_truncated
    opts = next_marker ? {:marker => next_marker} : {}
    response = @route53.client.list_health_checks(opts)

    response[:health_checks].each do |check|
      check_list[check[:id]] = check[:health_check_config]
    end

    is_truncated = response[:is_truncated]
    next_marker = response[:next_marker]
  end

  return check_list
end
