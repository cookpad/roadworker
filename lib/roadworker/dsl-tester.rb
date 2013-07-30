require 'roadworker/log'

require 'tempfile'
require 'socket'

# XXX:
unless Socket.const_defined?(:AF_INET6)
  Socket::AF_INET6 = Socket::AF_INET
end

require 'net/dns'

module Roadworker
  class DSL
    class Tester
      include Roadworker::Log

      DEFAULT_NAMESERVERS = '8.8.8.8'
      ASTERISK_PREFIX = 'asterisk-of-wildcard'

      class << self
        def test(dsl, options)
          self.new(options).test(dsl)
        end
      end # of class method

      def initialize(options)
        @options = options
        @resolver = create_resolver
      end

      def test(dsl)
        records = fetch_records(dsl)
        result = true
        no_response = false

        records.each do |key, rrs|
          errors = []

          name = asterisk_to_anyname(key[0])
          type = key[1]

          log(:debug, 'Check DNS', :white, "#{name} #{type}")

          response = query(name, type)

          unless response
            no_response = true
            next
          end

          is_valid = rrs.any? {|record|
            expected_value = (record.resource_records || []).map {|i| i[:value].strip }.sort
            expected_ttl = record.dns_name ? 60 : record.ttl

            actual_value = response.answer.map {|i| (type == 'TXT' ? i.txt : i.value).strip }.sort
            actual_ttls = response.answer.map {|i| i.ttl }

            case type
            when 'NS', 'PTR', 'MX', 'CNAME'
              expected_value = expected_value.map {|i| i.downcase.sub(/\.\Z/, '') }
              actual_value = actual_value.map {|i| i.downcase.sub(/\.\Z/, '') }
            when 'TXT'
              expected_value = expected_value.map {|i| i.scan(/"([^"]+)"/).join.strip.gsub(/\s+/, ' ') }
              actual_value = actual_value.map {|i| i.strip.gsub(/\s+/, ' ') }
            end

            expected_message = record.resource_records ? expected_value.join(',') : record.dns_name
            actual_message = actual_value.zip(actual_ttls).map {|v, t| "#{v}(#{t})" }.join(',')
            logmsg = "expected=#{expected_message}(#{expected_ttl}) actual=#{actual_message}"
            log(:debug, "  #{logmsg}", :white, "#{name} #{type}")

            is_same = false

            if record.dns_name
              # A(Alias)
              is_same = response.answer.all? {|a|
                query(a.value, 'PTR').answer.all? do |ptr|
                  ptr.value =~ /\.compute\.amazonaws\.com\.\Z/
                end
              }
            else
              is_same = (expected_value == actual_value)
            end

            if is_same
              unless actual_ttls.all? {|i| i <= expected_ttl }
                is_same = false
                errors << logmsg
              end
            else
              errors << logmsg
            end

            is_same
          }

          unless is_valid
            errors.each do |logmsg|
              log(:warn, "FAILED #{logmsg}", :intense_red, "#{name} #{type}")
            end
          end

          result &&= is_valid
        end

        return (not no_response and result)
      end

      private

      def create_resolver
        log_file = @options.debug ? Net::DNS::Resolver::Defaults[:log_file] : '/dev/null'

        if File.exist?(Net::DNS::Resolver::Defaults[:config_file])
          Net::DNS::Resolver.new(:log_file => log_file)
        else
          Tempfile.open(File.basename(__FILE__)) do |f|
            Net::DNS::Resolver.new(:config_file => f.path, :nameservers => DEFAULT_NAMESERVERS, :log_file => log_file)
          end
        end
      end

      def fetch_records(dsl)
        record_list = {}

        dsl.hosted_zones.each do |zone|
          zone.rrsets.each do |record|
            key = [record.name, record.type]
            record_list[key] ||= []
            record_list[key] << record
          end
        end

        return record_list
      end

      def asterisk_to_anyname(name)
        rand_str = (("a".."z").to_a + ("A".."Z").to_a + (0..9).to_a).shuffle[0..7].join
        name.gsub('*', "#{ASTERISK_PREFIX}-#{rand_str}")
      end

      def query(name, type)
        ctype = Net::DNS.const_get(type)
        response = nil

        begin
          response = @resolver.query(name, ctype)
        rescue => e
          log(:warn, "WARNING #{e.message}", :yellow, "#{name} #{type}")
        end

        return response
      end

    end # Tester
  end # DSL
end # Roadworker
