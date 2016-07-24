$: << File.expand_path("#{File.dirname __FILE__}/../lib")

if ENV['TRAVIS']
  require 'simplecov'
  require 'coveralls'

  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  SimpleCov.start do
    add_filter "spec/"
  end
end

TEST_ELB = ENV['TEST_ELB']
TEST_CF = ENV['TEST_CF']
TEST_VPC_REGION = ENV['TEST_VPC_REGION']
TEST_VPC1 = ENV['TEST_VPC1']
TEST_VPC2 = ENV['TEST_VPC2']
TEST_INTERVAL = ENV['TEST_INTERVAL'].to_i
DNS_PORT = 5300

require 'rubygems'
require 'roadworker'
require 'fileutils'
require 'logger'
require 'rubydns'

Aws.config.update({
  :access_key_id => (ENV['TEST_AWS_ACCESS_KEY_ID'] || 'scott'),
  :secret_access_key => (ENV['TEST_AWS_SECRET_ACCESS_KEY'] || 'tiger'),
})

RSpec.configure do |config|
  config.before(:each) {
    sleep TEST_INTERVAL
    cleanup_route53
    @route53 = Aws::Route53::Client.new
  }

  config.after(:all) do
    routefile(:force => true) { '' }
  end
end

def run_dns(dsl, options)
  server = nil
  handler = options.fetch(:handler)

  options = {
    :logger      => Logger.new(debug? ? $stdout : '/dev/null'),
    :nameservers => "127.0.0.1",
    :port        => DNS_PORT,
  }.merge(options)

  begin
    server = RubyDNS::RuleBasedServer.new(:logger => Logger.new(debug? ? $stdout : '/dev/null'), &handler)

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
  if debug?
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

    options = {
      :logger => Logger.new(debug? ? $stdout : '/dev/null'),
      :health_check_gc => true
    }.merge(options)

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
    response = @route53.list_health_checks(opts)

    response[:health_checks].each do |check|
      check_list[check[:id]] = check[:health_check_config]
    end

    is_truncated = response[:is_truncated]
    next_marker = response[:next_marker]
  end

  return check_list
end

def fetch_hosted_zones(route53)
  zones = []
  route53.list_hosted_zones.each do |page|
    page.hosted_zones.each do |zone|
      zones << zone
    end
  end
  zones
end

class RRSets
  def initialize(rrsets)
    @rrsets = rrsets
  end

  def [](name, type, set_identifier = nil)
    @rrsets.find do |rrset|
      rrset.name == name && rrset.type == type && rrset.set_identifier == set_identifier
    end
  end
end

def fetch_rrsets(route53, hosted_zone_id)
  rrsets = []
  route53.list_resource_record_sets(hosted_zone_id: hosted_zone_id).each do |page|
    page.resource_record_sets.each do |rrset|
      rrsets << rrset
    end
  end
  RRSets.new(rrsets)
end

def debug?
  ENV['DEBUG'] == '1'
end

def cleanup_route53
  r53 = Aws::Route53::Client.new
  fetch_hosted_zones(r53).each do |hz|
    hz_name = hz.name.sub(/\.\z/, '')

    changes = []
    r53.list_resource_record_sets(hosted_zone_id: hz.id).each do |page|
      page.resource_record_sets.each do |rrset|
        rrset_name = rrset.name.sub(/\.\z/, '')

        unless rrset_name == hz_name and %w(NS SOA).include?(rrset.type)
          changes << { action: 'DELETE', resource_record_set: rrset }
        end
      end
    end

    unless changes.empty?
      r53.change_resource_record_sets(hosted_zone_id: hz.id, change_batch: { changes: changes })
    end
    r53.delete_hosted_zone(id: hz.id)

    r53.list_health_checks.flat_map(&:health_checks).map(&:id).each do |health_check_id|
      r53.delete_health_check(health_check_id: health_check_id)
    end
  end
end
