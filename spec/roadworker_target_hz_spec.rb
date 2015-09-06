describe Roadworker::Client do
  context 'Target HostedZone' do
    context 'target' do
      it {
        routefile(:target_zone => /winebarrel/) do
<<-EOS
hosted_zone "winebarrel.jp" do
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

        zones = fetch_hosted_zones(@route53)
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(4)

        rrsets = fetch_rrsets(@route53, zone.id)
        expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a1 = rrsets['www.winebarrel.jp.', 'A', "web server 1"]
        expect(a1.name).to eq("www.winebarrel.jp.")
        expect(a1.set_identifier).to eq('web server 1')
        expect(a1.weight).to eq(100)
        expect(a1.ttl).to eq(456)
        expect(rrs_list(a1.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])

        a2 = rrsets['www.winebarrel.jp.', 'A', "web server 2"]
        expect(a2.name).to eq("www.winebarrel.jp.")
        expect(a2.set_identifier).to eq('web server 2')
        expect(a2.weight).to eq(50)
        expect(a2.ttl).to eq(456)
        expect(rrs_list(a2.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
      }
    end

    context 'non target' do
      it {
        routefile(:target_zone => /xwinebarrelx/) do
<<-EOS
hosted_zone "winebarrel.jp" do
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

        expect(fetch_hosted_zones(@route53)).to be_empty
      }
    end

    context 'exclude' do
      it {
        routefile(:exclude_zone => /winebarrel/) do
<<-EOS
hosted_zone "winebarrel.jp" do
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

        expect(fetch_hosted_zones(@route53)).to be_empty
      }
    end
  end
end
