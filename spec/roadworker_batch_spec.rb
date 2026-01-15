RSpec.describe Roadworker::Batch, skip_route53_setup: true do
  let(:hosted_zone) { double(Roadworker::Route53Wrapper::HostedzoneWrapper, name: 'winebarrel.jp.', id: nil) }
  let(:batch) do
    described_class.new(hosted_zone, dry_run: true, logger: double(Logger), health_checks: double(Roadworker::HealthCheck))
  end


  describe '#sort_key' do
    it 'prioritizes CNAME deletion over A creation' do
      batch.create(OpenStruct.new(name: 'winebarrel.jp.', type: 'A'))
      batch.delete(OpenStruct.new(name: 'winebarrel.jp.', type: 'CNAME'))
      allow(hosted_zone).to receive(:find_resource_record_set).with('winebarrel.jp.', 'CNAME', nil).and_return(
        Roadworker::Route53Wrapper::ResourceRecordSetWrapper.new(
          Aws::Route53::Types::ResourceRecordSet.new(
            type: 'CNAME',
            name: 'winebarrel.jp.',
          ),
          hosted_zone,
          {},
        )
      )
      sorted_operations = batch.operations.sort_by(&:sort_key)
      expect(sorted_operations.flat_map(&:changes)).to match([
        { action: 'DELETE', resource_record_set: hash_including(type: 'CNAME') },
        { action: 'CREATE', resource_record_set: hash_including(type: 'A') },
      ])
    end

    it 'prioritizes CNAME deletion over ALIAS creation' do
      batch.create(OpenStruct.new(name: 'winebarrel.jp.', type: 'A', dns_name: 'roadworker.cloudfront.net.'))
      batch.delete(OpenStruct.new(name: 'winebarrel.jp.', type: 'CNAME'))
      allow(hosted_zone).to receive(:find_resource_record_set).with('winebarrel.jp.', 'CNAME', nil).and_return(
        Roadworker::Route53Wrapper::ResourceRecordSetWrapper.new(
          Aws::Route53::Types::ResourceRecordSet.new(
            type: 'CNAME',
            name: 'winebarrel.jp.',
          ),
          hosted_zone,
          {},
        )
      )
      sorted_operations = batch.operations.sort_by(&:sort_key)
      expect(sorted_operations.flat_map(&:changes)).to match([
        { action: 'DELETE', resource_record_set: hash_including(type: 'CNAME') },
        { action: 'CREATE', resource_record_set: hash_including(type: 'A') },
      ])
    end

    it 'prioritizes A deletion over CNAME creation' do
      batch.create(OpenStruct.new(name: 'winebarrel.jp.', type: 'CNAME'))
      batch.delete(OpenStruct.new(name: 'winebarrel.jp.', type: 'A'))
      allow(hosted_zone).to receive(:find_resource_record_set).with('winebarrel.jp.', 'A', nil).and_return(
        Roadworker::Route53Wrapper::ResourceRecordSetWrapper.new(
          Aws::Route53::Types::ResourceRecordSet.new(
            type: 'A',
            name: 'winebarrel.jp.',
          ),
          hosted_zone,
          {},
        )
      )
      sorted_operations = batch.operations.sort_by(&:sort_key)
      expect(sorted_operations.flat_map(&:changes)).to match([
        { action: 'DELETE', resource_record_set: hash_including(type: 'A') },
        { action: 'CREATE', resource_record_set: hash_including(type: 'CNAME') },
      ])
    end

    it 'prioritizes ALIAS deletion over CNAME creation' do
      batch.create(OpenStruct.new(name: 'winebarrel.jp.', type: 'CNAME'))
      batch.delete(OpenStruct.new(name: 'winebarrel.jp.', type: 'A', dns_name: 'roadworker.cloudfront.net.'))
      allow(hosted_zone).to receive(:find_resource_record_set).with('winebarrel.jp.', 'A', nil).and_return(
        Roadworker::Route53Wrapper::ResourceRecordSetWrapper.new(
          Aws::Route53::Types::ResourceRecordSet.new(
            type: 'A',
            name: 'winebarrel.jp.',
          ),
          hosted_zone,
          {},
        )
      )
      sorted_operations = batch.operations.sort_by(&:sort_key)
      expect(sorted_operations.flat_map(&:changes)).to match([
        { action: 'DELETE', resource_record_set: hash_including(type: 'A') },
        { action: 'CREATE', resource_record_set: hash_including(type: 'CNAME') },
      ])
    end
  end
end
