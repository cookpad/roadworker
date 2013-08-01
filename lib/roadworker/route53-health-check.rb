require 'uri'
require 'uuid'

module Roadworker
  class HealthCheck

    class << self
      def health_checks(route53, options = {})
        self.new(route53).health_checks(options)
      end

      def config_to_hash(config)
        ipaddr = config[:ip_address]
        port   = config[:port]
        type   = config[:type].downcase
        path   = config[:resource_path]
        fqdn   = config[:fully_qualified_domain_name].downcase

        url = "#{type}://#{ipaddr}:#{port}"
        url << path if path && path != '/'

        {:url => url, :host_name => fqdn}
      end

      def parse_url(url)
        url = URI.parse(url)
        path = url.path

        if path.nil? or path.empty? or path == '/'
          path = nil
        end

        config = {}

        {
          :ip_address    => url.host,
          :port          => url.port,
          :type          => url.scheme.upcase,
          :resource_path => path,
        }.each {|key, value|
          config[key] = value if value
        }

        return config
      end
    end # of class method

    def initialize(route53)
      @route53 = route53
    end

    def health_checks(options = {})
      check_list = {}

      is_truncated = true
      next_marker = nil

      while is_truncated
        opts = next_marker ? {:marker => next_marker} : {}
        response = @route53.client.list_health_checks(opts)

        response[:health_checks].each do |check|
          check_list[check[:id]] = check[:health_check_config]
        end

        is_truncated = response[:is_truncated]
        next_marker = response[:next_marker]
      end

      if options[:extended]
        check_list.instance_variable_set(:@route53, @route53)

        def check_list.find_or_create(attrs)
          health_check_id, config = self.find {|hcid, elems| elems == attrs }

          unless health_check_id
            response = @route53.client.create_health_check({
              :caller_reference    => UUID.new.generate,
              :health_check_config => attrs,
            })

            health_check_id = response[:health_check][:id]
          end

          return health_check_id
        end
      end

      return check_list
    end

  end # HealthCheck
end # Roadworker