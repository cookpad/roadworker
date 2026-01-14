describe Roadworker::Client do
  context 'Update private' do
    context 'associate' do
      before {
        routefile do
          <<~EOS
            hosted_zone "winebarrel.jp" do
              vpc TEST_VPC_REGION, TEST_VPC1

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
          <<~EOS
            hosted_zone "winebarrel.jp" do
              vpc TEST_VPC_REGION, TEST_VPC1
              vpc TEST_VPC_REGION, TEST_VPC2

              rrset "www.winebarrel.jp", "A" do
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

        zone = @route53.get_hosted_zone(id: zones[0].id)
        expect(zone.hosted_zone.name).to eq("winebarrel.jp.")
        expect(zone.hosted_zone.resource_record_set_count).to eq(3)

        rrsets = fetch_rrsets(@route53, zone.hosted_zone.id)
        expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        expect(zone.vp_cs).to match_array [
          Aws::Route53::Types::VPC.new(vpc_region: TEST_VPC_REGION, vpc_id: TEST_VPC1),
          Aws::Route53::Types::VPC.new(vpc_region: TEST_VPC_REGION, vpc_id: TEST_VPC2),
        ]

        a = rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(456)
        expect(rrs_list(a.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
      }
    end

    context 'disassociate' do
      before {
        routefile do
          <<~EOS
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
      }

      it {
        routefile do
          <<~EOS
            hosted_zone "winebarrel.jp" do
              vpc TEST_VPC_REGION, TEST_VPC1

              rrset "www.winebarrel.jp", "A" do
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

        zone = @route53.get_hosted_zone(id: zones[0].id)
        expect(zone.hosted_zone.name).to eq("winebarrel.jp.")
        expect(zone.hosted_zone.resource_record_set_count).to eq(3)

        rrsets = fetch_rrsets(@route53, zone.hosted_zone.id)
        expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        expect(zone.vp_cs).to match_array [
          Aws::Route53::Types::VPC.new(vpc_region: TEST_VPC_REGION, vpc_id: TEST_VPC1),
        ]

        a = rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(456)
        expect(rrs_list(a.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
      }
    end

    context 'both public/private' do
      before {
        routefile do
          <<~EOS
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
      }

      it {
        routefile do
          <<~EOS
            hosted_zone "winebarrel.jp" do
              vpc TEST_VPC_REGION, TEST_VPC1

              rrset "www.winebarrel.jp", "A" do
                ttl 456
                resource_records(
                  "127.0.0.3",
                  "127.0.0.4"
                )
              end
            end
          EOS
        end

        zones = fetch_hosted_zones(@route53).map { |z| @route53.get_hosted_zone(id: z.id) }.sort_by { |i| i.vp_cs.length }
        expect(zones.length).to eq(2)

        # Public
        zone1 = zones[0]
        expect(zone1.hosted_zone.name).to eq("winebarrel.jp.")
        expect(zone1.hosted_zone.resource_record_set_count).to eq(3)

        rrsets1 = fetch_rrsets(@route53, zone1.hosted_zone.id)
        expect(rrsets1['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(rrsets1['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        expect(zone1.vp_cs).to match_array []

        a1 = rrsets1['www.winebarrel.jp.', 'A']
        expect(a1.name).to eq("www.winebarrel.jp.")
        expect(a1.ttl).to eq(123)
        expect(rrs_list(a1.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])

        # Private
        zone2 = zones[1]
        expect(zone2.hosted_zone.name).to eq("winebarrel.jp.")
        expect(zone2.hosted_zone.resource_record_set_count).to eq(3)

        rrsets2 = fetch_rrsets(@route53, zone2.hosted_zone.id)
        expect(rrsets2['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(rrsets2['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        expect(zone2.vp_cs).to match_array [Aws::Route53::Types::VPC.new(vpc_region: TEST_VPC_REGION, vpc_id: TEST_VPC1)]

        a2 = rrsets2['www.winebarrel.jp.', 'A']
        expect(a2.name).to eq("www.winebarrel.jp.")
        expect(a2.ttl).to eq(456)
        expect(rrs_list(a2.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
      }
    end

    context 'both private/public' do
      before {
        routefile do
          <<~EOS
            hosted_zone "winebarrel.jp" do
              vpc TEST_VPC_REGION, TEST_VPC1

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
          <<~EOS
            hosted_zone "winebarrel.jp" do
              rrset "www.winebarrel.jp", "A" do
                ttl 456
                resource_records(
                  "127.0.0.3",
                  "127.0.0.4"
                )
              end
            end
          EOS
        end

        zones = fetch_hosted_zones(@route53).map { |z| @route53.get_hosted_zone(id: z.id) }.sort_by { |i| i.vp_cs.length }
        expect(zones.length).to eq(2)

        # Public
        zone1 = zones[0]
        expect(zone1.hosted_zone.name).to eq("winebarrel.jp.")
        expect(zone1.hosted_zone.resource_record_set_count).to eq(3)

        rrsets1 = fetch_rrsets(@route53, zone1.hosted_zone.id)
        expect(rrsets1['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(rrsets1['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        expect(zone1.vp_cs).to match_array []

        a1 = rrsets1['www.winebarrel.jp.', 'A']
        expect(a1.name).to eq("www.winebarrel.jp.")
        expect(a1.ttl).to eq(456)
        expect(rrs_list(a1.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])

        # Private
        zone2 = zones[1]
        expect(zone2.hosted_zone.name).to eq("winebarrel.jp.")
        expect(zone2.hosted_zone.resource_record_set_count).to eq(3)

        rrsets2 = fetch_rrsets(@route53, zone2.hosted_zone.id)
        expect(rrsets2['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(rrsets2['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        expect(zone2.vp_cs).to match_array [
          Aws::Route53::Types::VPC.new(vpc_region: TEST_VPC_REGION, vpc_id: TEST_VPC1),
        ]

        a2 = rrsets2['www.winebarrel.jp.', 'A']
        expect(a2.name).to eq("www.winebarrel.jp.")
        expect(a2.ttl).to eq(123)
        expect(rrs_list(a2.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end
  end
end
