$: << File.expand_path("#{File.dirname __FILE__}/../lib")
$: << File.expand_path("#{File.dirname __FILE__}/../spec")

require 'rubygems'
require 'roadworker'
require 'spec_helper'
require 'fileutils'
require 'logger'

describe Roadworker::Client do
    routefile(:force => true) { '' }
    @route53 = AWS::Route53.new
  }

  after(:all) do
    routefile(:force => true) { '' }
  end

  context 'Mix' do
    before(:each) {
      routefile do
<<EOS
hosted_zone "info.winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end
end

hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "elb.winebarrel.jp", "A" do
    dns_name "roadworker-1619064454.ap-northeast-1.elb.amazonaws.com"
  end

  rrset "www.winebarrel.jp", "TXT" do
    ttl 123
    resource_records(
      '"v=spf1 +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/pra +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/mfrom +ip4:192.168.100.0/24 ~all"'
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

    context 'No change' do
      it {
        updated = routefile do
<<EOS
hosted_zone "info.winebarrel.jp" do
  rrset "info.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end
end

hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "elb.winebarrel.jp", "A" do
    dns_name "roadworker-1619064454.ap-northeast-1.elb.amazonaws.com"
  end

  rrset "www.winebarrel.jp", "TXT" do
    ttl 123
    resource_records(
      '"v=spf1 +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/pra +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/mfrom +ip4:192.168.100.0/24 ~all"'
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

        expect(updated).to be_false

        zones = @route53.hosted_zones.to_a.sort_by {|i| i.name }
        expect(zones.length).to eq(2)

        info_zone = zones[0]
        expect(info_zone.name).to eq("info.winebarrel.jp.")
        expect(info_zone.resource_record_set_count).to eq(3)

        expect(info_zone.rrsets['info.winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(info_zone.rrsets['info.winebarrel.jp.', 'SOA'].ttl).to eq(900)

        info_a = info_zone.rrsets['info.winebarrel.jp.', 'A']
        expect(info_a.name).to eq("info.winebarrel.jp.")
        expect(info_a.ttl).to eq(123)
        expect(rrs_list(info_a.resource_records)).to eq(["127.0.0.3", "127.0.0.4"])

        zone = zones[1]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(6)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a = zone.rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(123)
        expect(rrs_list(a.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])

        a_alias = zone.rrsets['elb.winebarrel.jp.', 'A']
        expect(a_alias.name).to eq("elb.winebarrel.jp.")
        expect(a_alias.alias_target).to eq({
          :hosted_zone_id => "Z2YN17T5R711GT",
          :dns_name => "roadworker-1619064454.ap-northeast-1.elb.amazonaws.com.",
          :evaluate_target_health => false,
        })

        txt = zone.rrsets['www.winebarrel.jp.', 'TXT']
        expect(txt.name).to eq("www.winebarrel.jp.")
        expect(txt.ttl).to eq(123)
        expect(rrs_list(txt.resource_records)).to eq([
          "\"v=spf1 +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/pra +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/mfrom +ip4:192.168.100.0/24 ~all\""
        ])

        mx = zone.rrsets['www.winebarrel.jp.', 'MX']
        expect(mx.name).to eq("www.winebarrel.jp.")
        expect(mx.ttl).to eq(123)
        expect(rrs_list(mx.resource_records)).to eq(["10 mail.winebarrel.jp", "20 mail2.winebarrel.jp"])
      }
    end

    context 'Normalization' do
      it {
        updated = routefile do
<<EOS
hosted_zone "info.winebarrel.jp." do
  rrset "INFO.WINEBARREL.JP", "A" do
    ttl 123
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end
end

hosted_zone "WINEBARREL.JP" do
  rrset "www.winebarrel.jp.", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "ELB.WINEBARREL.JP.", "A" do
    dns_name "ROADWORKER-1619064454.AP-NORTHEAST-1.ELB.AMAZONAWS.COM."
  end

  rrset "www.winebarrel.jp.", "TXT" do
    ttl 123
    resource_records(
      '"v=spf1 +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/pra +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/mfrom +ip4:192.168.100.0/24 ~all"'
    )
  end

  rrset "WWW.WINEBARREL.JP", "MX" do
    ttl 123
    resource_records(
      "10 mail.winebarrel.jp",
      "20 mail2.winebarrel.jp"
    )
  end
end
EOS
        end

        expect(updated).to be_false

        zones = @route53.hosted_zones.to_a.sort_by {|i| i.name }
        expect(zones.length).to eq(2)

        info_zone = zones[0]
        expect(info_zone.name).to eq("info.winebarrel.jp.")
        expect(info_zone.resource_record_set_count).to eq(3)

        expect(info_zone.rrsets['info.winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(info_zone.rrsets['info.winebarrel.jp.', 'SOA'].ttl).to eq(900)

        info_a = info_zone.rrsets['info.winebarrel.jp.', 'A']
        expect(info_a.name).to eq("info.winebarrel.jp.")
        expect(info_a.ttl).to eq(123)
        expect(rrs_list(info_a.resource_records)).to eq(["127.0.0.3", "127.0.0.4"])

        zone = zones[1]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(6)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a = zone.rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(123)
        expect(rrs_list(a.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])

        a_alias = zone.rrsets['elb.winebarrel.jp.', 'A']
        expect(a_alias.name).to eq("elb.winebarrel.jp.")
        expect(a_alias.alias_target).to eq({
          :hosted_zone_id => "Z2YN17T5R711GT",
          :dns_name => "roadworker-1619064454.ap-northeast-1.elb.amazonaws.com.",
          :evaluate_target_health => false,
        })

        txt = zone.rrsets['www.winebarrel.jp.', 'TXT']
        expect(txt.name).to eq("www.winebarrel.jp.")
        expect(txt.ttl).to eq(123)
        expect(rrs_list(txt.resource_records)).to eq([
          "\"v=spf1 +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/pra +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/mfrom +ip4:192.168.100.0/24 ~all\""
        ])

        mx = zone.rrsets['www.winebarrel.jp.', 'MX']
        expect(mx.name).to eq("www.winebarrel.jp.")
        expect(mx.ttl).to eq(123)
        expect(rrs_list(mx.resource_records)).to eq(["10 mail.winebarrel.jp", "20 mail2.winebarrel.jp"])
      }
    end

    context 'Change' do
      it {
        updated = routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
    )
  end

  rrset "elb.winebarrel.jp", "A" do
    dns_name "roadworker-1619064454.ap-northeast-1.elb.amazonaws.com"
  end

  rrset "www.winebarrel.jp", "TXT" do
    ttl 456
    resource_records(
      '"v=spf1 +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/pra +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/mfrom +ip4:192.168.100.0/24 ~all"'
    )
  end

  rrset "ftp.winebarrel.jp", "SRV" do
    ttl 123
    resource_records(
      "1   0   21  server01.example.jp",
      "2   0   21  server02.example.jp"
    )
  end

  rrset "www.winebarrel.jp", "AAAA" do
    ttl 123
    resource_records("::1")
  end
end

hosted_zone "333.222.111.in-addr.arpa" do
  rrset "444.333.222.111.in-addr.arpa", "PTR" do
    ttl 123
    resource_records("www.winebarrel.jp")
  end
end
EOS
        end

        expect(updated).to be_true

        zones = @route53.hosted_zones.to_a.sort_by {|i| i.name }
        expect(zones.length).to eq(3)

        ptr_zone = zones[0]
        expect(ptr_zone.name).to eq("333.222.111.in-addr.arpa.")
        expect(ptr_zone.resource_record_set_count).to eq(3)

        expect(ptr_zone.rrsets['333.222.111.in-addr.arpa.', 'NS'].ttl).to eq(172800)
        expect(ptr_zone.rrsets['333.222.111.in-addr.arpa.', 'SOA'].ttl).to eq(900)

        ptr = ptr_zone.rrsets['444.333.222.111.in-addr.arpa.', 'PTR']
        expect(ptr.name).to eq("444.333.222.111.in-addr.arpa.")
        expect(ptr.ttl).to eq(123)
        expect(rrs_list(ptr.resource_records)).to eq(["www.winebarrel.jp"])

        info_zone = zones[1]
        expect(info_zone.name).to eq("info.winebarrel.jp.")
        expect(info_zone.resource_record_set_count).to eq(3)

        expect(info_zone.rrsets['info.winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(info_zone.rrsets['info.winebarrel.jp.', 'SOA'].ttl).to eq(900)

        info_a = info_zone.rrsets['info.winebarrel.jp.', 'A']
        expect(info_a.name).to eq("info.winebarrel.jp.")
        expect(info_a.ttl).to eq(123)
        expect(rrs_list(info_a.resource_records)).to eq(["127.0.0.3", "127.0.0.4"])

        zone = zones[2]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(7)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a = zone.rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(123)
        expect(rrs_list(a.resource_records)).to eq(["127.0.0.1"])

        a_alias = zone.rrsets['elb.winebarrel.jp.', 'A']
        expect(a_alias.name).to eq("elb.winebarrel.jp.")
        expect(a_alias.alias_target).to eq({
          :hosted_zone_id => "Z2YN17T5R711GT",
          :dns_name => "roadworker-1619064454.ap-northeast-1.elb.amazonaws.com.",
          :evaluate_target_health => false,
        })

        txt = zone.rrsets['www.winebarrel.jp.', 'TXT']
        expect(txt.name).to eq("www.winebarrel.jp.")
        expect(txt.ttl).to eq(456)
        expect(rrs_list(txt.resource_records)).to eq([
          "\"v=spf1 +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/pra +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/mfrom +ip4:192.168.100.0/24 ~all\""
        ])

        srv = zone.rrsets['ftp.winebarrel.jp.', 'SRV']
        expect(srv.name).to eq("ftp.winebarrel.jp.")
        expect(srv.ttl).to eq(123)
        expect(rrs_list(srv.resource_records)).to eq([
          "1   0   21  server01.example.jp",
          "2   0   21  server02.example.jp"
        ])

        aaaa = zone.rrsets['www.winebarrel.jp.', 'AAAA']
        expect(aaaa.name).to eq("www.winebarrel.jp.")
        expect(aaaa.ttl).to eq(123)
        expect(rrs_list(aaaa.resource_records)).to eq(["::1"])
      }
    end

    context 'Change (force)' do
      it {
        updated = routefile(:force => true) do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
    )
  end

  rrset "elb.winebarrel.jp", "A" do
    dns_name "roadworker-1619064454.ap-northeast-1.elb.amazonaws.com"
  end

  rrset "www.winebarrel.jp", "TXT" do
    ttl 456
    resource_records(
      '"v=spf1 +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/pra +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/mfrom +ip4:192.168.100.0/24 ~all"'
    )
  end

  rrset "ftp.winebarrel.jp", "SRV" do
    ttl 123
    resource_records(
      "1   0   21  server01.example.jp",
      "2   0   21  server02.example.jp"
    )
  end

  rrset "www.winebarrel.jp", "AAAA" do
    ttl 123
    resource_records("::1")
  end
end

hosted_zone "333.222.111.in-addr.arpa" do
  rrset "444.333.222.111.in-addr.arpa", "PTR" do
    ttl 123
    resource_records("www.winebarrel.jp")
  end
end
EOS
        end

        expect(updated).to be_true

        zones = @route53.hosted_zones.to_a.sort_by {|i| i.name }
        expect(zones.length).to eq(2)

        ptr_zone = zones[0]
        expect(ptr_zone.name).to eq("333.222.111.in-addr.arpa.")
        expect(ptr_zone.resource_record_set_count).to eq(3)

        expect(ptr_zone.rrsets['333.222.111.in-addr.arpa.', 'NS'].ttl).to eq(172800)
        expect(ptr_zone.rrsets['333.222.111.in-addr.arpa.', 'SOA'].ttl).to eq(900)

        ptr = ptr_zone.rrsets['444.333.222.111.in-addr.arpa.', 'PTR']
        expect(ptr.name).to eq("444.333.222.111.in-addr.arpa.")
        expect(ptr.ttl).to eq(123)
        expect(rrs_list(ptr.resource_records)).to eq(["www.winebarrel.jp"])

        zone = zones[1]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(7)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a = zone.rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(123)
        expect(rrs_list(a.resource_records)).to eq(["127.0.0.1"])

        a_alias = zone.rrsets['elb.winebarrel.jp.', 'A']
        expect(a_alias.name).to eq("elb.winebarrel.jp.")
        expect(a_alias.alias_target).to eq({
          :hosted_zone_id => "Z2YN17T5R711GT",
          :dns_name => "roadworker-1619064454.ap-northeast-1.elb.amazonaws.com.",
          :evaluate_target_health => false,
        })

        txt = zone.rrsets['www.winebarrel.jp.', 'TXT']
        expect(txt.name).to eq("www.winebarrel.jp.")
        expect(txt.ttl).to eq(456)
        expect(rrs_list(txt.resource_records)).to eq([
          "\"v=spf1 +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/pra +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/mfrom +ip4:192.168.100.0/24 ~all\""
        ])

        srv = zone.rrsets['ftp.winebarrel.jp.', 'SRV']
        expect(srv.name).to eq("ftp.winebarrel.jp.")
        expect(srv.ttl).to eq(123)
        expect(rrs_list(srv.resource_records)).to eq([
          "1   0   21  server01.example.jp",
          "2   0   21  server02.example.jp"
        ])

        aaaa = zone.rrsets['www.winebarrel.jp.', 'AAAA']
        expect(aaaa.name).to eq("www.winebarrel.jp.")
        expect(aaaa.ttl).to eq(123)
        expect(rrs_list(aaaa.resource_records)).to eq(["::1"])
      }
    end
  end
end
