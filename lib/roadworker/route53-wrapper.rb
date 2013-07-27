require 'ostruct'

module Roadworker
  class Route53Wrapper

    def initialize(route53, options)
      @route53 = route53
      @options = options
    end

    def export
      result = []

      batch(@route53.hosted_zones) do |zone|
        zone_h = item_to_hash(zone, :name)
        result << zone_h

        rrsets = []
        zone_h[:rrsets] = rrsets

        batch(zone.rrsets) do |record|
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
    end # export

    def item_to_hash(item, *attrs)
      h = {}

      attrs.each do |attr|
        value = item.send(attr)
        h[attr] = value if value
      end

      return h
    end
    private :item_to_hash

    def hosted_zones
      HostedZoneCollectionWrapper(@route53.hosted_zones, @options)
    end

    class HostedZoneCollectionWrapper
      def initialize(hosted_zones, options)
        @hosted_zones = hosted_zones
        @options = options
      end

      def each
        batch(@hosted_zones) do |zone|
          yield(HostedZoneWrapper.new(zone, @options))
        end
      end

      def create(name, opts = {})
        if @options[:dry_run]
          zone = OpenStruct.new({:name => name, :rrsets => []}.merge(opts))
        else
          zone = @hosted_zones.create(name, opts)
        end

        HostedZoneWrapper.new(zone, @options)
      end
    end # HostedZoneCollection
 
    class HostedZoneWrapper
      def initialize(hosted_zone, options)
        @hosted_zone = hosted_zone
        @options = options
      end

      def resource_record_sets
        ResourceRecordSetCollectionWrapper.new(hosted_zone.rrsets, @options)
      end
      alias rrsets resource_record_sets

      def delete
        if @options[:dry_run]
          # ...
        else
          @hosted_zone.delete
        end
      end

      private

      def method_missing(method_name, *args)
        @resource_record_set.send(method_name, *args)
      end
    end # HostedZoneWrapper

    class ResourceRecordSetCollectionWrapper
      def initialize(resource_record_sets, options)
        @resource_record_sets = resource_record_sets
        @options = options
      end

      def each
        batch(@resource_record_sets) do |record|
          yield(ResourceRecordSetWrapper.new(record, @options))
        end
      end

      def create(name, type, opts = {})
        if @options[:dry_run]
          record = OpenStruct.new({:name => name, :type => type}.merge(opts))
        else
          record = @resource_record_sets.create(name, type, opts)
        end

        ResourceRecordSetWrapper.new(record, @options)
      end
    end # ResourceRecordSetCollectionWrapper

    def ResourceRecordSetWrapper
      def initialize(resource_record_set, options)
        @resource_record_set = resource_record_set
        @options = options
      end

      def update
        if @options[:dry_run]
          # ...
        else
          @resource_record_set.update
        end
      end

      def delete
        if @options[:dry_run]
          # ...
        else
          @resource_record_set.delete
        end
      end

      def resource_records(*value)
        @resource_record_set.resource_records = values.map {|i| {:value => i} }
      end

      def dns_name(name)
        name += '.' unless name =~ /\.\Z/

        unless name =~ /([^.]+)\.elb\.amazonaws.com\.\Z/i
          raise "Invalid DNS Name: #{name}"
        end

        region = $1.downcase

        elb = AWS::ELB.new({
          :access_key_id     => @options[:access_key_id],
          :secret_access_key => @options[:secret_access_key],
          :region            => region,
        })

        load_balancer = elb.load_balancers.find do |lb|
          lb.dns_name =~ /\A#{Regexp.escape(name)}\Z/i
        end

        unless load_balancers
          raise "Cannot find ELB: #{name}"
        end

        @resource_record_set.alias_target = {
          :hosted_zone_id         => load_balancers.canonical_hosted_zone_name_id,
          :dns_name               => load_balancers.dns_name,
          :evaluate_target_health => false, # XXX:
        }
      end

      private

      def method_missing(method_name, *args)
        @resource_record_set.send(method_name, *args)
      end
    end # ResourceRecordSetWrapper

    private
    def batch(collection)
      AWS.memoize {
        collection.each_batch do |batch|
          batch.each do |item|
            yield(item)
          end
        end
      }
    end

  end # Route53Wrapper
end # Roadworker
