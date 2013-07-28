$: << File.expand_path("#{File.dirname __FILE__}/../lib")
require 'rubygems'
require 'roadworker'
require 'fileutils'
require 'logger'

def routefile(options = {})
  tempfile = `mktemp /tmp/#{File.basename(__FILE__)}.XXXXXX`.strip

  begin
    open(tempfile, 'wb') {|f| f.puts(yield) }
    options = {:logger => Logger.new('/dev/null')}.merge(options)
    client = Roadworker::Client.new(options)
    client.apply(tempfile)
  ensure
    FileUtils.rm_f(tempfile)
  end
end

def rrs_list(rrs)
  rrs.map {|i| i[:value] }.sort
end

describe Roadworker::Client do
  before(:each) {
    AWS.config({
      :access_key_id => (ENV['TEST_AWS_ACCESS_KEY_ID'] || 'scott'),
      :secret_access_key => (ENV['TEST_AWS_SECRET_ACCESS_KEY'] || 'tiger'),
    })

    routefile(:force => true) { '' }
    @route53 = AWS::Route53.new
  }

  context 'empty' do
    it  {
      expect(@route53.hosted_zones.to_a).to be_empty
    }
  end

  context 'Create HostedZone' do
    before do
      routefile do
<<EOS
hosted_zone "winebarre.jp" do
end
EOS
      end
    end

    it {
      zones = @route53.hosted_zones.to_a
      expect(zones.length).to eq(1)

      zone = zones[0]
      expect(zone.name).to eq("winebarre.jp.")
      expect(zone.resource_record_set_count).to eq(2)

      expect(zone.rrsets['winebarre.jp.', 'NS'].ttl).to eq(172800)
      expect(zone.rrsets['winebarre.jp.', 'SOA'].ttl).to eq(900)
    }
  end

  context 'Create A record' do
    before {
      routefile do
<<EOS
hosted_zone "winebarre.jp" do
  rrset "www.winebarre.jp", "A" do
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
      zones = @route53.hosted_zones.to_a
      expect(zones.length).to eq(1)

      zone = zones[0]
      expect(zone.name).to eq("winebarre.jp.")
      expect(zone.resource_record_set_count).to eq(3)

      expect(zone.rrsets['winebarre.jp.', 'NS'].ttl).to eq(172800)
      expect(zone.rrsets['winebarre.jp.', 'SOA'].ttl).to eq(900)

      a = zone.rrsets['www.winebarre.jp.', 'A']
      expect(a.name).to eq("www.winebarre.jp.")
      expect(a.ttl).to eq(123)
      expect(rrs_list(a.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
    }
  end

  context 'Create A(Alias) record' do
    before {
      routefile do
<<EOS
hosted_zone "winebarre.jp" do
  rrset "www.winebarre.jp", "A" do
    dns_name "roadworker-1957159880.ap-northeast-1.elb.amazonaws.com"
  end
end
EOS
      end
    }

    it {
      zones = @route53.hosted_zones.to_a
      expect(zones.length).to eq(1)

      zone = zones[0]
      expect(zone.name).to eq("winebarre.jp.")
      expect(zone.resource_record_set_count).to eq(3)

      expect(zone.rrsets['winebarre.jp.', 'NS'].ttl).to eq(172800)
      expect(zone.rrsets['winebarre.jp.', 'SOA'].ttl).to eq(900)

      a = zone.rrsets['www.winebarre.jp.', 'A']
      expect(a.name).to eq("www.winebarre.jp.")
      expect(a.alias_target).to eq({
        :hosted_zone_id => "Z2YN17T5R711GT",
        :dns_name => "roadworker-1957159880.ap-northeast-1.elb.amazonaws.com.",
        :evaluate_target_health => false,
      })
    }
  end

  context 'Create A1 A2' do
    before {
      routefile do
<<-EOS
hosted_zone "winebarre.jp" do
  rrset "www.winebarre.jp", "A" do
    set_identifier "web server 1"
    weight 100
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarre.jp", "A" do
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
      zones = @route53.hosted_zones.to_a
      expect(zones.length).to eq(1)

      zone = zones[0]
      expect(zone.name).to eq("winebarre.jp.")
      expect(zone.resource_record_set_count).to eq(4)

      expect(zone.rrsets['winebarre.jp.', 'NS'].ttl).to eq(172800)
      expect(zone.rrsets['winebarre.jp.', 'SOA'].ttl).to eq(900)

      a1 = zone.rrsets['www.winebarre.jp.', 'A', "web server 1"]
      expect(a1.name).to eq("www.winebarre.jp.")
      expect(a1.set_identifier).to eq('web server 1')
      expect(a1.weight).to eq(100)
      expect(a1.ttl).to eq(456)
      expect(rrs_list(a1.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])

      a2 = zone.rrsets['www.winebarre.jp.', 'A', "web server 2"]
      expect(a2.name).to eq("www.winebarre.jp.")
      expect(a2.set_identifier).to eq('web server 2')
      expect(a2.weight).to eq(50)
      expect(a2.ttl).to eq(456)
      expect(rrs_list(a2.resource_records)).to eq(["127.0.0.3", "127.0.0.4"])
    }
  end

  context 'Create TXT record' do
    before {
      routefile do
<<EOS
hosted_zone "winebarre.jp" do
  rrset "www.winebarre.jp", "TXT" do
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
      zones = @route53.hosted_zones.to_a
      expect(zones.length).to eq(1)

      zone = zones[0]
      expect(zone.name).to eq("winebarre.jp.")
      expect(zone.resource_record_set_count).to eq(3)

      expect(zone.rrsets['winebarre.jp.', 'NS'].ttl).to eq(172800)
      expect(zone.rrsets['winebarre.jp.', 'SOA'].ttl).to eq(900)

      txt = zone.rrsets['www.winebarre.jp.', 'TXT']
      expect(txt.name).to eq("www.winebarre.jp.")
      expect(txt.ttl).to eq(123)
      expect(rrs_list(txt.resource_records)).to eq([
        "\"spf2.0/mfrom +ip4:192.168.100.0/24 ~all\"",
        "\"spf2.0/pra +ip4:192.168.100.0/24 ~all\"",
        "\"v=spf1 +ip4:192.168.100.0/24 ~all\""
      ])
    }
  end

  context 'Create CNAME record' do
    before {
      routefile do
<<EOS
hosted_zone "winebarre.jp" do
  rrset "www.winebarre.jp", "CNAME" do
    ttl 123
    resource_records("www2.winebarre.jp")
  end
end
EOS
      end
    }

    it {
      zones = @route53.hosted_zones.to_a
      expect(zones.length).to eq(1)

      zone = zones[0]
      expect(zone.name).to eq("winebarre.jp.")
      expect(zone.resource_record_set_count).to eq(3)

      expect(zone.rrsets['winebarre.jp.', 'NS'].ttl).to eq(172800)
      expect(zone.rrsets['winebarre.jp.', 'SOA'].ttl).to eq(900)

      cname = zone.rrsets['www.winebarre.jp.', 'CNAME']
      expect(cname.name).to eq("www.winebarre.jp.")
      expect(cname.ttl).to eq(123)
      expect(rrs_list(cname.resource_records)).to eq(["www2.winebarre.jp"])
    }
  end

  context 'Create MX record' do
    before {
      routefile do
<<EOS
hosted_zone "winebarre.jp" do
  rrset "www.winebarre.jp", "MX" do
    ttl 123
    resource_records(
      "10 mail.winebarre.jp",
      "20 mail2.winebarre.jp"
    )
  end
end
EOS
      end
    }

    it {
      zones = @route53.hosted_zones.to_a
      expect(zones.length).to eq(1)

      zone = zones[0]
      expect(zone.name).to eq("winebarre.jp.")
      expect(zone.resource_record_set_count).to eq(3)

      expect(zone.rrsets['winebarre.jp.', 'NS'].ttl).to eq(172800)
      expect(zone.rrsets['winebarre.jp.', 'SOA'].ttl).to eq(900)

      mx = zone.rrsets['www.winebarre.jp.', 'CNAME']
      expect(mx.name).to eq("www.winebarre.jp.")
      expect(mx.ttl).to eq(123)
      expect(rrs_list(mx.resource_records)).to eq(["10 mail.winebarre.jp", "20 mail2.winebarre.jp"])
    }
  end
end
