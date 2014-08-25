describe Roadworker::DSL::Tester do
  it 'checks A record' do
    handler = proc do
      match('test.mydomain.org', Resolv::DNS::Resource::IN::A) do |tx|
        tx.respond!("10.0.0.80", :ttl => 300)
      end
    end

    failures = run_dns(<<-RUBY, :handler => handler)
      hosted_zone "mydomain.org." do
        rrset "test.mydomain.org.", "A" do
          ttl 300
          resource_records(
            "10.0.0.80"
          )
        end
      end
    RUBY

    expect(failures).to eq(0)
  end

  it 'checks PTR record' do
    handler = proc do
      match('80.0.0.10.in-addr.arpa', Resolv::DNS::Resource::IN::PTR) do |tx|
        tx.respond!(Resolv::DNS::Name.create('test.mydomain.org.'), :ttl => 300)
      end
    end

    failures = run_dns(<<-RUBY, :handler => handler)
      hosted_zone "0.0.10.in-addr.arpa." do
        rrset "80.0.0.10.in-addr.arpa.", "PTR" do
          ttl 300
          resource_records(
            "test.mydomain.org."
          )
        end
      end
    RUBY

    expect(failures).to eq(0)
  end

  it 'checks TXT record' do
    handler = proc do
      match('test.mydomain.org', Resolv::DNS::Resource::IN::TXT) do |tx|
        tx.respond!('v=spf1 +ip4:192.168.100.0/24 ~all', :ttl => 300)
      end
    end

    failures = run_dns(<<-RUBY, :handler => handler)
      hosted_zone "mydomain.org." do
        rrset "test.mydomain.org.", "TXT" do
          ttl 300
          resource_records(
            '"v=spf1 +ip4:192.168.100.0/24 ~all"'
          )
        end
      end
    RUBY

    expect(failures).to eq(0)
  end

  it 'checks CNAME record' do
    handler = proc do
      match('test.mydomain.org', Resolv::DNS::Resource::IN::CNAME) do |tx|
        tx.respond!(Resolv::DNS::Name.create('test2.mydomain.org.'), :ttl => 300)
      end
    end

    failures = run_dns(<<-RUBY, :handler => handler)
      hosted_zone "mydomain.org." do
        rrset "test.mydomain.org.", "CNAME" do
          ttl 300
          resource_records(
            "test2.mydomain.org."
          )
        end
      end
    RUBY

    expect(failures).to eq(0)
  end
end
