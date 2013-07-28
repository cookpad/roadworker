$: << File.expand_path("#{File.dirname __FILE__}/../lib")
$: << File.expand_path("#{File.dirname __FILE__}/../spec")

require 'rubygems'
require 'roadworker'
require 'spec_helper'
require 'fileutils'
require 'logger'

describe Roadworker::Client do
  before(:each) {
    AWS.config({
      :access_key_id => (ENV['TEST_AWS_ACCESS_KEY_ID'] || 'scott'),
      :secret_access_key => (ENV['TEST_AWS_SECRET_ACCESS_KEY'] || 'tiger'),
    })

    routefile(:force => true) { '' }
    @route53 = AWS::Route53.new
  }

  after(:all) do
    routefile(:force => true) { '' }
  end

  context 'Delete' do
    context 'HostedZone' do
      before do
        routefile do
<<EOS
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
        end
      end

      it {
        routefile { '' }

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

    context 'HostedZone (force)' do
      before do
        routefile do
<<EOS
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
        end
      end

      it {
        routefile(:force => true) { '' }

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(0)
      }
    end
  end
end
