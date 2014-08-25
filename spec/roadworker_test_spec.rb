describe Roadworker::DSL::Tester do
  it 'checks A record' do
    handler = proc do
      match(/test.mydomain.org/, Resolv::DNS::Resource::IN::A) do |tx|
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
end
