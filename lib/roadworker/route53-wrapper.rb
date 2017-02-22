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
      HostedzoneCollectionWrapper.new(@options.route53.list_hosted_zones, @options)
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

        logmsg = 'Create Hostedzone'
        logmsg << " #{vpc.inspect}"
        log(:info, logmsg, :cyan, name)

        if @options.dry_run
          opts.delete(:vpc)
          zone = OpenStruct.new({:name => name, :rrsets => [], :vpcs => vpcs}.merge(opts))
        else
          params = {
            :name => name,
            :caller_reference => "roadworker #{Roadworker::VERSION} #{UUID.new.generate}",
          }
          if vpc
            params[:vpc] = vpc
          end
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
        ResourceRecordSetCollectionWrapper.new(@hosted_zone, @options)
      end
      alias rrsets resource_record_sets

      def delete
        if @options.force
          log(:info, 'Delete Hostedzone', :red, @hosted_zone.name)

          self.rrsets.each do |record|
            record.delete
          end

          unless @options.dry_run
            @options.route53.delete_hosted_zone(id: @hosted_zone.id)
            @options.updated = true
          end
        else
          log(:info, 'Undefined Hostedzone (pass `--force` if you want to remove)', :yellow, @hosted_zone.name)
        end
      end

      def associate_vpc(vpc)
        log(:info, "Associate #{vpc.inspect}", :green, @hosted_zone.name)
        unless @options.dry_run
          @options.route53.associate_vpc_with_hosted_zone(
            hosted_zone_id: @hosted_zone.id,
            vpc: vpc,
          )
        end
      end

      def disassociate_vpc(vpc)
        log(:info, "Disassociate #{vpc.inspect}", :red, @hosted_zone.name)
        unless @options.dry_run
          @options.route53.disassociate_vpc_from_hosted_zone(
            hosted_zone_id: @hosted_zone.id,
            vpc: vpc,
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

      def each
        if @hosted_zone.id
          Collection.batch(@options.route53.list_resource_record_sets(hosted_zone_id: @hosted_zone.id), :resource_record_sets) do |record|
            yield(ResourceRecordSetWrapper.new(record, @hosted_zone, @options))
          end
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
          resource_record_set_params = {
            name: name,
            type: type,
          }

          Route53Wrapper::RRSET_ATTRS.each do |attribute|
            value = expected_record.send(attribute)
            next unless value

            case attribute
            when :dns_name
              attribute = :alias_target
              dns_name, dns_name_opts = value
              value = Aws::Route53.dns_name_to_alias_target(dns_name, dns_name_opts, @hosted_zone.id, @hosted_zone.name || @options.hosted_zone_name)
            when :health_check
              attribute = :health_check_id
              value = @options.health_checks.find_or_create(value)
            end

            resource_record_set_params[attribute] = value
          end

          @options.route53.change_resource_record_sets(
            hosted_zone_id: @hosted_zone.id,
            change_batch: {
              changes: [
                {
                  action: 'CREATE',
                  resource_record_set: resource_record_set_params,
                },
              ],
            },
          )
          @options.updated = true
        end

        ResourceRecordSetWrapper.new(expected_record, @hosted_zone, @options)
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
          expected = expected.sort_by {|i| i.to_s } if expected.kind_of?(Array)
          expected = nil if expected.kind_of?(Array) && expected.empty?
          actual = self.public_send(attribute)
          actual = actual.sort_by {|i| i.to_s } if actual.kind_of?(Array)
          actual = nil if actual.kind_of?(Array) && actual.empty?

          if !expected and !actual
            true
          elsif expected and actual
            case attribute
            when :health_check
              if actual[:alarm_identifier]
                actual[:alarm_identifier] = actual[:alarm_identifier].to_h
              end
            when :dns_name
              expected[0] = expected[0].downcase.sub(/\.\z/, '')
              actual[0] = actual[0].downcase.sub(/\.\z/, '')

              if expected[0] !~ /\Adualstack\./i and actual[0] =~ /\Adualstack\./i
                log(:warn, "`dualstack` prefix is used in the actual DNS name", :yellow) do
                  log_id = [self.name, self.type].join(' ')
                  rrset_setid = self.set_identifier
                  rrset_setid ? (log_id + " (#{rrset_setid})") : log_id
                end

                actual[0].sub!(/\Adualstack\./i, '')
              end
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

        resource_record_set_prev = @resource_record_set.dup
        Route53Wrapper::RRSET_ATTRS_WITH_TYPE.each do |attribute|
          expected = expected_record.send(attribute)
          expected = expected.sort_by {|i| i.to_s } if expected.kind_of?(Array)
          expected = nil if expected.kind_of?(Array) && expected.empty?
          actual = self.send(attribute)
          actual = actual.sort_by {|i| i.to_s } if actual.kind_of?(Array)
          actual = nil if actual.kind_of?(Array) && actual.empty?

          # XXX: Fix for diff
          if attribute == :health_check and actual
            if (actual[:child_health_checks] || []).empty?
              actual[:child_health_checks] = []
            end

            if (actual[:regions] || []).empty?
              actual[:regions] = []
            end
          end

          if (expected and !actual) or (!expected and actual)
            log(:info, "  #{attribute}:\n".green + Roadworker::Utils.diff(actual, expected, :color => @options.color, :indent => '    '), false)
            unless @options.dry_run
              self.send(:"#{attribute}=", expected)
            end
          elsif expected and actual
            if expected != actual
              log(:info, "  #{attribute}:\n".green + Roadworker::Utils.diff(actual, expected, :color => @options.color, :indent => '    '), false)
              unless @options.dry_run
                self.send(:"#{attribute}=", expected)
              end
            end
          end
        end

        unless @options.dry_run
          @options.route53.change_resource_record_sets(
            hosted_zone_id: @hosted_zone.id,
            change_batch: {
              changes: [
                {
                  action: 'DELETE',
                  resource_record_set: resource_record_set_prev,
                },
                {
                  action: 'CREATE',
                  resource_record_set: @resource_record_set,
                },
              ],
            },
          )
          @options.updated = true
        end
      end

      def delete
        if self.type =~ /\A(SOA|NS)\z/i
          hz_name = (@hosted_zone.name || @options.hosted_zone_name).downcase.sub(/\.\z/, '')
          rrs_name = @resource_record_set.name.downcase.sub(/\.\z/, '')
          return if hz_name == rrs_name
        end

        log(:info, 'Delete ResourceRecordSet', :red) do
          log_id = [self.name, self.type].join(' ')
          rrset_setid = self.set_identifier
          rrset_setid ? (log_id + " (#{rrset_setid})") : log_id
        end

        unless @options.dry_run
          @options.route53.change_resource_record_sets(
            hosted_zone_id: @hosted_zone.id,
            change_batch: {
              changes: [
                {
                  action: 'DELETE',
                  resource_record_set: @resource_record_set,
                },
              ],
            },
          )
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
            Aws::Route53.normalize_dns_name_options(alias_target),
          ]
        else
          nil
        end
      end

      def dns_name=(value)
        if value
          dns_name, dns_name_opts = value
          @resource_record_set.alias_target = Aws::Route53.dns_name_to_alias_target(dns_name, dns_name_opts, @hosted_zone.id, @hosted_zone.name || @options.hosted_zone_name)
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
