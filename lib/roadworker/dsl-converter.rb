module Roadworker
  class DSL
    class Converter
      class << self
        def convert(exported)
          self.new(exported).convert
        end
      end # of class method

      def initialize(exported)
        @health_checks = exported[:health_checks]
        @hosted_zones = exported[:hosted_zones]
      end

      def convert
        @hosted_zones.map {|i| output_zone(i) }.join("\n")
      end

      private

        def output_rrset(recrod)
          name = recrod.delete(:name).inspect
          type = recrod.delete(:type).inspect

          attrs = recrod.map {|key, value|
            case key
            when :resource_records
              if value.empty?
                nil
              else
                value = value.map {|i| i.inspect }.join(",\n      ")
                "#{key}(\n      #{value}\n    )"
              end
            when :health_check_id
              config = HealthCheck.config_to_hash(@health_checks[value])

              if config[:calculated]
                hc_args = ":calculated => #{config[:calculated].inspect}"
              else
                hc_args = config[:url].sub(/\A(https?)_str_match:/) { $1 + ':' }.inspect
              end

              [
                :host,
                :search_string,
                :request_interval,
                :health_threshold,
                :failure_threshold,
                :measure_latency,
                :inverted,
              ].each do |key|
                unless config[key].nil?
                  hc_args << ", :#{key} => #{config[key].inspect}"
                end
              end

              "health_check #{hc_args}"
            when :dns_name
              if value.kind_of?(Array) and value.length > 1
                dns_name_opts = value.pop
                value = value.inspect.sub(/\A\[/, '').sub(/\]\Z/, '')
                dns_name_opts = dns_name_opts.inspect.sub(/\A\{/, '').sub(/\}\Z/, '')
                "#{key} #{value}, #{dns_name_opts}"
              else
                value = [value].flatten.inspect.sub(/\A\[/, '').sub(/\]\Z/, '')
                "#{key} #{value}"
              end
            else
              inspected_value = value.inspect
              inspected_value.sub!(/\A{/, '').sub!(/}\z/, '') if value.kind_of?(Hash)
              "#{key} #{inspected_value}"
            end
          }.select {|i| i }.join("\n    ")

          return(<<-EOS)
  rrset #{name}, #{type} do
    #{attrs}
  end
          EOS
        end

        def output_zone(zone)
          name = zone[:name].inspect
          rrsets = zone[:rrsets]
          vpcs = output_vpcs(zone[:vpcs])
          vpcs = "  #{vpcs}\n\n" if vpcs

          return(<<-EOS)
hosted_zone #{name} do
#{vpcs
}#{rrsets.map {|i| output_rrset(i) }.join("\n").chomp}
end
          EOS
        end

        def output_vpcs(vpcs)
          return nil if (vpcs || []).empty?

          vpcs.map {|vpc|
            region = vpc[:vpc_region]
            vpc_id = vpc[:vpc_id]
            "vpc #{region.inspect}, #{vpc_id.inspect}"
          }.join("\n  ")
        end

    end # Converter
  end # DSL
end # Roadworker
