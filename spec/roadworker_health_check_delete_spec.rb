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
    context 'Delete' do
      context 'HTTP_STR_MATCH' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "http://192.0.43.10:80/path", :host => 'example.com', :search_string => '123', :request_interval => 10, :failure_threshold => 10
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

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
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
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

          info = zone.rrsets['info.winebarrel.jp.', 'A']
          expect(info.name).to eq("info.winebarrel.jp.")
          expect(info.ttl).to eq(123)
          expect(rrs_list(info.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(1)

          a2 = zone.rrsets['www.winebarrel.jp.', 'A', "Secondary"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('Secondary')
          expect(a2.failover).to eq('SECONDARY')
          expect(a2.ttl).to eq(456)
          expect(rrs_list(a2.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 3306,
            :type => 'TCP',
            :request_interval => 30,
            :failure_threshold => 3,
          })
        }
      end

      context 'Primary' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

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
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
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

          info = zone.rrsets['info.winebarrel.jp.', 'A']
          expect(info.name).to eq("info.winebarrel.jp.")
          expect(info.ttl).to eq(123)
          expect(rrs_list(info.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(1)

          a2 = zone.rrsets['www.winebarrel.jp.', 'A', "Secondary"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('Secondary')
          expect(a2.failover).to eq('SECONDARY')
          expect(a2.ttl).to eq(456)
          expect(rrs_list(a2.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 3306,
            :type => 'TCP',
            :request_interval => 30,
            :failure_threshold => 3,
          })
        }
      end

      context 'Secondary' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

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
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "http://192.0.43.10:80/path"
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
          expect(zone.resource_record_set_count).to eq(4)

          expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          info = zone.rrsets['info.winebarrel.jp.', 'A']
          expect(info.name).to eq("info.winebarrel.jp.")
          expect(info.ttl).to eq(123)
          expect(rrs_list(info.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(1)

          a1 = zone.rrsets['www.winebarrel.jp.', 'A', "Primary"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('Primary')
          expect(a1.failover).to eq('PRIMARY')
          expect(a1.ttl).to eq(456)
          expect(rrs_list(a1.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])
          expect(check_list[a1.health_check_id]).to eq({
            :ip_address => '192.0.43.10',
            :port => 80,
            :type => 'HTTP',
            :resource_path => '/path',
            :request_interval => 30,
            :failure_threshold => 3,
          })
        }
      end

      context 'Both' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

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
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
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

          info = zone.rrsets['info.winebarrel.jp.', 'A']
          expect(info.name).to eq("info.winebarrel.jp.")
          expect(info.ttl).to eq(123)
          expect(rrs_list(info.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(0)
        }
      end

      context 'No HealthCheck GC' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

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
        }

        it {
          routefile(:no_health_check_gc => true) do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
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

          info = zone.rrsets['info.winebarrel.jp.', 'A']
          expect(info.name).to eq("info.winebarrel.jp.")
          expect(info.ttl).to eq(123)
          expect(rrs_list(info.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)
        }
      end

      context 'Weighted' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "w100"
    weight 100
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "w50"
    weight 50
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
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
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

          info = zone.rrsets['info.winebarrel.jp.', 'A']
          expect(info.name).to eq("info.winebarrel.jp.")
          expect(info.ttl).to eq(123)
          expect(rrs_list(info.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(0)
        }
      end

      context 'Latency' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "jp"
    region "ap-northeast-1"
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "us"
    region "us-east-1"
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
        }

        it {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
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

          info = zone.rrsets['info.winebarrel.jp.', 'A']
          expect(info.name).to eq("info.winebarrel.jp.")
          expect(info.ttl).to eq(123)
          expect(rrs_list(info.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(0)
        }
      end
    end
  end
end
