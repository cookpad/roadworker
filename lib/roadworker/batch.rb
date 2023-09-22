module Roadworker
  class Batch
    include Log

    # @param [Roadworker::Route53Wrapper::HostedzoneWrapper] hosted_zone
    # @param [Roadworker::HealthCheck] health_checks
    def initialize(hosted_zone, dry_run:, logger:, health_checks:, colorized:)
      @hosted_zone = hosted_zone
      @dry_run = dry_run
      @logger = logger
      @health_checks = health_checks
      @colorized = colorized

      @operations = []
    end

    attr_reader :hosted_zone, :health_checks
    attr_reader :dry_run, :logger
    attr_reader :operations

    # @param [OpenStruct] rrset Roadworker::DSL::ResourceRecordSet#result
    def create(rrset)
      add_operation Create, rrset
    end

    # @param [OpenStruct] rrset Roadworker::DSL::ResourceRecordSet#result
    def update(rrset)
      add_operation Update, rrset
    end

    # @param [Roadworker::Route53Wrapper::ResourceRecordSetWrapper] rrset
    def delete(rrset)
      add_operation Delete, rrset
    end

    # @param [Aws::Route53::Client] route53
    # @return [Boolean] updated
    def request!(route53)
      sorted_operations = operations.sort_by(&:sort_key)

      batches = slice_operations(sorted_operations)
      batches.each_with_index do |batch, i|
        dispatch_batch!(route53, batch, i, batches.size)
      end

      sorted_operations.any? { |op| !op.changes.empty? }
    end

    def inspect
      "#<#{self.class.name}: #{operations.size} operations>"
    end

    def to_s
      inspect
    end

    private

    def dispatch_batch!(route53, batch, i, total)
      changes = batch.flat_map(&:changes)
      return if changes.empty?

      page = total > 1 ? " | #{i + 1}/#{total}" : nil
      log(
        :info,
        "=== Change batch: #{hosted_zone.name} | #{hosted_zone.id}#{hosted_zone.vpcs.empty? ? "" : " - private"}#{page}",
        :bold
      )
      batch.each { |operation| operation.diff!() }

      if dry_run
        log(:info, "---", :bold, dry_run: false)
      else
        change =
          route53.change_resource_record_sets(
            hosted_zone_id: hosted_zone.id,
            change_batch: {
              changes: changes
            }
          )
        log(:info, "--> Change submitted: #{change.change_info.id}", :bold)
      end
      log(:info, "", :bold, dry_run: false)
    end

    # Slice operations to batches, per 32,000 characters in "Value" or per 1,000 operations.
    def slice_operations(ops)
      total_value_size = 0
      total_ops = 0
      ops
        .slice_before do |op|
          total_value_size += op.value_size
          total_ops += op.op_size
          if total_value_size > 32_000 || total_ops > 1000
            total_value_size = op.value_size
            total_ops = op.op_size
            true
          else
            false
          end
        end
        .to_a
    end

    def add_operation(klass, rrset)
      assert_record_name rrset
      operations << klass.new(
        hosted_zone,
        rrset,
        health_checks: health_checks,
        dry_run: dry_run,
        logger: logger
      )
      self
    end

    def assert_record_name(record)
      unless record
               .name
               .downcase
               .sub(/\.$/, "")
               .end_with?(hosted_zone.name.sub(/\.$/, ""))
        raise ArgumentError,
              "#{record.name.inspect} isn't under hosted zone name #{hosted_zone.name.inspect}"
      end
    end

    class Operation
      include Log

      # @param [Roadworker::Route53Wrapper::HostedzoneWrapper] hosted_zone
      # @param [Roadworker::DSL::ResourceRecordSet] rrset
      # @param [Roadworker::HealthCheck] health_checks
      # @param [Logger] logger
      def initialize(hosted_zone, rrset, health_checks:, dry_run:, logger:)
        @hosted_zone = hosted_zone
        @rrset = rrset
        @health_checks = health_checks
        @dry_run = dry_run
        @logger = logger
      end

      attr_reader :hosted_zone, :rrset
      attr_reader :health_checks
      attr_reader :dry_run, :logger

      def sort_key
        # See Operation#cname_first?
        cname_precedence =
          if rrset.type == "CNAME"
            cname_first? ? 0 : 2
          else
            1
          end
        # Alias target may be created in the same change batch. Let's do operations for non-alias records first.
        alias_precedence = (rrset.dns_name ? 1 : 0)
        [
          rrset.name,
          cname_precedence,
          alias_precedence,
          rrset.type,
          rrset.set_identifier
        ]
      end

      # CNAME should always be created/updated later, as CNAME doesn't permit other records
      # See also Roadworker::Batch::Delete#cname_first?
      def cname_first?
        false
      end

      # Count total length of RR "Value" included in changes
      # https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/DNSLimitations.html#limits-api-requests-changeresourcerecordsets
      #
      # See also: Batch#slice_operations
      # @return [Integer]
      def value_size
        changes
          .map do |change|
            upsert_multiplier = change[:action] == "UPSERT" ? 2 : 1
            rrset = change[:resource_record_set]
            next 0 unless rrset
            rrs = rrset[:resource_records]
            next 0 unless rrs
            (rrs.map { |_| _[:value]&.size || 0 }.sum) * upsert_multiplier
          end
          .sum || 0
      end

      # Count of operational size
      # https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/DNSLimitations.html#limits-api-requests-changeresourcerecordsets
      #
      # See also: Batch#slice_operations
      # @return [Integer]
      def op_size
        changes.map { |change| change[:action] == "UPSERT" ? 2 : 1 }.sum || 0
      end

      # @return [Array<Hash>]
      def changes
        raise NotImplementedError
      end

      # @return [Hash]
      def desired_rrset
        raise NotImplementedError
      end

      # @return [Roadworker::Route53Wrapper::ResourceRecordSetWrapper]
      def present_rrset
        hosted_zone.find_resource_record_set(
          rrset.name,
          rrset.type,
          rrset.set_identifier
        ) or raise "record not present"
      end

      def diff!(dry_run: false)
        raise NotImplementedError
      end

      def inspect
        "#<#{self.class.name} @changes=#{changes.inspect}>"
      end

      def to_s
        inspect
      end

      private

      # @param [String] dns_name
      # @param [Hash] options
      # @return [?]
      def get_alias_target(dns_name, options)
        Aws::Route53.dns_name_to_alias_target(
          dns_name,
          options,
          hosted_zone.id,
          hosted_zone.name
        )
      end

      # @param [?] health_check
      # @return [?]
      def get_health_check(check)
        check ? health_checks.find_or_create(check) : nil
      end
    end

    class Create < Operation
      # @return [Hash]
      def desired_rrset
        return @new_rrset if defined?(@new_rrset)
        @new_rrset = { name: rrset.name, type: rrset.type }

        Route53Wrapper::RRSET_ATTRS.each do |attribute|
          value = rrset.send(attribute)
          next unless value

          case attribute
          when :dns_name
            attribute = :alias_target
            dns_name, dns_name_opts = value
            value = get_alias_target(dns_name, dns_name_opts)
          when :health_check
            attribute = :health_check_id
            value = get_health_check(value)
          end

          @new_rrset[attribute] = value
        end

        @new_rrset
      end

      def changes
        [{ action: "CREATE", resource_record_set: desired_rrset.to_h }]
      end

      def diff!
        log(:info, "Create ResourceRecordSet", :cyan) do
          "#{desired_rrset[:name]} #{desired_rrset[:type]}#{desired_rrset[:set_identifier] && " (#{desired_rrset[:set_identifier]})"}"
        end
      end
    end

    class Delete < Operation
      # CNAME should always be deleted first, as CNAME doesn't permit other records
      def cname_first?
        true
      end

      def hosted_zone_soa_or_ns?
        (present_rrset.type == "SOA" || present_rrset.type == "NS") &&
          hosted_zone.name == present_rrset.name
      end

      def changes
        # Avoid deleting hosted zone SOA/NS
        return [] if hosted_zone_soa_or_ns?

        [{ action: "DELETE", resource_record_set: present_rrset.to_h }]
      end

      def diff!
        return if changes.empty?
        log(:info, "Delete ResourceRecordSet", :red) do
          "#{present_rrset.name} #{present_rrset.type}#{present_rrset.set_identifier && " (#{present_rrset.set_identifier})"}"
        end
      end
    end

    class Update < Operation
      def desired_rrset
        return @desired_rrset if defined?(@desired_rrset)
        @desired_rrset = { name: rrset[:name] }

        Route53Wrapper::RRSET_ATTRS_WITH_TYPE.each do |attribute|
          value = rrset[attribute]
          next unless value

          case attribute
          when :dns_name
            dns_name, dns_name_opts = value
            @desired_rrset[:alias_target] = get_alias_target(
              dns_name,
              dns_name_opts
            )
          when :health_check
            @desired_rrset[:health_check_id] = get_health_check(value)
          else
            @desired_rrset[attribute] = value
          end
        end

        @desired_rrset
      end

      def changes
        [
          { action: "DELETE", resource_record_set: present_rrset.to_h },
          { action: "CREATE", resource_record_set: desired_rrset.to_h }
        ]
      end

      def diff!
        log(:info, "Update ResourceRecordSet", :green) do
          "#{present_rrset.name} #{present_rrset.type}#{present_rrset.set_identifier && " (#{present_rrset.set_identifier})"}"
        end

        # Note that desired_rrset is directly for Route 53, and present_record is also from Route 53
        # Only given +rrset+ is brought from DSL, and dns_name & health_check is only valid in our DSL
        Route53Wrapper::RRSET_ATTRS_WITH_TYPE.each do |attribute|
          case attribute
          when :dns_name
            present =
              normalize_attribute_for_diff(
                attribute,
                present_rrset[:alias_target] &&
                  present_rrset[:alias_target][:dns_name]
              )
            desired =
              normalize_attribute_for_diff(
                attribute,
                desired_rrset[:alias_target] &&
                  desired_rrset[:alias_target][:dns_name]
              )
          when :health_check
            present =
              normalize_attribute_for_diff(
                attribute,
                present_rrset[:health_check_id]
              )
            desired =
              normalize_attribute_for_diff(
                attribute,
                desired_rrset[:health_check_id]
              )
          else
            present =
              normalize_attribute_for_diff(attribute, present_rrset[attribute])
            desired =
              normalize_attribute_for_diff(attribute, desired_rrset[attribute])
          end

          if desired != present
            log(
              :info,
              "  #{attribute}:\n".green +
                Roadworker::Utils.diff(
                  present,
                  desired,
                  color: @colorized,
                  indent: "    "
                ),
              false
            )
          end
        end
      end

      private

      def normalize_attribute_for_diff(attribute, value)
        if value.is_a?(Array)
          value = Aws::Route53.sort_rrset_values(attribute, value)
          value = nil if value.empty?
        end
        value
      end
    end
  end
end
