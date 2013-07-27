module Roadworker
  class DSL
    attr_reader :hosted_zones

    def initialize(&block)
      @hosted_zones = []
      instance_eval(&block)
    end

    private

    def hosted_zone(name, &block)
      @hosted_zones << HostedZone.new(name, &block)
    end

    class HostedZone
      attr_reader :name
      attr_reader :comment
      attr_reader :caller_reference
      attr_reader :resource_record_sets

      def initialize(name, &block)
        @name = name
        @resource_record_sets = []
        instance_eval(&block)
      end

      private

      def comment(value)
        @comment = value
      end

      def caller_reference(value)
        @caller_reference = value
      end

      def resource_record_set(name, type, &block)
        @resource_record_sets << ResourceRecordSet.new(name, type, &block)
      end
      alias rrset resource_record_set

      class ResourceRecordSet
        attr_reader :set_identifier
        attr_reader :weight
        attr_reader :ttl
        attr_reader :region
        attr_reader :alias
        attr_reader :resource_records

        def initialize(name, type, &block)
          @name = name
          @type = type
          instance_eval(&block)
        end

        private

        def set_identifier(value)
          @set_identifier = value
        end
        alias identifier set_identifier

        def weight(value)
          @weight = value
        end

        def ttl(value)
          @ttl = ttl
        end

        def region(value)
          @region = value
        end

        def alias(dns_name)
          @alias = dns_name
        end

        def resource_records(*values)
          @resource_records = [values].flatten
        end
      end # ResourceRecordSet
    end # HostedZone
  end # DSL
end # RoadWorker
