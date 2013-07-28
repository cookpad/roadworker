require 'roadworker/dsl-converter'
require 'ostruct'

module Roadworker
  class DSL

    class << self
      def define(source)
        self.new do
          eval(source, binding)
        end
      end

      def convert(hosted_zones)
        Converter.convert(hosted_zones)
      end
    end # of class method

    attr_reader :result

    def initialize(&block)
      @result = OpenStruct.new({:hosted_zones => []})
      instance_eval(&block)
    end

    private

    def hosted_zone(name, &block)
      @result.hosted_zones << HostedZone.new(name, &block).result
    end

    class HostedZone
      attr_reader :result

      def initialize(name, &block)
        @result = OpenStruct.new({
          :name => name,
          :resource_record_sets => [],
        })

        instance_eval(&block)
      end

      private

      def resource_record_set(name, type, &block)
        @result.resource_record_sets << ResourceRecordSet.new(name, type, &block).result
      end
      alias rrset resource_record_set

      class ResourceRecordSet
        attr_reader :result

        def initialize(name, type, &block)
          @result = OpenStruct.new({
            :name => name,
            :type => type,
          })

          instance_eval(&block)
        end

        private

        def set_identifier(value = nil)
          @result.set_identifier = value
        end
        alias identifier set_identifier

        def weight(value)
          @result.weight = value
        end

        def ttl(value)
          @result.ttl = value
        end

        def region(value)
          @result.region = value
        end

        def dns_name(value)
          @result.dns_name = value
        end

        def resource_records(*values)
          @result.resource_records = [values].flatten
        end

      end # ResourceRecordSet

    end # HostedZone

  end # DSL
end # RoadWorker
