module Roadworker
  class DSL
    include Roadworker::TemplateHelper

    class << self
      def define(source, path, lineno = 1)
        self.new(path) do
          eval(source, binding, path, lineno)
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

      @context = Hashie::Mash.new(
        :path => path,
        :templates => {}
      )

      instance_eval(&block)
    end

    def template(name, &block)
      @context.templates[name.to_s] = block
    end

    private

    def require(file)
      routefile = (file =~ %r|\A/|) ? file : File.expand_path(File.join(File.dirname(@path), file))

      if File.exist?(routefile)
        instance_eval(File.read(routefile), routefile)
      elsif File.exist?(routefile + '.rb')
        instance_eval(File.read(routefile + '.rb'), routefile + '.rb')
      else
        Kernel.require(file)
      end
    end

    def hosted_zone(name, id = nil, &block)
      @result.hosted_zones << Hostedzone.new(@context, name, id, [], &block).result
    end

    class Hostedzone
      include Roadworker::TemplateHelper

      attr_reader :result

      def initialize(context, name, id, rrsets = [], &block)
        @name = name
        @context = context.merge(:hosted_zone_name => name)

        @result = OpenStruct.new({
          :id => id,
          :name => name,
          :vpcs => [],
          :resource_record_sets => rrsets,
          :rrsets => rrsets,
          :ignore_patterns => [],
        })

        instance_eval(&block)
      end

      private

      def vpc(vpc_region, vpc_id)
        unless vpc_region
          raise "Invalid VPC Region: #{vpc_region.inspect}"
        end

        unless vpc_id
          raise "Invalid VPC ID: #{vpc_id}"
        end

        vpc_h = Aws::Route53::Types::VPC.new(:vpc_region => vpc_region.to_s, :vpc_id => vpc_id.to_s)

        if @result.vpcs.include?(vpc_h)
          raise "VPC is already defined: #{vpc_h.inspect}"
        end

        @result.vpcs << vpc_h
      end

      def ignore(rrset_name)
        @result.ignore_patterns << case rrset_name
        when Regexp
          rrset_name
        else 
          rrset_name.to_s.sub(/\.\z/, '')
        end
      end

      def ignore_under(rrset_name)
        ignore /(\A|\.)#{Regexp.escape(rrset_name.to_s.sub(/\.\z/, ''))}\z/
      end

      def resource_record_set(rrset_name, type, &block)
        if rrset_name.sub(/\.\z/, '') !~ /#{Regexp.escape(@name.sub(/\.\Z/, ''))}\Z/i
          raise "Invalid ResourceRecordSet Name: #{rrset_name}"
        end

        @result.resource_record_sets << ResourceRecordSet.new(@context, rrset_name, type, &block).result
      end
      alias rrset resource_record_set

      class ResourceRecordSet
        include Roadworker::TemplateHelper

        attr_reader :result

        def initialize(context, name, type, &block)
          @context = context.merge(
            :rrset_name => name,
            :rrset_type => type
          )

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

        def dns_name(value, options = {})
          options = Aws::Route53.normalize_dns_name_options(options)
          @result.dns_name = [value, options]
        end

        def geo_location(value)
          @result.geo_location = value
        end

        def failover(value)
          @result.failover = value
        end

        def health_check(url, options = {})
          unless options.kind_of?(Hash)
            raise TypeError, "wrong argument type #{options.inspect} (expected Hash)"
          end

          if url.kind_of?(Hash)
            if url.include?(:calculated)
              config = Aws::Route53::Types::HealthCheckConfig.new
              config[:type] = 'CALCULATED'
              config[:child_health_checks] = url.delete(:calculated)
              options = url
            elsif url.include?(:cloudwatch_metric)
              config = Aws::Route53::Types::HealthCheckConfig.new
              config[:type] = 'CLOUDWATCH_METRIC'
              config[:alarm_identifier] = url.delete(:cloudwatch_metric)
              config[:child_health_checks] = [] 
              options = url
            else
              raise ArgumentError, "wrong arguments: #{url.inspect}"
            end
          else
            config = HealthCheck.parse_url(url)
            config[:child_health_checks] = []
          end

          {
            :host              => :fully_qualified_domain_name,
            :search_string     => :search_string,
            :request_interval  => :request_interval,
            :health_threshold  => :health_threshold,
            :failure_threshold => :failure_threshold,
            :measure_latency   => :measure_latency,
            :inverted          => :inverted,
            :enable_sni        => :enable_sni,
            :regions           => :regions,
            :insufficient_data_health_status => :insufficient_data_health_status,
          }.each do |option_key, config_key|
            config[config_key] = options[option_key] unless options[option_key].nil?
          end

          config[:regions] ||= []

          if config.search_string
            config.type += '_STR_MATCH'
          end

          case config[:type]
          when 'CALCULATED'
            # nothing to do
          when 'CLOUDWATCH_METRIC'
            config[:inverted] ||= false
            config[:insufficient_data_health_status] ||= 'LastKnownStatus'
          else
            config[:request_interval]  ||= 30
            config[:failure_threshold] ||= 3
            config[:measure_latency]   ||= false
            config[:inverted]          ||= false
            config[:enable_sni]        ||= false
          end

          @result.health_check = config
        end

        def resource_records(*values)
          if values.uniq.length != values.length
            raise "Duplicate ResourceRecords: #{values.join(', ')}"
          end

          @result.resource_records = [values].flatten.map {|i| Aws::Route53::Types::ResourceRecord.new(:value => i) }
        end

      end # ResourceRecordSet

    end # Hostedzone

  end # DSL
end # RoadWorker
