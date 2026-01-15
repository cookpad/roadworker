describe Roadworker::Client do
  context 'Mix' do
    before(:each) {
      routefile do
        <<~EOS
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
              dns_name TEST_ELB
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

            rrset "fo.winebarrel.jp", "A" do
              set_identifier "Primary"
              failover "PRIMARY"
              health_check "tcp://192.0.43.10:3306"
              ttl 456
              resource_records(
                "127.0.0.5",
                "127.0.0.6"
              )
            end

            rrset "fo.winebarrel.jp", "A" do
              set_identifier "Secondary"
              failover "SECONDARY"
              ttl 456
              health_check "http://192.0.43.10:80/path", :host => 'example.com'
              resource_records(
                "127.0.0.7",
                "127.0.0.8"
              )
            end
          end
        EOS
      end
    }

    context 'No change' do
      it {
        updated = routefile do
          <<~EOS
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
                dns_name TEST_ELB
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

              rrset "fo.winebarrel.jp", "A" do
                set_identifier "Primary"
                failover "PRIMARY"
                health_check "tcp://192.0.43.10:3306"
                ttl 456
                resource_records(
                  "127.0.0.5",
                  "127.0.0.6"
                )
              end

              rrset "fo.winebarrel.jp", "A" do
                set_identifier "Secondary"
                failover "SECONDARY"
                ttl 456
                health_check "http://192.0.43.10:80/path", :host => 'example.com'
                resource_records(
                  "127.0.0.7",
                  "127.0.0.8"
                )
              end
            end
          EOS
        end

        expect(updated).to be_falsey

        zones = fetch_hosted_zones(@route53).sort_by { |i| i.name }
        expect(zones.length).to eq(2)

        info_zone = zones[0]
        expect(info_zone.name).to eq("info.winebarrel.jp.")
        expect(info_zone.resource_record_set_count).to eq(3)

        info_rrsets = fetch_rrsets(@route53, info_zone.id)
        expect(info_rrsets['info.winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(info_rrsets['info.winebarrel.jp.', 'SOA'].ttl).to eq(900)

        info_a = info_rrsets['info.winebarrel.jp.', 'A']
        expect(info_a.name).to eq("info.winebarrel.jp.")
        expect(info_a.ttl).to eq(123)
        expect(rrs_list(info_a.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])

        zone = zones[1]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(8)

        rrsets = fetch_rrsets(@route53, zone.id)
        expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a = rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(123)
        expect(rrs_list(a.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])

        a_alias = rrsets['elb.winebarrel.jp.', 'A']
        expect(a_alias.name).to eq("elb.winebarrel.jp.")
        expect(a_alias.alias_target).to eq(Aws::Route53::Types::AliasTarget.new(
          hosted_zone_id: "Z14GRHDCWA56QT",
          dns_name: "dualstack." + TEST_ELB,
          evaluate_target_health: false,
        ))

        txt = rrsets['www.winebarrel.jp.', 'TXT']
        expect(txt.name).to eq("www.winebarrel.jp.")
        expect(txt.ttl).to eq(123)
        expect(rrs_list(txt.resource_records.sort_by { |i| i.to_s })).to eq([
          "\"spf2.0/mfrom +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/pra +ip4:192.168.100.0/24 ~all\"",
          "\"v=spf1 +ip4:192.168.100.0/24 ~all\"",
        ])

        mx = rrsets['www.winebarrel.jp.', 'MX']
        expect(mx.name).to eq("www.winebarrel.jp.")
        expect(mx.ttl).to eq(123)
        expect(rrs_list(mx.resource_records.sort_by { |i| i.to_s })).to eq(["10 mail.winebarrel.jp", "20 mail2.winebarrel.jp"])

        check_list = fetch_health_checks(@route53)
        expect(check_list.length).to eq(2)

        fo_p = rrsets['fo.winebarrel.jp.', 'A', "Primary"]
        expect(fo_p.name).to eq("fo.winebarrel.jp.")
        expect(fo_p.set_identifier).to eq('Primary')
        expect(fo_p.failover).to eq('PRIMARY')
        expect(fo_p.ttl).to eq(456)
        expect(rrs_list(fo_p.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.5", "127.0.0.6"])
        expect(check_list[fo_p.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
          ip_address: '192.0.43.10',
          port: 3306,
          type: 'TCP',
          request_interval: 30,
          failure_threshold: 3,
          measure_latency: false,
          inverted: false,
          child_health_checks: [],
          enable_sni: false,
          regions: [],
        ))

        fo_s = rrsets['fo.winebarrel.jp.', 'A', "Secondary"]
        expect(fo_s.name).to eq("fo.winebarrel.jp.")
        expect(fo_s.set_identifier).to eq('Secondary')
        expect(fo_s.failover).to eq('SECONDARY')
        expect(fo_s.ttl).to eq(456)
        expect(rrs_list(fo_s.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.7", "127.0.0.8"])
        expect(check_list[fo_s.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
          ip_address: '192.0.43.10',
          port: 80,
          type: 'HTTP',
          resource_path: '/path',
          fully_qualified_domain_name: 'example.com',
          request_interval: 30,
          failure_threshold: 3,
          measure_latency: false,
          inverted: false,
          child_health_checks: [],
          enable_sni: false,
          regions: [],
        ))
      }
    end

    context 'Normalization' do
      it {
        updated = routefile do
          <<~EOS
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
                dns_name TEST_ELB
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

              rrset "fo.winebarrel.jp", "A" do
                set_identifier "Primary"
                failover "PRIMARY"
                health_check "tcp://192.0.43.10:3306"
                ttl 456
                resource_records(
                  "127.0.0.5",
                  "127.0.0.6"
                )
              end

              rrset "FO.WINEBARREL.JP", "A" do
                set_identifier "Secondary"
                failover "SECONDARY"
                ttl 456
                health_check "http://192.0.43.10:80/path", :host => 'example.com'
                resource_records(
                  "127.0.0.7",
                  "127.0.0.8"
                )
              end
            end
          EOS
        end

        expect(updated).to be_falsey

        zones = fetch_hosted_zones(@route53).sort_by { |i| i.name }
        expect(zones.length).to eq(2)

        info_zone = zones[0]
        expect(info_zone.name).to eq("info.winebarrel.jp.")
        expect(info_zone.resource_record_set_count).to eq(3)

        info_rrsets = fetch_rrsets(@route53, info_zone.id)
        expect(info_rrsets['info.winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(info_rrsets['info.winebarrel.jp.', 'SOA'].ttl).to eq(900)

        info_a = info_rrsets['info.winebarrel.jp.', 'A']
        expect(info_a.name).to eq("info.winebarrel.jp.")
        expect(info_a.ttl).to eq(123)
        expect(rrs_list(info_a.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])

        zone = zones[1]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(8)

        rrsets = fetch_rrsets(@route53, zone.id)
        expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a = rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(123)
        expect(rrs_list(a.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])

        a_alias = rrsets['elb.winebarrel.jp.', 'A']
        expect(a_alias.name).to eq("elb.winebarrel.jp.")
        expect(a_alias.alias_target).to eq(Aws::Route53::Types::AliasTarget.new(
          hosted_zone_id: "Z14GRHDCWA56QT",
          dns_name: "dualstack." + TEST_ELB,
          evaluate_target_health: false,
        ))

        txt = rrsets['www.winebarrel.jp.', 'TXT']
        expect(txt.name).to eq("www.winebarrel.jp.")
        expect(txt.ttl).to eq(123)
        expect(rrs_list(txt.resource_records.sort_by { |i| i.to_s })).to eq([
          "\"spf2.0/mfrom +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/pra +ip4:192.168.100.0/24 ~all\"",
          "\"v=spf1 +ip4:192.168.100.0/24 ~all\"",
        ])

        mx = rrsets['www.winebarrel.jp.', 'MX']
        expect(mx.name).to eq("www.winebarrel.jp.")
        expect(mx.ttl).to eq(123)
        expect(rrs_list(mx.resource_records.sort_by { |i| i.to_s })).to eq(["10 mail.winebarrel.jp", "20 mail2.winebarrel.jp"])

        check_list = fetch_health_checks(@route53)
        expect(check_list.length).to eq(2)

        fo_p = rrsets['fo.winebarrel.jp.', 'A', "Primary"]
        expect(fo_p.name).to eq("fo.winebarrel.jp.")
        expect(fo_p.set_identifier).to eq('Primary')
        expect(fo_p.failover).to eq('PRIMARY')
        expect(fo_p.ttl).to eq(456)
        expect(rrs_list(fo_p.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.5", "127.0.0.6"])
        expect(check_list[fo_p.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
          ip_address: '192.0.43.10',
          port: 3306,
          type: 'TCP',
          request_interval: 30,
          failure_threshold: 3,
          measure_latency: false,
          inverted: false,
          child_health_checks: [],
          enable_sni: false,
          regions: [],
        ))

        fo_s = rrsets['fo.winebarrel.jp.', 'A', "Secondary"]
        expect(fo_s.name).to eq("fo.winebarrel.jp.")
        expect(fo_s.set_identifier).to eq('Secondary')
        expect(fo_s.failover).to eq('SECONDARY')
        expect(fo_s.ttl).to eq(456)
        expect(rrs_list(fo_s.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.7", "127.0.0.8"])
        expect(check_list[fo_s.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
          ip_address: '192.0.43.10',
          port: 80,
          type: 'HTTP',
          resource_path: '/path',
          fully_qualified_domain_name: 'example.com',
          request_interval: 30,
          failure_threshold: 3,
          measure_latency: false,
          inverted: false,
          child_health_checks: [],
          enable_sni: false,
          regions: [],
        ))
      }
    end

    context 'Change' do
      it {
        updated = routefile do
          <<~EOS
            hosted_zone "winebarrel.jp" do
              rrset "www.winebarrel.jp", "A" do
                ttl 123
                resource_records(
                  "127.0.0.1",
                )
              end

              rrset "elb.winebarrel.jp", "A" do
                dns_name TEST_ELB
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

              rrset "fo.winebarrel.jp", "A" do
                set_identifier "Primary"
                failover "PRIMARY"
                health_check "http://192.0.43.10:80/path", :host => 'example.com'
                ttl 456
                resource_records(
                  "127.0.0.1",
                  "127.0.0.2"
                )
              end

              rrset "fo.winebarrel.jp", "A" do
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

            hosted_zone "333.222.111.in-addr.arpa" do
              rrset "444.333.222.111.in-addr.arpa", "PTR" do
                ttl 123
                resource_records("www.winebarrel.jp")
              end
            end
          EOS
        end

        expect(updated).to be_truthy

        zones = fetch_hosted_zones(@route53).sort_by { |i| i.name }
        expect(zones.length).to eq(3)

        ptr_zone = zones[0]
        expect(ptr_zone.name).to eq("333.222.111.in-addr.arpa.")
        expect(ptr_zone.resource_record_set_count).to eq(3)

        ptr_rrsets = fetch_rrsets(@route53, ptr_zone.id)
        expect(ptr_rrsets['333.222.111.in-addr.arpa.', 'NS'].ttl).to eq(172800)
        expect(ptr_rrsets['333.222.111.in-addr.arpa.', 'SOA'].ttl).to eq(900)

        ptr = ptr_rrsets['444.333.222.111.in-addr.arpa.', 'PTR']
        expect(ptr.name).to eq("444.333.222.111.in-addr.arpa.")
        expect(ptr.ttl).to eq(123)
        expect(rrs_list(ptr.resource_records.sort_by { |i| i.to_s })).to eq(["www.winebarrel.jp"])

        info_zone = zones[1]
        expect(info_zone.name).to eq("info.winebarrel.jp.")
        expect(info_zone.resource_record_set_count).to eq(3)

        info_rrsets = fetch_rrsets(@route53, info_zone.id)
        expect(info_rrsets['info.winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(info_rrsets['info.winebarrel.jp.', 'SOA'].ttl).to eq(900)

        info_a = info_rrsets['info.winebarrel.jp.', 'A']
        expect(info_a.name).to eq("info.winebarrel.jp.")
        expect(info_a.ttl).to eq(123)
        expect(rrs_list(info_a.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])

        zone = zones[2]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(9)

        rrsets = fetch_rrsets(@route53, zone.id)
        expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a = rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(123)
        expect(rrs_list(a.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.1"])

        a_alias = rrsets['elb.winebarrel.jp.', 'A']
        expect(a_alias.name).to eq("elb.winebarrel.jp.")
        expect(a_alias.alias_target).to eq(Aws::Route53::Types::AliasTarget.new(
          hosted_zone_id: "Z14GRHDCWA56QT",
          dns_name: "dualstack." + TEST_ELB,
          evaluate_target_health: false,
        ))

        txt = rrsets['www.winebarrel.jp.', 'TXT']
        expect(txt.name).to eq("www.winebarrel.jp.")
        expect(txt.ttl).to eq(456)
        expect(rrs_list(txt.resource_records.sort_by { |i| i.to_s })).to eq([
          "\"spf2.0/mfrom +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/pra +ip4:192.168.100.0/24 ~all\"",
          "\"v=spf1 +ip4:192.168.100.0/24 ~all\"",
        ])

        srv = rrsets['ftp.winebarrel.jp.', 'SRV']
        expect(srv.name).to eq("ftp.winebarrel.jp.")
        expect(srv.ttl).to eq(123)
        expect(rrs_list(srv.resource_records.sort_by { |i| i.to_s })).to eq([
          "1   0   21  server01.example.jp",
          "2   0   21  server02.example.jp",
        ])

        aaaa = rrsets['www.winebarrel.jp.', 'AAAA']
        expect(aaaa.name).to eq("www.winebarrel.jp.")
        expect(aaaa.ttl).to eq(123)
        expect(rrs_list(aaaa.resource_records.sort_by { |i| i.to_s })).to eq(["::1"])
        check_list = fetch_health_checks(@route53)
        expect(check_list.length).to eq(2)

        fo_p = rrsets['fo.winebarrel.jp.', 'A', "Primary"]
        expect(fo_p.name).to eq("fo.winebarrel.jp.")
        expect(fo_p.set_identifier).to eq('Primary')
        expect(fo_p.failover).to eq('PRIMARY')
        expect(fo_p.ttl).to eq(456)
        expect(rrs_list(fo_p.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.1", "127.0.0.2"])
        expect(check_list[fo_p.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
          ip_address: '192.0.43.10',
          port: 80,
          type: 'HTTP',
          resource_path: '/path',
          fully_qualified_domain_name: 'example.com',
          request_interval: 30,
          failure_threshold: 3,
          measure_latency: false,
          inverted: false,
          child_health_checks: [],
          enable_sni: false,
          regions: [],
        ))

        fo_s = rrsets['fo.winebarrel.jp.', 'A', "Secondary"]
        expect(fo_s.name).to eq("fo.winebarrel.jp.")
        expect(fo_s.set_identifier).to eq('Secondary')
        expect(fo_s.failover).to eq('SECONDARY')
        expect(fo_s.ttl).to eq(456)
        expect(rrs_list(fo_s.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.3", "127.0.0.4"])
        expect(check_list[fo_s.health_check_id]).to eq(Aws::Route53::Types::HealthCheckConfig.new(
          ip_address: '192.0.43.10',
          port: 3306,
          type: 'TCP',
          request_interval: 30,
          failure_threshold: 3,
          measure_latency: false,
          inverted: false,
          child_health_checks: [],
          enable_sni: false,
          regions: [],
        ))
      }
    end

    context 'Change (force)' do
      it {
        updated = routefile(force: true) do
          <<~EOS
            hosted_zone "winebarrel.jp" do
              rrset "www.winebarrel.jp", "A" do
                ttl 123
                resource_records(
                  "127.0.0.1",
                )
              end

              rrset "elb.winebarrel.jp", "A" do
                dns_name TEST_ELB
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

        expect(updated).to be_truthy

        zones = fetch_hosted_zones(@route53).sort_by { |i| i.name }
        expect(zones.length).to eq(2)

        ptr_zone = zones[0]
        expect(ptr_zone.name).to eq("333.222.111.in-addr.arpa.")
        expect(ptr_zone.resource_record_set_count).to eq(3)

        ptr_rrsets = fetch_rrsets(@route53, ptr_zone.id)
        expect(ptr_rrsets['333.222.111.in-addr.arpa.', 'NS'].ttl).to eq(172800)
        expect(ptr_rrsets['333.222.111.in-addr.arpa.', 'SOA'].ttl).to eq(900)

        ptr = ptr_rrsets['444.333.222.111.in-addr.arpa.', 'PTR']
        expect(ptr.name).to eq("444.333.222.111.in-addr.arpa.")
        expect(ptr.ttl).to eq(123)
        expect(rrs_list(ptr.resource_records.sort_by { |i| i.to_s })).to eq(["www.winebarrel.jp"])

        zone = zones[1]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(7)

        rrsets = fetch_rrsets(@route53, zone.id)
        expect(rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a = rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(123)
        expect(rrs_list(a.resource_records.sort_by { |i| i.to_s })).to eq(["127.0.0.1"])

        a_alias = rrsets['elb.winebarrel.jp.', 'A']
        expect(a_alias.name).to eq("elb.winebarrel.jp.")
        expect(a_alias.alias_target).to eq(Aws::Route53::Types::AliasTarget.new(
          hosted_zone_id: "Z14GRHDCWA56QT",
          dns_name: "dualstack." + TEST_ELB,
          evaluate_target_health: false,
        ))

        txt = rrsets['www.winebarrel.jp.', 'TXT']
        expect(txt.name).to eq("www.winebarrel.jp.")
        expect(txt.ttl).to eq(456)
        expect(rrs_list(txt.resource_records.sort_by { |i| i.to_s })).to eq([
          "\"spf2.0/mfrom +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/pra +ip4:192.168.100.0/24 ~all\"",
          "\"v=spf1 +ip4:192.168.100.0/24 ~all\"",
        ])

        srv = rrsets['ftp.winebarrel.jp.', 'SRV']
        expect(srv.name).to eq("ftp.winebarrel.jp.")
        expect(srv.ttl).to eq(123)
        expect(rrs_list(srv.resource_records.sort_by { |i| i.to_s })).to eq([
          "1   0   21  server01.example.jp",
          "2   0   21  server02.example.jp",
        ])

        aaaa = rrsets['www.winebarrel.jp.', 'AAAA']
        expect(aaaa.name).to eq("www.winebarrel.jp.")
        expect(aaaa.ttl).to eq(123)
        expect(rrs_list(aaaa.resource_records.sort_by { |i| i.to_s })).to eq(["::1"])
      }
    end
  end
end
