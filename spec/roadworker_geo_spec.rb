describe Roadworker::Client do
  context 'when update A record with geo location' do
    before {
      routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp.", "A" do
    set_identifier "www1"
    ttl 300
    geo_location :continent_code=>"AS"
    resource_records(
      "127.0.0.1"
    )
  end

  rrset "www.winebarrel.jp.", "A" do
    set_identifier "www2"
    ttl 300
    geo_location :continent_code=>"OC"
    resource_records(
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
  rrset "www.winebarrel.jp.", "A" do
    set_identifier "www1"
    ttl 300
    geo_location :continent_code=>"AS"
    resource_records(
      "127.0.0.1"
    )
  end

  rrset "www.winebarrel.jp.", "A" do
    set_identifier "www2"
    ttl 300
    geo_location :continent_code=>"EU"
    resource_records(
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

      www1 = zone.rrsets["www.winebarrel.jp.", 'A', 'www1']
      expect(www1.name).to eq("www.winebarrel.jp.")
      expect(www1.ttl).to eq(300)
      expect(www1.resource_records).to eq [{:value=>"127.0.0.1"}]
      expect(www1.geo_location).to eq({:continent_code=>"AS"})

      www2 = zone.rrsets["www.winebarrel.jp.", 'A', 'www2']
      expect(www2.name).to eq("www.winebarrel.jp.")
      expect(www2.ttl).to eq(300)
      expect(www2.resource_records).to eq [{:value=>"127.0.0.2"}]
      expect(www2.geo_location).to eq({:continent_code=>"EU"})
    }
  end
end
