require 'roadworker/collection'

require 'ostruct'

module Roadworker
  class Exporter

    class << self
      def export(route53)
        self.new(route53).export
      end
    end # of class method

    def initialize(route53)
      @route53 = route53
    end

    def export
      result = []

      Collection.batch(@route53.hosted_zones) do |zone|
        zone_h = item_to_hash(zone, :name)
        result << zone_h

        rrsets = []
        zone_h[:rrsets] = rrsets

        Collection.batch(zone.rrsets) do |record|
          attrs = [
            :name,
            :type,
            :set_identifier,
            :weight,
            :ttl,
            :resource_records,
            :alias_target,
            :region,
          ]

          record_h = item_to_hash(record, *attrs)
          rrsets << record_h

          rrs = record_h.delete(:resource_records)
          record_h[:resource_records] = rrs.map {|i| i[:value] }

          if (alias_target = record_h.delete(:alias_target))
            record_h[:dns_name] = alias_target[:dns_name]
          end
        end
      end

      return result
    end

    private

    def item_to_hash(item, *attrs)
      h = {}

      attrs.each do |attr|
        value = item.send(attr)
        h[attr] = value if value
      end

      return h
    end

  end # Exporter
end # Roadworker
