require 'roadworker/dsl-converter'
require 'roadworker/dsl-tester'

require 'ostruct'

module Roadworker
  class DSL

    class << self
      def define(source, path)
        self.new(path) do
          eval(source, binding)
        end
      end

      def convert(hosted_zones)
        Converter.convert(hosted_zones)
      end


      def test(dsl, options)
        Tester.test(dsl, options)
      end
    end # of class method

    attr_reader :result

    def initialize(path, &block)
      @path = path
      @result = OpenStruct.new({:hosted_zones => []})
      instance_eval(&block)
    end

    private

    def require(file)
      routefile = File.expand_path(File.join(File.dirname(@path), file))

      if File.exist?(routefile)
        instance_eval(File.read(routefile))
      elsif File.exist?(routefile + '.rb')
        instance_eval(File.read(routefile + '.rb'))
      else
        Kernel.require(file)
      end
    end

    def hosted_zone(name, &block)
      @result.hosted_zones << HostedZone.new(name, &block).result
    end

    class HostedZone
      attr_reader :result

      def initialize(name, &block)
        @name = name
        rrsets = []

        @result = OpenStruct.new({
          :name => name,
          :resource_record_sets => rrsets,
          :rrsets => rrsets,
        })

        instance_eval(&block)
      end

      private

      def resource_record_set(rrset_name, type, &block)
        if rrset_name.sub(/\.\Z/, '') !~ /#{Regexp.escape(@name.sub(/\.\Z/, ''))}\Z/i
          raise "Invalid ResourceRecordSet Name: #{rrset_name}"
        end

        @result.resource_record_sets << ResourceRecordSet.new(rrset_name, type, &block).result
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
          if values.uniq.length != values.length
            raise "Duplicate ResourceRecords: #{values.join(', ')}"
          end

          @result.resource_records = [values].flatten.map {|i| {:value => i} }
        end

      end # ResourceRecordSet

    end # HostedZone

  end # DSL
end # RoadWorker
