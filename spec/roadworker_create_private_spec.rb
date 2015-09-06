describe Roadworker::Client do
  context 'Create private' do
    context 'A record' do
      it {
        routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  vpc TEST_VPC_REGION, TEST_VPC1
  vpc TEST_VPC_REGION, TEST_VPC2

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

        zones = fetch_hosted_zones(@route53)
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(3)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        expect(zone.vpcs).to match_array [
          {:vpc_region => TEST_VPC_REGION, :vpc_id => TEST_VPC1},
          {:vpc_region => TEST_VPC_REGION, :vpc_id => TEST_VPC2},
        ]

        a = zone.rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(123)
        expect(rrs_list(a.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end
  end
end
