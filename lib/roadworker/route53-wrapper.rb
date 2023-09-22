module Roadworker
  class Route53Wrapper
    RRSET_ATTRS = %i[
      set_identifier
      weight
      ttl
      resource_records
      dns_name
      region
      geo_location
      failover
      health_check
    ]

    RRSET_ATTRS_WITH_TYPE = [:type] + RRSET_ATTRS

    def initialize(options)
      @options = options
    end

    def export
      Exporter.export(@options)
    end

    def hosted_zones
      HostedzoneCollectionWrapper.new(
        @options.route53.list_hosted_zones,
        @options
      )
    end

    class HostedzoneCollectionWrapper
      include Roadworker::Log

      def initialize(hosted_zones_response, options)
        @hosted_zones_response = hosted_zones_response
        @options = options
      end

      def each
        Collection.batch(@hosted_zones_response, :hosted_zones) do |zone|
          resp = @options.route53.get_hosted_zone(id: zone.id)
          yield(HostedzoneWrapper.new(resp.hosted_zone, resp.vp_cs, @options))
        end
      end

      def create(name, opts = {})
        if vpc = opts[:vpc]
          vpcs = [vpc]
        else
          vpcs = []
          opts.delete(:vpc)
        end

        logmsg = "Create Hostedzone"
        logmsg << " #{vpc.inspect}"
        log(:info, logmsg, :cyan, name)

        if @options.dry_run
          opts.delete(:vpc)
          zone =
            OpenStruct.new({ name: name, rrsets: [], vpcs: vpcs }.merge(opts))
        else
          params = {
            name: name,
            caller_reference:
              "roadworker #{Roadworker::VERSION} #{UUID.new.generate}"
          }
          params[:vpc] = vpc if vpc
          zone = @options.route53.create_hosted_zone(params).hosted_zone
          @options.hosted_zone_name = name
          @options.updated = true
        end

        HostedzoneWrapper.new(zone, vpcs, @options)
      end
    end # HostedzoneCollection

    class HostedzoneWrapper
      include Roadworker::Log

      def initialize(hosted_zone, vpcs, options)
        @hosted_zone = hosted_zone
        @vpcs = vpcs
        @options = options
      end

      attr_reader :vpcs

      def resource_record_sets
        @resource_record_sets ||=
          ResourceRecordSetCollectionWrapper.new(@hosted_zone, @options)
      end
      alias rrsets resource_record_sets

      # @return [Roadworker::Route53Wrapper::ResourceRecordSetWrapper]
      def find_resource_record_set(name, type, set_identifier)
        resource_record_sets.to_h[[name, type, set_identifier]]
      end

      def delete
        if @options.force
          log(:info, "Delete Hostedzone", :red, @hosted_zone.name)

          change_batch =
            Batch.new(
              self,
              health_checks: @options.health_checks,
              logger: @options.logger,
              dry_run: @options.dry_run,
              colorized: @options.color
            )
          self.rrsets.each { |record| change_batch.delete(record) }

          change_batch.request!(@options.route53)

          unless @options.dry_run
            @options.route53.delete_hosted_zone(id: @hosted_zone.id)
            @options.updated = true
          end
        else
          log(
            :info,
            "Undefined Hostedzone (pass `--force` if you want to remove)",
            :yellow,
            @hosted_zone.name
          )
        end
      end

      def associate_vpc(vpc)
        log(:info, "Associate #{vpc.inspect}", :green, @hosted_zone.name)
        unless @options.dry_run
          @options.route53.associate_vpc_with_hosted_zone(
            hosted_zone_id: @hosted_zone.id,
            vpc: vpc
          )
        end
      end

      def disassociate_vpc(vpc)
        log(:info, "Disassociate #{vpc.inspect}", :red, @hosted_zone.name)
        unless @options.dry_run
          @options.route53.disassociate_vpc_from_hosted_zone(
            hosted_zone_id: @hosted_zone.id,
            vpc: vpc
          )
        end
      end

      private

      def method_missing(method_name, *args)
        @hosted_zone.send(method_name, *args)
      end
    end # HostedzoneWrapper

    class ResourceRecordSetCollectionWrapper
      include Roadworker::Log

      def initialize(hosted_zone, options)
        @hosted_zone = hosted_zone
        @options = options
      end

      # @return [Hash<Array<(String,String,String)>, Roadworker::Route53Wrapper::ResourceRecordSetWrapper>]
      def to_h
        return @hash if defined?(@hash)
        @hash = {}

        self.each do |item|
          @hash[[item.name, item.type, item.set_identifier]] = item
        end

        @hash
      end

      def each
        if @hosted_zone.id
          Collection.batch(
            @options.route53.list_resource_record_sets(
              hosted_zone_id: @hosted_zone.id
            ),
            :resource_record_sets
          ) do |record|
            yield(ResourceRecordSetWrapper.new(record, @hosted_zone, @options))
          end
        end
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
          expected = expected_record.public_send(attribute)
          expected =
            Aws::Route53.sort_rrset_values(
              attribute,
              expected
            ) if expected.kind_of?(Array)
          expected = nil if expected.kind_of?(Array) && expected.empty?
          actual = self.public_send(attribute)
          actual =
            Aws::Route53.sort_rrset_values(
              attribute,
              actual
            ) if actual.kind_of?(Array)
          actual = nil if actual.kind_of?(Array) && actual.empty?

          if attribute == :geo_location and actual
            actual = Hash[actual.each_pair.select { |k, v| not v.nil? }]
          end

          if !expected and !actual
            true
          elsif expected and actual
            case attribute
            when :health_check
              if actual[:alarm_identifier]
                actual[:alarm_identifier] = actual[:alarm_identifier].to_h
              end
            when :dns_name
              expected[0] = expected[0].downcase.sub(/\.\z/, "")
              actual[0] = actual[0].downcase.sub(/\.\z/, "")

              if expected[0] !~ /\Adualstack\./i and
                   actual[0] =~ /\Adualstack\./i
                log(
                  :warn,
                  "`dualstack` prefix is used in the actual DNS name",
                  :yellow
                ) do
                  log_id = [self.name, self.type].join(" ")
                  rrset_setid = self.set_identifier
                  rrset_setid ? (log_id + " (#{rrset_setid})") : log_id
                end

                actual[0].sub!(/\Adualstack\./i, "")
              end
            end

            (expected == actual)
          else
            false
          end
        end
      end

      def name
        value = @resource_record_set.name
        value ? value.gsub("\\052", "*") : value
      end

      def dns_name
        alias_target = @resource_record_set.alias_target || {}
        dns_name = alias_target[:dns_name]

        if dns_name
          [dns_name, Aws::Route53.normalize_dns_name_options(alias_target)]
        else
          nil
        end
      end

      def health_check
        @options.health_checks[@resource_record_set.health_check_id]
      end

      private

      def method_missing(method_name, *args)
        @resource_record_set.send(method_name, *args)
      end
    end # ResourceRecordSetWrapper
  end # Route53Wrapper
end # Roadworker
