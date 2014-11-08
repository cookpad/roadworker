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
      :region,
      :geo_location,
      :failover,
      :health_check,
    ]

    RRSET_ATTRS_WITH_TYPE = [:type] + RRSET_ATTRS

    def initialize(options)
      @options = options
    end

    def export
      Exporter.export(@options)
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
          yield(HostedZoneWrapper.new(zone, zone.vpcs, @options))
        end
      end

      def create(name, opts = {})
        vpc = opts[:vpc]
        vpcs = vpc ? [vpc] : []

        logmsg = 'Create HostedZone'
        logmsg << " #{vpc.inspect}"
        log(:info, logmsg, :cyan, name)

        if @options.dry_run
          opts.delete(:vpc)
          zone = OpenStruct.new({:name => name, :rrsets => [], :vpcs => vpcs}.merge(opts))
        else
          zone = @hosted_zones.create(name, opts)
          @options.hosted_zone_name = name
          @options.updated = true
        end

        HostedZoneWrapper.new(zone, vpcs, @options)
      end
    end # HostedZoneCollection

    class HostedZoneWrapper
      include Roadworker::Log

      def initialize(hosted_zone, vpcs, options)
        @hosted_zone = hosted_zone
        @vpcs = vpcs
        @options = options
      end

      attr_reader :vpcs

      def resource_record_sets
        ResourceRecordSetCollectionWrapper.new(@hosted_zone.rrsets, @hosted_zone, @options)
      end
      alias rrsets resource_record_sets

      def delete
        if @options.force
          log(:info, 'Delete HostedZone', :red, @hosted_zone.name)

          self.rrsets.each do |record|
            record.delete
          end

          unless @options.dry_run
            @hosted_zone.delete
            @options.updated = true
          end
        else
          log(:info, 'Undefined HostedZone (pass `--force` if you want to remove)', :yellow, @hosted_zone.name)
        end
      end

      def delete
        if @options.force
          log(:info, 'Delete HostedZone', :red, @hosted_zone.name)

          self.rrsets.each do |record|
            record.delete
          end

          unless @options.dry_run
            @hosted_zone.delete
            @options.updated = true
          end
        else
          log(:info, 'Undefined HostedZone (pass `--force` if you want to remove)', :yellow, @hosted_zone.name)
        end
      end

      def associate_vpc(vpc)
        log(:info, "Associate #{vpc.inspect}", :green, @hosted_zone.name)
        @hosted_zone.associate_vpc(vpc) unless @options.dry_run
      end

      def disassociate_vpc(vpc)
        log(:info, "Disassociate #{vpc.inspect}", :red, @hosted_zone.name)
        @hosted_zone.disassociate_vpc(vpc) unless @options.dry_run
      end

      private

      def method_missing(method_name, *args)
        @hosted_zone.send(method_name, *args)
      end
    end # HostedZoneWrapper

    class ResourceRecordSetCollectionWrapper
      include Roadworker::Log

      def initialize(resource_record_sets, hosted_zone, options)
        @resource_record_sets = resource_record_sets
        @hosted_zone = hosted_zone
        @options = options
      end

      def each
        Collection.batch(@resource_record_sets) do |record|
          yield(ResourceRecordSetWrapper.new(record, @hosted_zone, @options))
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

          Route53Wrapper::RRSET_ATTRS.each do |attribute|
            value = expected_record.send(attribute)
            next unless value

            case attribute
            when :dns_name
              attribute = :alias_target
              dns_name, dns_name_opts = value
              value = AWS::Route53.dns_name_to_alias_target(dns_name, dns_name_opts, @hosted_zone.id, @hosted_zone.name || @options.hosted_zone_name)
            when :health_check
              attribute = :health_check_id
              value = @options.health_checks.find_or_create(value)
            end

            opts[attribute] = value
          end

          record = @resource_record_sets.create(name, type, opts)
          @options.updated = true
        end

        ResourceRecordSetWrapper.new(record, @hosted_zone, @options)
      end
    end # ResourceRecordSetCollectionWrapper

    class ResourceRecordSetWrapper
      include Roadworker::Log

      def initialize(resource_record_set, hosted_zone, options)
        @resource_record_set = resource_record_set
        @hosted_zone = hosted_zone
        @options = options
      end

      def eql?(expected_record)
        Route53Wrapper::RRSET_ATTRS_WITH_TYPE.all? do |attribute|
          expected = expected_record.send(attribute)
          expected = expected.sort_by {|i| i.to_s } if expected.kind_of?(Array)
          expected = nil if expected.kind_of?(Array) && expected.empty?
          actual = self.send(attribute)
          actual = actual.sort_by {|i| i.to_s } if actual.kind_of?(Array)
          actual = nil if actual.kind_of?(Array) && actual.empty?

          if !expected and !actual
            true
          elsif expected and actual
            case attribute
            when :dns_name
              expected[0] = expected[0].downcase.sub(/\.\Z/, '')
              actual[0] = actual[0].downcase.sub(/\.\Z/, '')
            end

            (expected == actual)
          else
            false
          end
        end
      end

      def update(expected_record)
        log_id_proc = proc do
          log_id = [self.name, self.type].join(' ')
          rrset_setid = self.set_identifier
          rrset_setid ? (log_id + " (#{rrset_setid})") : log_id
        end

        log(:info, 'Update ResourceRecordSet', :green, &log_id_proc)

        Route53Wrapper::RRSET_ATTRS_WITH_TYPE.each do |attribute|
          expected = expected_record.send(attribute)
          expected = expected.sort_by {|i| i.to_s } if expected.kind_of?(Array)
          expected = nil if expected.kind_of?(Array) && expected.empty?
          actual = self.send(attribute)
          actual = actual.sort_by {|i| i.to_s } if actual.kind_of?(Array)
          actual = nil if actual.kind_of?(Array) && actual.empty?

          if (expected and !actual) or (!expected and actual)
            log(:info, "  set #{attribute}=#{expected.inspect}" , :green)
            self.send(:"#{attribute}=", expected) unless @options.dry_run
          elsif expected and actual
            if expected != actual
              log(:info, "  set #{attribute}=#{expected.inspect}" , :green)
              self.send(:"#{attribute}=", expected) unless @options.dry_run
            end
          end
        end

        unless @options.dry_run
          @resource_record_set.update
          @options.updated = true
        end
      end

      def delete
        if self.type =~ /\A(SOA|NS)\Z/i
          hz_name = (@hosted_zone.name || @options.hosted_zone_name).downcase.sub(/\.\Z/, '')
          rrs_name = @resource_record_set.name.downcase.sub(/\.\Z/, '')
          return if hz_name == rrs_name
        end

        log(:info, 'Delete ResourceRecordSet', :red) do
          log_id = [self.name, self.type].join(' ')
          rrset_setid = self.set_identifier
          rrset_setid ? (log_id + " (#{rrset_setid})") : log_id
        end

        unless @options.dry_run
          @resource_record_set.delete
          @options.updated = true
        end
      end

      def name
        value = @resource_record_set.name
        value ? value.gsub("\\052", '*') : value
      end

      def dns_name
        alias_target = @resource_record_set.alias_target || {}
        dns_name = alias_target[:dns_name]

        if dns_name
          [
            dns_name,
            AWS::Route53.normalize_dns_name_options(alias_target),
          ]
        else
          nil
        end
      end

      def dns_name=(value)
        if value
          dns_name, dns_name_opts = value
          @resource_record_set.alias_target = AWS::Route53.dns_name_to_alias_target(dns_name, dns_name_opts, @hosted_zone.id, @hosted_zone.name || @options.hosted_zone_name)
        else
          @resource_record_set.alias_target = nil
        end
      end

      def health_check
        @options.health_checks[@resource_record_set.health_check_id]
      end

      def health_check=(check)
        health_check_id = check ? @options.health_checks.find_or_create(check) : nil
        @resource_record_set.health_check_id = health_check_id
      end

      private

      def method_missing(method_name, *args)
        @resource_record_set.send(method_name, *args)
      end
    end # ResourceRecordSetWrapper

  end # Route53Wrapper
end # Roadworker
