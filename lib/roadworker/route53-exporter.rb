require 'roadworker/collection'

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
      result = {}
      health_checks = result[:health_checks] = {}
      hosted_zones = result[:hosted_zones] = []

      export_health_checks(health_checks)
      export_hosted_zones(hosted_zones)

      return result
    end

    private

    def export_health_checks(health_checks)
      is_truncated = true
      next_marker = nil

      while is_truncated
        opts = next_marker ? {:marker => next_marker} : {}
        response = @options.route53.client.list_health_checks(opts)

        response[:health_checks].each do |check|
          health_checks[check[:id]] = check[:health_check_config]
        end

        is_truncated = response[:is_truncated]
        next_marker = [:next_marker]
      end
    end

    def export_hosted_zones(hosted_zones)
      Collection.batch(@options.route53.hosted_zones) do |zone|
        zone_h = item_to_hash(zone, :name)
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
          end
        end
      end
    end

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
