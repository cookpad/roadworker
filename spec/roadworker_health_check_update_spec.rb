$: << File.expand_path("#{File.dirname __FILE__}/../lib")
$: << File.expand_path("#{File.dirname __FILE__}/../spec")

require 'rubygems'
require 'roadworker'
require 'spec_helper'
require 'fileutils'
require 'logger'

describe Roadworker::Client do
  before(:each) {
    routefile(:force => true) { '' }
    @route53 = AWS::Route53.new
  }

  after(:all) do
    routefile(:force => true) { '' }
  end

  describe 'HealthCheck' do
    context 'Update' do
      context 'HTTPS?_STR_MATCH' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "tcp://192.0.43.10:3306"
    ttl 456
    resource_records(
      "127.0.0.5",
      "127.0.0.6"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.7",
      "127.0.0.8"
    )
  end
end
EOS
          end
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "http://192.0.43.10:80/path", :host => 'example.com', :search_string => '123'
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "https://192.0.43.10/path", :host => 'example.com', :search_string => '123'
    ttl 4560
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end
end
EOS
          end

          zones = @route53.hosted_zones.to_a
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(4)

          expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)

          a1 = zone.rrsets['www.winebarrel.jp.', 'A', "Primary"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('Primary')
          expect(a1.failover).to eq('PRIMARY')
          expect(a1.ttl).to eq(123)
          expect(rrs_list(a1.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
          expect(check_list[a1.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 80,
            :type => 'HTTP_STR_MATCH',
            :resource_path => '/path',
            :fully_qualified_domain_name => 'example.com',
            :search_string => '123',
            :request_interval => 30,
            :failure_threshold => 3,
          })

          a2 = zone.rrsets['www.winebarrel.jp.', 'A', "Secondary"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('Secondary')
          expect(a2.failover).to eq('SECONDARY')
          expect(a2.ttl).to eq(4560)
          expect(rrs_list(a2.resource_records)).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 443,
            :type => 'HTTPS_STR_MATCH',
            :resource_path => '/path',
            :fully_qualified_domain_name => 'example.com',
            :search_string => '123',
            :request_interval => 30,
            :failure_threshold => 3,
          })
        }
      end

      context 'Failover -> Failover' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "tcp://192.0.43.10:3306"
    ttl 456
    resource_records(
      "127.0.0.5",
      "127.0.0.6"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.7",
      "127.0.0.8"
    )
  end
end
EOS
          end
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "http://192.0.43.10:80/path"
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "tcp://192.0.43.10:3306"
    ttl 4560
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end
end
EOS
          end

          zones = @route53.hosted_zones.to_a
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(4)

          expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)

          a1 = zone.rrsets['www.winebarrel.jp.', 'A', "Primary"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('Primary')
          expect(a1.failover).to eq('PRIMARY')
          expect(a1.ttl).to eq(123)
          expect(rrs_list(a1.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
          expect(check_list[a1.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 80,
            :type => 'HTTP',
            :resource_path => '/path',
            :request_interval => 30,
            :failure_threshold => 3,
          })

          a2 = zone.rrsets['www.winebarrel.jp.', 'A', "Secondary"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('Secondary')
          expect(a2.failover).to eq('SECONDARY')
          expect(a2.ttl).to eq(4560)
          expect(rrs_list(a2.resource_records)).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 3306,
            :type => 'TCP',
            :request_interval => 30,
            :failure_threshold => 3,
          })
        }
      end

      context 'Failover -> Weighted' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "tcp://192.0.43.10:3306"
    ttl 456
    resource_records(
      "127.0.0.5",
      "127.0.0.6"
    )
  end
end
EOS
          end
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    weight 100
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end
end
EOS
          end

          zones = @route53.hosted_zones.to_a
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(3)

          expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(0)

          a1 = zone.rrsets['www.winebarrel.jp.', 'A', "Primary"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('Primary')
          expect(a1.failover).to be_nil
          expect(a1.weight).to eq(100)
          expect(a1.ttl).to eq(456)
          expect(rrs_list(a1.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
        }
      end

      context 'Weighted -> Failover' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    weight 100
    ttl 456
    resource_records(
      "127.0.0.5",
      "127.0.0.6"
    )
  end
end
EOS
          end
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "tcp://192.0.43.10:3306"
    ttl 456
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end
end
EOS
          end

          zones = @route53.hosted_zones.to_a
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(3)

          expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(1)

          a2 = zone.rrsets['www.winebarrel.jp.', 'A', "Secondary"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('Secondary')
          expect(a2.weight).to be_nil
          expect(a2.failover).to eq('SECONDARY')
          expect(a2.ttl).to eq(456)
          expect(rrs_list(a2.resource_records)).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 3306,
            :type => 'TCP',
            :request_interval => 30,
            :failure_threshold => 3,
          })
        }
      end

      context 'Weighted' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "w100"
    weight 100
    health_check "tcp://192.0.43.10:3306"
    ttl 456
    resource_records(
      "127.0.0.5",
      "127.0.0.6"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "w50"
    weight 50
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.7",
      "127.0.0.8"
    )
  end
end
EOS
          end
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "w100"
    weight 70
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "w50"
    weight 90
    health_check "tcp://192.0.43.10:3306"
    ttl 456
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end
end
EOS
          end

          zones = @route53.hosted_zones.to_a
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(4)

          expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)

          a1 = zone.rrsets['www.winebarrel.jp.', 'A', "w100"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('w100')
          expect(a1.weight).to eq(70)
          expect(a1.ttl).to eq(456)
          expect(rrs_list(a1.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
          expect(check_list[a1.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 80,
            :type => 'HTTP',
            :resource_path => '/path',
            :request_interval => 30,
            :failure_threshold => 3,
          })

          a2 = zone.rrsets['www.winebarrel.jp.', 'A', "w50"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('w50')
          expect(a2.weight).to eq(90)
          expect(a2.ttl).to eq(456)
          expect(rrs_list(a2.resource_records)).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 3306,
            :type => 'TCP',
            :request_interval => 30,
            :failure_threshold => 3,
          })
        }
      end

      context 'Latency' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "jp"
    region "ap-northeast-1"
    health_check "tcp://192.0.43.10:3306"
    ttl 456
    resource_records(
      "127.0.0.5",
      "127.0.0.6"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "us"
    region "us-east-1"
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.7",
      "127.0.0.8"
    )
  end
end
EOS
          end
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "jp"
    region "ap-northeast-1"
    health_check "http://192.0.43.10:80/path"
    ttl 123
    resource_records(
      "127.0.0.5",
      "127.0.0.6"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "us"
    region "us-east-1"
    health_check "tcp://192.0.43.10:3306"
    ttl 4560
    resource_records(
      "127.0.0.7",
      "127.0.0.8"
    )
  end
end
EOS
          end

          zones = @route53.hosted_zones.to_a
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(4)

          expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)

          a1 = zone.rrsets['www.winebarrel.jp.', 'A', "jp"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('jp')
          expect(a1.region).to eq('ap-northeast-1')
          expect(a1.ttl).to eq(123)
          expect(rrs_list(a1.resource_records)).to eq(["127.0.0.5", "127.0.0.6"])
          expect(check_list[a1.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 80,
            :type => 'HTTP',
            :resource_path => '/path',
            :request_interval => 30,
            :failure_threshold => 3,
          })

          a2 = zone.rrsets['www.winebarrel.jp.', 'A', "us"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('us')
          expect(a2.region).to eq('us-east-1')
          expect(a2.ttl).to eq(4560)
          expect(rrs_list(a2.resource_records)).to eq(["127.0.0.7", "127.0.0.8"])
          expect(check_list[a2.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 3306,
            :type => 'TCP',
            :request_interval => 30,
            :failure_threshold => 3,
          })
        }
      end
    end
  end
end
