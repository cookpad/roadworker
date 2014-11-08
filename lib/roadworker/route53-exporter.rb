require 'roadworker/collection'
require 'roadworker/route53-health-check'

require 'ostruct'

module Roadworker
  class Exporter

    class << self
      def export(route53)
        self.new(route53).export
      end
    end # of class method

    def initialize(options)
      @options = options
    end

    def export
      result = {
        :health_checks => HealthCheck.health_checks(@options.route53),
      }

      hosted_zones = result[:hosted_zones] = []
      export_hosted_zones(hosted_zones)

      return result
    end

    private

    def export_hosted_zones(hosted_zones)
      Collection.batch(@options.route53.hosted_zones) do |zone|
        zone_h = item_to_hash(zone, :name, :vpcs)

        if @options.target_zone
          next unless zone_h[:name] =~ @options.target_zone
        end

        hosted_zones << zone_h

        rrsets = []
        zone_h[:rrsets] = rrsets

        Collection.batch(zone.rrsets) do |record|
          if record.name == zone.name and %w(SOA NS).include?(record.type) and not @options.with_soa_ns
            next
          end

          attrs = [
            :name,
            :type,
            :set_identifier,
            :weight,
            :ttl,
            :resource_records,
            :alias_target,
            :region,
            :geo_location,
            :failover,
            :health_check_id,
          ]

          record_h = item_to_hash(record, *attrs)
          record_h[:name].gsub!("\\052", '*') if record_h[:name]
          rrsets << record_h

          rrs = record_h.delete(:resource_records)
          record_h[:resource_records] = rrs.map {|i| i[:value] }

          if (alias_target = record_h.delete(:alias_target))
            record_h[:dns_name] = alias_target[:dns_name]

            if alias_target[:evaluate_target_health]
              record_h[:dns_name] = [
                record_h[:dns_name],
                {:evaluate_target_health => alias_target[:evaluate_target_health]}
              ]
            end
          end
        end
      end
    end

    def item_to_hash(item, *attrs)
      h = {}

      attrs.each do |attribute|
        value = item.send(attribute)
        h[attribute] = value if value
      end

      return h
    end

  end # Exporter
end # Roadworker
