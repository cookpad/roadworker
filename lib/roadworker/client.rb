module Roadworker
  class Client
    include Roadworker::Log
    include Roadworker::Utils::Helper

    def initialize(options = {})
      @options = OpenStruct.new(options)
      @options.logger ||= Logger.new($stdout)
      @options.route53 = Aws::Route53::Client.new
      @health_checks =
        HealthCheck.health_checks(@options.route53, extended: true)
      @options.health_checks = @health_checks
      @route53 = Route53Wrapper.new(@options)
    end

    def apply(file)
      dsl = load_file(file)
      updated = false

      if dsl.hosted_zones.empty? and not @options.force
        log(
          :warn,
          "Nothing is defined (pass `--force` if you want to remove)",
          :yellow
        )
      else
        updated = walk_hosted_zones(dsl)
      end

      if updated and @options.health_check_gc
        HealthCheck.gc(@options.route53, logger: @options.logger)
      end

      return updated
    end

    def export
      exported = @route53.export

      if block_given?
        yield(exported, DSL.method(:convert))
      else
        DSL.convert(exported)
      end
    end

    def test(file)
      dsl = load_file(file)
      DSL.test(dsl, @options)
    end

    private

    def load_file(file)
      dsl = nil

      if file.kind_of?(String)
        open(file) { |f| dsl = DSL.define(f.read, file).result }
      else
        dsl = DSL.define(file.read, file.path).result
      end

      return dsl
    end

    def walk_hosted_zones(dsl)
      updated = false

      expected =
        collection_to_hash(dsl.hosted_zones) do |i|
          [i.name, i.vpcs.empty?, normalize_id(i.id)]
        end
      actual =
        collection_to_hash(@route53.hosted_zones) do |i|
          [i.name, i.vpcs.empty?, normalize_id(i.id)]
        end

      expected.each do |keys, expected_zone|
        name, private_zone, id = keys
        next unless matched_zone?(name)
        if id
          actual_zone = actual.delete(keys)
          unless actual_zone
            log(:warn, "Hosted zone not found", :yellow, "#{name} (#{id})")
            next
          end
        else
          actual_keys, actual_zone =
            actual.find { |(n, p, _), _| n == name && p == private_zone }
          actual.delete(actual_keys) if actual_keys
        end

        unless actual_zone
          updated = true
          actual_zone =
            @route53.hosted_zones.create(name, vpc: expected_zone.vpcs.first)
        end

        updated = true if walk_vpcs(expected_zone, actual_zone)
        updated = true if walk_rrsets(expected_zone, actual_zone)
      end

      actual.each do |keys, zone|
        name = keys[0]
        next unless matched_zone?(name)
        zone.delete
        updated = true
      end

      updated
    end

    def walk_vpcs(expected_zone, actual_zone)
      updated = false

      expected_vpcs = expected_zone.vpcs || []
      actual_vpcs = actual_zone.vpcs || []

      if not expected_vpcs.empty? and actual_vpcs.empty?
        log(
          :warn,
          "Cannot associate VPC to public zone",
          :yellow,
          expected_zone.name
        )
      else
        (expected_vpcs - actual_vpcs).each do |vpc|
          actual_zone.associate_vpc(vpc)
          updated = true
        end

        unexpected_vpcs = actual_vpcs - expected_vpcs

        if unexpected_vpcs.length.nonzero? and expected_vpcs.length.zero?
          log(
            :warn,
            "Private zone requires one or more of VPCs",
            :yellow,
            expected_zone.name
          )
        else
          unexpected_vpcs.each do |vpc|
            actual_zone.disassociate_vpc(vpc)
            updated = true
          end
        end
      end

      updated
    end

    # @param [OpenStruct] expected_zone Roadworker::DSL::Hostedzone#result
    # @param [Roadworker::Route53Wrapper::HostedzoneWrapper] actual_zone
    def walk_rrsets(expected_zone, actual_zone)
      change_batch =
        Batch.new(
          actual_zone,
          health_checks: @options.health_checks,
          logger: @options.logger,
          dry_run: @options.dry_run,
          colorized: @options.color
        )

      expected =
        collection_to_hash(expected_zone.rrsets, :name, :type, :set_identifier)
      actual = actual_zone.rrsets.to_h.dup

      expected.each do |keys, expected_record|
        name, type, set_identifier = keys
        actual_record = actual.delete(keys)

        # XXX: normalization should be happen on DSL as much as possible, but ignore_patterns expect no trailing dot
        # and to keep backward compatibility, removing then dot when checking ignored_patterns.
        name_for_ignore_patterns = name.sub(/\.\z/, "")
        if expected_zone.ignore_patterns.any? { |pattern|
             pattern === name_for_ignore_patterns
           }
          log(
            :warn,
            "Ignoring defined record in DSL, because it is ignored record",
            :yellow
          ) do
            "#{name} #{type}" + (set_identifier ? " (#{set_identifier})" : "")
          end
          next
        end

        if actual_record
          unless actual_record.eql?(expected_record)
            change_batch.update(expected_record)
          end
        else
          change_batch.create(expected_record)
        end
      end

      actual.each do |(name, _type, _set_identifier), record|
        # XXX: normalization should be happen on DSL as much as possible, but ignore_patterns expect no trailing dot
        # and to keep backward compatibility, removing then dot when checking ignored_patterns.
        name = name.sub(/\.\z/, "")
        if expected_zone.ignore_patterns.any? { |pattern| pattern === name }
          next
        end

        change_batch.delete(record)
      end

      change_batch.request!(@options.route53)
    end

    def collection_to_hash(collection, *keys)
      hash = {}

      collection.each do |item|
        if block_given?
          key_list = yield(item)
        else
          key_list = keys.map { |k| item.send(k) }
        end

        hash[key_list] = item
      end

      return hash
    end

    def normalize_id(id)
      id.sub(%r{^/hostedzone/}, "") if id
    end
  end # Client
end # Roadworker
