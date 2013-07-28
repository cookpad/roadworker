$: << File.expand_path("#{File.dirname __FILE__}/../lib")
require 'rubygems'
require 'roadworker'
require 'fileutils'

def routefile(options = {})
  tempfile = `mktemp /tmp/#{File.basename(__FILE__)}.XXXXXX`.strip

  begin
    open(tempfile, 'wb') {|f| f.puts(yield) }
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

  it {
    expect(@route53.hosted_zones.to_a).to be_empty
  }

  it {
    routefile {
      <<-EOS
hosted_zone "winebarre.jp" do
end
      EOS
    }

    zones = @route53.hosted_zones.to_a
    expect(zones.length).to eq(1)

    zone = zones[0]
    expect(zone.name).to eq("winebarre.jp.")
    expect(zone.resource_record_set_count).to eq(2)

    expect(zone.rrsets['winebarre.jp.', 'NS'].ttl).to eq(172800)
    expect(zone.rrsets['winebarre.jp.', 'SOA'].ttl).to eq(900)
  }

  it {
    routefile {
      <<-EOS
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
    }

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
