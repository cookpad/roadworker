require 'roadworker/collection'
require 'roadworker/log'
require 'roadworker/route53-exporter'
require 'roadworker/route53-ext'

require 'ostruct'

module Roadworker
  class Route53Wrapper

    RRSET_ATTRS = [
      :set_identifier,
      :weight,
      :ttl,
      :resource_records,
      :dns_name,
      :region
    ]

    def initialize(options)
      @options = options
    end

    def export
      Exporter.export(@options.route53)
    end

    def hosted_zones
      HostedZoneCollectionWrapper.new(@options.route53.hosted_zones, @options)
    end

    class HostedZoneCollectionWrapper
      include Roadworker::Log

      def initialize(hosted_zones, options)
        @hosted_zones = hosted_zones
        @options = options
      end

      def each
        Collection.batch(@hosted_zones) do |zone|
          yield(HostedZoneWrapper.new(zone, @options))
        end
      end

      def create(name, opts = {})
        log(:info, 'Create HostedZone', :cyan, name)

        if @options.dry_run
          zone = OpenStruct.new({:name => name, :rrsets => []}.merge(opts))
        else
          zone = @hosted_zones.create(name, opts)
        end

        HostedZoneWrapper.new(zone, @options)
      end
    end # HostedZoneCollection
 
    class HostedZoneWrapper
      include Roadworker::Log

      def initialize(hosted_zone, options)
        @hosted_zone = hosted_zone
        @options = options
      end

      def resource_record_sets
        ResourceRecordSetCollectionWrapper.new(@hosted_zone.rrsets, @options)
      end
      alias rrsets resource_record_sets

      def delete
        if @options.force
          log(:info, 'Delete HostedZone', :red, @hosted_zone.name)
          @hosted_zone.delete unless @options.dry_run
        else
          log(:info, 'Undefined HostedZone (pass `--force` if you want to remove)', :yellow, @hosted_zone.name)
        end
      end

      private

      def method_missing(method_name, *args)
        @hosted_zone.send(method_name, *args)
      end
    end # HostedZoneWrapper

    class ResourceRecordSetCollectionWrapper
      include Roadworker::Log

      def initialize(resource_record_sets, options)
        @resource_record_sets = resource_record_sets
        @options = options
      end

      def each
        Collection.batch(@resource_record_sets) do |record|
          yield(ResourceRecordSetWrapper.new(record, @options))
        end
      end

      def create(name, type, expected_record)
        log(:info, 'Create ResourceRecordSet', :cyan) do 
          log_id = [name, type].join(' ')
          rrset_setid = expected_record.set_identifier
          rrset_setid ? (log_id + " (#{rrset_setid})") : log_id
        end

        if @options.dry_run
          record = expected_record
        else
          opts = {}

          Route53Wrapper::RRSET_ATTRS.each do |attr|
            value = expected_record.send(attr)
            next unless value

            case attr
            when :dns_name
              attr = :alias_target
              value = @options.route53.dns_name_to_alias_target(value)
            end

            opts[attr] = value
          end

          record = @resource_record_sets.create(name, type, opts)
        end

        ResourceRecordSetWrapper.new(record, @options)
      end
    end # ResourceRecordSetCollectionWrapper

    class ResourceRecordSetWrapper
      include Roadworker::Log

      def initialize(resource_record_set, options)
        @resource_record_set = resource_record_set
        @options = options
      end

      def eql?(expected_record)
        Route53Wrapper::RRSET_ATTRS.all? do |attr|
          expected = expected_record.send(attr)
          expected = nil if expected.kind_of?(Array) && expected.empty?
          actual = self.send(attr)
          actual = nil if actual.kind_of?(Array) && actual.empty?

          if !expected and !actual
            true
          elsif expected and actual
            case attr
            when :resource_records
              expected = expected.sort_by {|i| i[:value] }
              actual = actual.sort_by {|i| i[:value] }
            end

            (expected == actual)
          else
            false
          end
        end
      end

      def update(expected_record)
        log(:info, 'Update ResourceRecordSet', :green) do
          log_id = [@resource_record_set.name, @resource_record_set.type].join(' ')
          rrset_setid = @resource_record_set.set_identifier
          rrset_setid ? (log_id + " (#{rrset_setid})") : log_id
        end

        Route53Wrapper::RRSET_ATTRS.each do |attr|
          expected = expected_record.send(attr)
          expected = nil if expected.kind_of?(Array) && expected.empty?
          actual = self.send(attr)
          actual = nil if actual.kind_of?(Array) && actual.empty?

          if (expected and !actual) or (!expected and actual)
            log(:info, "  set #{attr}=#{expected.inspect}" , :green) do
              log_id = [@resource_record_set.name, @resource_record_set.type].join(' ')
              rrset_setid = @resource_record_set.set_identifier
              rrset_setid ? (log_id + " (#{rrset_setid})") : log_id
            end

            self.send(:"#{attr}=", expected) unless @options.dry_run
          elsif expected and actual
            case attr
            when :resource_records
              expected = expected.sort_by {|i| i[:value] }
              actual = actual.sort_by {|i| i[:value] }
            end

            if expected != actual
              log(:info, "  set #{attr}=#{expected.inspect}" , :green) do
                log_id = [@resource_record_set.name, @resource_record_set.type].join(' ')
                rrset_setid = @resource_record_set.set_identifier
                rrset_setid ? (log_id + " (#{rrset_setid})") : log_id
              end

              self.send(:"#{attr}=", expected) unless @options.dry_run
            end
          end
        end

        @resource_record_set.update unless @options.dry_run
      end

      def delete(opts = {})
        return if type =~ /\A(SOA|NS)\Z/i
        if not opts[:cascaded] or @options.force
          log(:info, 'Delete ResourceRecordSet', :red) do
            log_id = [@resource_record_set.name, @resource_record_set.type].join(' ')
            rrset_setid = @resource_record_set.set_identifier
            rrset_setid ? (log_id + " (#{rrset_setid})") : log_id
          end
        end

        @resource_record_set.delete unless @options.dry_run
      end

      def dns_name=(name)
        if name
          @resource_record_set.alias_target = @options.route53.dns_name_to_alias_target(name)
        else
          @resource_record_set.alias_target = nil
        end
      end

      def dns_name
        (@resource_record_set.alias_target || {})[:dns_name]
      end

      private

      def method_missing(method_name, *args)
        @resource_record_set.send(method_name, *args)
      end
    end # ResourceRecordSetWrapper

  end # Route53Wrapper
end # Roadworker
