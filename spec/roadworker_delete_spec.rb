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

  context 'Delete' do
    context 'HostedZone' do
      before do
        routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end
end
EOS
        end
      end

      it {
        routefile { '' }

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(3)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a = zone.rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(123)
        expect(rrs_list(a.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end

    context 'HostedZone (force)' do
      before do
        routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end
end
EOS
        end
      end

      it {
        routefile(:force => true) { '' }

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(0)
      }
    end

    context 'A(Wildcard) record' do
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

  rrset "*.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end

    context 'A record' do
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
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end

    context 'A1 A2' do
      before {
        routefile do
<<-EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 1"
    weight 100
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 2"
    weight 50
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
<<-EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 2"
    weight 50
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])

        a2 = zone.rrsets['www.winebarrel.jp.', 'A', "web server 2"]
        expect(a2.name).to eq("www.winebarrel.jp.")
        expect(a2.set_identifier).to eq('web server 2')
        expect(a2.weight).to eq(50)
        expect(a2.ttl).to eq(456)
        expect(rrs_list(a2.resource_records)).to eq(["127.0.0.3", "127.0.0.4"])
      }
    end

    context 'A1 A2 (both)' do
      before {
        routefile do
<<-EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 1"
    weight 100
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 2"
    weight 50
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
<<-EOS
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end

    context 'A1 A2 (Latency)' do
      before {
        routefile do
<<-EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 1"
    ttl 456
    region "us-west-1"
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 2"
    ttl 456
    region "us-west-2"
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
<<-EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 1"
    ttl 456
    region "us-west-1"
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])

        a1 = zone.rrsets['www.winebarrel.jp.', 'A', "web server 1"]
        expect(a1.name).to eq("www.winebarrel.jp.")
        expect(a1.set_identifier).to eq('web server 1')
        expect(a1.ttl).to eq(456)
        expect(a1.region).to eq("us-east-1")
        expect(rrs_list(a1.resource_records)).to eq(["127.0.0.6", "127.0.0.5"])
      }
    end


    context 'A1 A2 (Latency) (both)' do
      before {
        routefile do
<<-EOS
hosted_zone "winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 1"
    ttl 456
    region "us-west-1"
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 2"
    ttl 456
    region "us-west-2"
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
<<-EOS
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end

    context 'TXT record' do
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

  rrset "www.winebarrel.jp", "TXT" do
    ttl 123
    resource_records(
      '"v=spf1 +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/pra +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/mfrom +ip4:192.168.100.0/24 ~all"'
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end

    context 'CNAME record' do
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

  rrset "www.winebarrel.jp", "CNAME" do
    ttl 123
    resource_records("www2.winebarrel.jp")
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end

    context 'MX record' do
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

  rrset "www.winebarrel.jp", "MX" do
    ttl 123
    resource_records(
      "10 mail.winebarrel.jp",
      "20 mail2.winebarrel.jp"
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end

    context 'PTR record' do
      before {
        routefile do
<<EOS
hosted_zone "333.222.111.in-addr.arpa" do
  rrset "444.333.222.111.in-addr.arpa", "PTR" do
    ttl 123
    resource_records("www.winebarrel.jp")
  end

  rrset "555.333.222.111.in-addr.arpa", "PTR" do
    ttl 123
    resource_records("www2.winebarrel.jp")
  end
end
EOS
        end
      }

      it {
        routefile do
<<EOS
hosted_zone "333.222.111.in-addr.arpa" do
  rrset "555.333.222.111.in-addr.arpa", "PTR" do
    ttl 123
    resource_records("www2.winebarrel.jp")
  end
end
EOS
        end

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("333.222.111.in-addr.arpa.")
        expect(zone.resource_record_set_count).to eq(3)

        expect(zone.rrsets['333.222.111.in-addr.arpa.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['333.222.111.in-addr.arpa.', 'SOA'].ttl).to eq(900)

        ptr = zone.rrsets['555.333.222.111.in-addr.arpa.', 'PTR']
        expect(ptr.name).to eq("555.333.222.111.in-addr.arpa.")
        expect(ptr.ttl).to eq(123)
        expect(rrs_list(ptr.resource_records)).to eq(["www2.winebarrel.jp"])
      }
    end

    context 'SRV record' do
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

  rrset "ftp.winebarrel.jp", "SRV" do
    ttl 123
    resource_records(
      "1   0   21  server01.example.jp",
      "2   0   21  server02.example.jp"
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end

    context 'AAAA record' do
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

  rrset "www.winebarrel.jp", "AAAA" do
    ttl 123
    resource_records("::1")
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end

    context 'NS record' do
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

  rrset "www.winebarrel.jp", "NS" do
    ttl 123
    resource_records(
      "ns.winebarrel.jp",
      "ns2.winebarrel.jp"
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
        expect(rrs_list(info.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end
  end
end
