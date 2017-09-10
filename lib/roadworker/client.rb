module Roadworker
  class Client
    include Roadworker::Log
    include Roadworker::Utils::Helper

    def initialize(options = {})
      @options = OpenStruct.new(options)
      @options.logger ||= Logger.new($stdout)
      String.colorize = @options.color
      @options.route53 = Aws::Route53::Client.new
      @health_checks = HealthCheck.health_checks(@options.route53, :extended => true)
      @options.health_checks = @health_checks
      @route53 = Route53Wrapper.new(@options)
    end

    def apply(file)
      dsl = load_file(file)
      updated = false

      if dsl.hosted_zones.empty? and not @options.force
        log(:warn, "Nothing is defined (pass `--force` if you want to remove)", :yellow)
      else
        walk_hosted_zones(dsl)
        updated = @options.updated
      end

      if updated and @options.health_check_gc
        HealthCheck.gc(@options.route53, :logger => @options.logger)
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
        open(file) do |f|
          dsl = DSL.define(f.read, file).result
        end
      else
        dsl = DSL.define(file.read, file.path).result
      end

      return dsl
    end

    def walk_hosted_zones(dsl)
      expected = collection_to_hash(dsl.hosted_zones) {|i| [normalize_name(i.name), i.vpcs.map(&:vpc_id)] }
      actual   = collection_to_hash(@route53.hosted_zones) {|i| [normalize_name(i.name), i.vpcs.map(&:vpc_id)] }

      expected.each do |keys, expected_zone|
        name = keys[0]
        next unless matched_zone?(name)
        actual_zone = actual.delete(keys)
        actual_zone ||= @route53.hosted_zones.create(name, :vpc => expected_zone.vpcs.first)

        walk_vpcs(expected_zone, actual_zone)
        walk_rrsets(expected_zone, actual_zone)
      end

      actual.each do |keys, zone|
        name = keys[0]
        next unless matched_zone?(name)
        zone.delete
      end
    end

    def walk_vpcs(expected_zone, actual_zone)
      expected_vpcs = expected_zone.vpcs || []
      actual_vpcs = actual_zone.vpcs || []

      if not expected_vpcs.empty? and actual_vpcs.empty?
        log(:warn, "Cannot associate VPC to public zone", :yellow, expected_zone.name)
      else
        (expected_vpcs - actual_vpcs).each do |vpc|
          actual_zone.associate_vpc(vpc)
        end

        unexpected_vpcs = actual_vpcs - expected_vpcs

        if unexpected_vpcs.length.nonzero? and expected_vpcs.length.zero?
          log(:warn, "Private zone requires one or more of VPCs", :yellow, expected_zone.name)
        else
          unexpected_vpcs.each do |vpc|
            actual_zone.disassociate_vpc(vpc)
          end
        end
      end
    end

    def walk_rrsets(expected_zone, actual_zone)
      expected = collection_to_hash(expected_zone.rrsets, :name, :type, :set_identifier)
      actual   = collection_to_hash(actual_zone.rrsets, :name, :type, :set_identifier)

      expected.each do |keys, expected_record|
        name = keys[0]
        type = keys[1]
        set_identifier = keys[2]

        actual_record = actual.delete(keys)

        if not actual_record and %w(A CNAME).include?(type)
          actual_type = (type == 'A' ? 'CNAME' : 'A')
          actual_record = actual.delete([name, actual_type, set_identifier])
        end

        if expected_zone.ignore_patterns.any? { |pattern| pattern === name }
          log(:warn, "Ignoring defined record in DSL, because it is ignored record", :yellow) do
            "#{name} #{type}" + (set_identifier ? " (#{set_identifier})" : '')
          end
          next
        end

        if actual_record
          unless actual_record.eql?(expected_record)
            actual_record.update(expected_record)
          end
        else
          actual_record = actual_zone.rrsets.create(name, type, expected_record)
        end
      end

      actual.each do |keys, record|
        name = keys[0]
        if expected_zone.ignore_patterns.any? { |pattern| pattern === name }
          next
        end
        
        record.delete
      end
    end

    def collection_to_hash(collection, *keys)
      hash = {}

      collection.each do |item|
        if block_given?
          key_list = yield(item)
        else
          key_list = keys.map do |k|
            value = item.send(k)
            (k == :name && value) ? normalize_name(value) : value
          end
        end

        hash[key_list] = item
      end

      return hash
    end

    def normalize_name(name)
      name.downcase.sub(/\.\z/, '')
    end

  end # Client
end # Roadworker
