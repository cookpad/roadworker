describe Roadworker::Client do
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
    health_check "tcp://192.0.43.10:3306", :request_interval => 30, :failure_threshold => 4
    ttl 456
    resource_records(
      "127.0.0.5",
      "127.0.0.6"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "http://192.0.43.10:80/path", :request_interval => 30, :failure_threshold => 4, :measure_latency => true, :inverted => true
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
    health_check "http://192.0.43.10:80/path", :host => 'example.com', :search_string => '123', :request_interval => 10, :failure_threshold => 5, :measure_latency => true, :inverted => true
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "https://192.0.43.10/path", :host => 'example.com', :search_string => '123', :request_interval => 10, :failure_threshold => 10
    ttl 4560
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

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)

          a1 = rrsets['www.winebarrel.jp.', 'A', "Primary"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('Primary')
          expect(a1.failover).to eq('PRIMARY')
          expect(a1.ttl).to eq(123)
          expect(rrs_list(a1.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])
          expect(check_list[a1.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => '192.0.43.10',
            :port => 80,
            :type => 'HTTP_STR_MATCH',
            :resource_path => '/path',
            :fully_qualified_domain_name => 'example.com',
            :search_string => '123',
            :request_interval => 10,
            :failure_threshold => 5,
            :measure_latency => true,
            :inverted => true,
            :child_health_checks => [],
            :enable_sni => false,
          ))

          a2 = rrsets['www.winebarrel.jp.', 'A', "Secondary"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('Secondary')
          expect(a2.failover).to eq('SECONDARY')
          expect(a2.ttl).to eq(4560)
          expect(rrs_list(a2.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => '192.0.43.10',
            :port => 443,
            :type => 'HTTPS_STR_MATCH',
            :resource_path => '/path',
            :fully_qualified_domain_name => 'example.com',
            :search_string => '123',
            :request_interval => 10,
            :failure_threshold => 10,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))
        }
      end

      context 'HTTPS?_STR_MATCH (Use domain only)' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "tcp://192.0.43.10:3306", :request_interval => 30, :failure_threshold => 4
    ttl 456
    resource_records(
      "127.0.0.5",
      "127.0.0.6"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "http://192.0.43.10:80/path", :request_interval => 30, :failure_threshold => 4
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
    health_check "http://example.com:80/path", :search_string => '123', :request_interval => 10, :failure_threshold => 5
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "https://example.com/path", :search_string => '123', :request_interval => 10, :failure_threshold => 10
    ttl 4560
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

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)

          a1 = rrsets['www.winebarrel.jp.', 'A', "Primary"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('Primary')
          expect(a1.failover).to eq('PRIMARY')
          expect(a1.ttl).to eq(123)
          expect(rrs_list(a1.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])
          expect(check_list[a1.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :port => 80,
            :type => 'HTTP_STR_MATCH',
            :resource_path => '/path',
            :fully_qualified_domain_name => 'example.com',
            :search_string => '123',
            :request_interval => 10,
            :failure_threshold => 5,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))

          a2 = rrsets['www.winebarrel.jp.', 'A', "Secondary"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('Secondary')
          expect(a2.failover).to eq('SECONDARY')
          expect(a2.ttl).to eq(4560)
          expect(rrs_list(a2.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :port => 443,
            :type => 'HTTPS_STR_MATCH',
            :resource_path => '/path',
            :fully_qualified_domain_name => 'example.com',
            :search_string => '123',
            :request_interval => 10,
            :failure_threshold => 10,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))
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

          zones = fetch_hosted_zones(@route53)
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(4)

          rrsets = fetch_rrsets(@route53, zone.id)
          expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)

          a1 = rrsets['www.winebarrel.jp.', 'A', "Primary"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('Primary')
          expect(a1.failover).to eq('PRIMARY')
          expect(a1.ttl).to eq(123)
          expect(rrs_list(a1.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])
          expect(check_list[a1.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => '192.0.43.10',
            :port => 80,
            :type => 'HTTP',
            :resource_path => '/path',
            :request_interval => 30,
            :failure_threshold => 3,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))

          a2 = rrsets['www.winebarrel.jp.', 'A', "Secondary"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('Secondary')
          expect(a2.failover).to eq('SECONDARY')
          expect(a2.ttl).to eq(4560)
          expect(rrs_list(a2.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => '192.0.43.10',
            :port => 3306,
            :type => 'TCP',
            :request_interval => 30,
            :failure_threshold => 3,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))
        }
      end

      context 'Failover -> Failover (Use domain only)' do
        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "tcp://example.com:3306"
    ttl 456
    resource_records(
      "127.0.0.5",
      "127.0.0.6"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "http://example.com:80/path"
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
    health_check "http://example.com:80/path2"
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "tcp://example.com:3307"
    ttl 4560
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

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)

          a1 = rrsets['www.winebarrel.jp.', 'A', "Primary"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('Primary')
          expect(a1.failover).to eq('PRIMARY')
          expect(a1.ttl).to eq(123)
          expect(rrs_list(a1.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])
          expect(check_list[a1.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :fully_qualified_domain_name => 'example.com',
            :port => 80,
            :type => 'HTTP',
            :resource_path => '/path2',
            :request_interval => 30,
            :failure_threshold => 3,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))

          a2 = rrsets['www.winebarrel.jp.', 'A', "Secondary"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('Secondary')
          expect(a2.failover).to eq('SECONDARY')
          expect(a2.ttl).to eq(4560)
          expect(rrs_list(a2.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :fully_qualified_domain_name => 'example.com',
            :port => 3307,
            :type => 'TCP',
            :request_interval => 30,
            :failure_threshold => 3,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))
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

          zones = fetch_hosted_zones(@route53)
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(3)

          rrsets = fetch_rrsets(@route53, zone.id)
          expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(0)

          a1 = rrsets['www.winebarrel.jp.', 'A', "Primary"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('Primary')
          expect(a1.failover).to be_nil
          expect(a1.weight).to eq(100)
          expect(a1.ttl).to eq(456)
          expect(rrs_list(a1.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])
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

          zones = fetch_hosted_zones(@route53)
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(3)

          rrsets = fetch_rrsets(@route53, zone.id)
          expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(1)

          a2 = rrsets['www.winebarrel.jp.', 'A', "Secondary"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('Secondary')
          expect(a2.weight).to be_nil
          expect(a2.failover).to eq('SECONDARY')
          expect(a2.ttl).to eq(456)
          expect(rrs_list(a2.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => '192.0.43.10',
            :port => 3306,
            :type => 'TCP',
            :request_interval => 30,
            :failure_threshold => 3,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))
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

          zones = fetch_hosted_zones(@route53)
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(4)

          rrsets = fetch_rrsets(@route53, zone.id)
          expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)

          a1 = rrsets['www.winebarrel.jp.', 'A', "w100"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('w100')
          expect(a1.weight).to eq(70)
          expect(a1.ttl).to eq(456)
          expect(rrs_list(a1.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])
          expect(check_list[a1.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => '192.0.43.10',
            :port => 80,
            :type => 'HTTP',
            :resource_path => '/path',
            :request_interval => 30,
            :failure_threshold => 3,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))

          a2 = rrsets['www.winebarrel.jp.', 'A', "w50"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('w50')
          expect(a2.weight).to eq(90)
          expect(a2.ttl).to eq(456)
          expect(rrs_list(a2.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => '192.0.43.10',
            :port => 3306,
            :type => 'TCP',
            :request_interval => 30,
            :failure_threshold => 3,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))
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

          zones = fetch_hosted_zones(@route53)
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(4)

          rrsets = fetch_rrsets(@route53, zone.id)
          expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)

          a1 = rrsets['www.winebarrel.jp.', 'A', "jp"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('jp')
          expect(a1.region).to eq('ap-northeast-1')
          expect(a1.ttl).to eq(123)
          expect(rrs_list(a1.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.5", "127.0.0.6"])
          expect(check_list[a1.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => '192.0.43.10',
            :port => 80,
            :type => 'HTTP',
            :resource_path => '/path',
            :request_interval => 30,
            :failure_threshold => 3,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))

          a2 = rrsets['www.winebarrel.jp.', 'A', "us"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('us')
          expect(a2.region).to eq('us-east-1')
          expect(a2.ttl).to eq(4560)
          expect(rrs_list(a2.resource_records.sort_by {|i| i.to_s })).to eq( ["127.0.0.7", "127.0.0.8"])
          expect(check_list[a2.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => '192.0.43.10',
            :port => 3306,
            :type => 'TCP',
            :request_interval => 30,
            :failure_threshold => 3,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))
        }
      end

      context 'CALCULATED' do
        let(:health_check_ids) { [] }

        before {
          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
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
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end

  rrset "www2.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check :calculated => #{health_check_ids.inspect}, :health_threshold => 1, :inverted => false
    ttl 500
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
          check_list = nil
          sleep 10

          60.times do
            check_list = fetch_health_checks(@route53)
            break if check_list.length == 2
            sleep 1
          end

          health_check_ids.concat(check_list.keys)

          routefile do
<<EOS
hosted_zone "winebarrel.jp" do
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
    health_check "http://192.0.43.10:80/path"
    ttl 456
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end

  rrset "www2.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check :calculated => #{[health_check_ids[0]].inspect}, :health_threshold => 2, :inverted => true
    ttl 500
    resource_records(
      "127.0.0.5",
      "127.0.0.6"
    )
  end
end
EOS
          end

          zones = fetch_hosted_zones(@route53)
          expect(zones.length).to eq(1)

          zone = zones[0]
          expect(zone.name).to eq("winebarrel.jp.")
          expect(zone.resource_record_set_count).to eq(5)

          rrsets = fetch_rrsets(@route53, zone.id)
          expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
          expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

          check_list = fetch_health_checks(@route53)
          expect(check_list.length).to eq(2)

          a1 = rrsets['www.winebarrel.jp.', 'A', "Primary"]
          expect(a1.name).to eq("www.winebarrel.jp.")
          expect(a1.set_identifier).to eq('Primary')
          expect(a1.failover).to eq('PRIMARY')
          expect(a1.ttl).to eq(456)
          expect(rrs_list(a1.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])
          expect(check_list[a1.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => '192.0.43.10',
            :port => 80,
            :type => 'HTTP',
            :resource_path => '/path',
            :request_interval => 30,
            :failure_threshold => 3,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))

          a2 = rrsets['www.winebarrel.jp.', 'A', "Secondary"]
          expect(a2.name).to eq("www.winebarrel.jp.")
          expect(a2.set_identifier).to eq('Secondary')
          expect(a2.failover).to eq('SECONDARY')
          expect(a2.ttl).to eq(456)
          expect(rrs_list(a2.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
          expect(check_list[a2.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => '192.0.43.10',
            :port => 80,
            :type => 'HTTP',
            :resource_path => '/path',
            :request_interval => 30,
            :failure_threshold => 3,
            :measure_latency => false,
            :inverted => false,
            :child_health_checks => [],
            :enable_sni => false,
          ))

          a3 = rrsets['www2.winebarrel.jp.', 'A', "Primary"]
          expect(a3.name).to eq("www2.winebarrel.jp.")
          expect(a3.set_identifier).to eq('Primary')
          expect(a3.failover).to eq('PRIMARY')
          expect(a3.ttl).to eq(500)
          expect(rrs_list(a3.resource_records.sort_by {|i| i.to_s })).to eq(["127.0.0.5", "127.0.0.6"])
          expect(check_list[a3.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
            :ip_address => nil,
            :port => nil,
            :type => 'CALCULATED',
            :resource_path => nil,
            :request_interval => nil,
            :failure_threshold => nil,
            :health_threshold => 2,
            :measure_latency => nil,
            :inverted => true,
            :child_health_checks => [health_check_ids[0]],
          ))
        }
      end
    end
  end
end
