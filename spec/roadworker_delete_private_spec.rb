describe Roadworker::Client do
  context 'Delete private' do
    context 'Private HostedZone (force)' do
      before do
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
      end

      it {
        routefile(:force => true) { '' }

        zones = fetch_hosted_zones(@route53)
        expect(zones.length).to eq(0)
      }
    end
  end
end
