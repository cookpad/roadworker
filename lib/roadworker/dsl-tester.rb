require 'roadworker/log'

require 'tempfile'
require 'socket'

# XXX:
unless Socket.const_defined?(:AF_INET6)
  Socket::AF_INET6 = Socket::AF_INET
end

# XXX:
proc {
  begin
    socket6 = UDPSocket.new(Socket::AF_INET6)
    socket6.close
  rescue Errno::EAFNOSUPPORT
    verbose = $VERBOSE
    $VERBOSE = nil
    Socket::AF_INET6 = Socket::AF_INET
    $VERBOSE = verbose
  end
}.call

require 'net/dns'

module Roadworker
  class DSL
    class Tester
      include Roadworker::Log

      DEFAULT_NAMESERVERS = ['8.8.8.8', '8.8.4.4']
      ASTERISK_PREFIX = 'asterisk-of-wildcard'
      RETRY = 3
      RETRY_WAIT = 1

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
        records_length = records.length
        failures = 0
        error_messages = []
        warning_messages = []
        a_records = {}

        records.each do |key, rrs|
          name, type = key
          next unless type == "A"

          a_records[name] = rrs.map do |record|
            [(record.resource_records || []).map {|i| i[:value].strip }.sort, record.ttl]
          end
        end

        validate_record = lambda do |key, rrs, asterisk_answers|
          errors = []

          original_name = key[0]
          name = asterisk_to_anyname(original_name)
          type = key[1]

          log(:debug, 'Check DNS', :white, "#{name} #{type}")

          response = query(name, type, error_messages)

          unless response
            failures += 1
            print_failure
            next
          end

          is_valid = rrs.any? {|record|
            expected_value = (record.resource_records || []).map {|i| i[:value].strip }.sort
            expected_ttl = fetch_dns_name(record.dns_name) ? 60 : record.ttl

            actual_value = response.answer.map {|i|
              case type
              when 'TXT', 'SPF'
                i.txt
              when 'SRV'
                [i.priority, i.weight, i.port, i.host].join(' ')
              else
                i.value
              end
            }.map {|i| i.strip }.sort
            actual_ttls = response.answer.map {|i| i.ttl }

            case type
            when 'NS', 'PTR', 'MX', 'CNAME', 'SRV'
              expected_value = expected_value.map {|i| i.downcase.sub(/\.\Z/, '') }
              actual_value = actual_value.map {|i| i.downcase.sub(/\.\Z/, '') }
            when 'TXT', 'SPF'
              # see https://github.com/bluemonk/net-dns/blob/651dc1006d9ee0c167fa515e4b9d2494af415ae9/lib/net/dns/rr/txt.rb#L46
              expected_value = expected_value.map {|i| i.scan(/(?:\\\\|(?:\\"|(?:[^\\"]|[^"])))*"((?:\\\\|(?:\\"|(?:\\"|(?:[^\\"]|[^"]))))*)"/).join(' ').gsub(/\\(.)/) { $1 }.strip }
              actual_value = actual_value.map {|i| i.strip }
            end

            expected_message = record.resource_records ? expected_value.map {|i| "#{i}(#{expected_ttl})" }.join(',') : "#{fetch_dns_name(record.dns_name)}(#{expected_ttl})"
            actual_message = actual_value.zip(actual_ttls).map {|v, t| "#{v}(#{t})" }.join(',')
            logmsg_expected = "expected=#{expected_message}"
            logmsg_actual = "actual=#{actual_message}"
            log(:debug, "  #{logmsg_expected}\n  #{logmsg_actual}", :white)

            is_same = false

            if fetch_dns_name(record.dns_name)
              # A(Alias)
              case fetch_dns_name(record.dns_name).sub(/\.\Z/, '')
              when /\.elb\.amazonaws\.com/i
                is_same = response.answer.all? {|a|
                  response_query_ptr = query(a.value, 'PTR', error_messages)

                  if response_query_ptr
                    response_query_ptr.answer.all? do |ptr|
                      ptr.value =~ /\.compute\.amazonaws\.com\.\Z/
                    end
                  else
                    false
                  end
                }
              when /\As3-website-(?:[^.]+)\.amazonaws\.com\Z/
                response_answer_ip_1_2 = response.answer.map {|a| a.value.split('.').slice(0, 2) }.uniq

                # try 3 times
                is_same = (0...3).any? do |n|
                  unless n.zero?
                    sleep 3
                    log(:debug, 'Retry Check', :white, "#{name} #{type}")
                  end

                  dns_name_a = query(fetch_dns_name(record.dns_name), 'A', error_messages)
                  s3_website_endpoint_ips = dns_name_a.answer.map {|i| i.value }

                  !s3_website_endpoint_ips.empty? && s3_website_endpoint_ips.any? {|ip|
                    response_answer_ip_1_2.include?(ip.split('.').slice(0, 2))
                  }
                end
              when /\.cloudfront\.net\Z/
                is_same = response.answer.all? {|a|
                  response_query_ptr = query(a.value, 'PTR', error_messages)

                  if response_query_ptr
                    response_query_ptr.answer.all? do |ptr|
                      ptr.value =~ /\.cloudfront\.net\.\Z/
                    end
                  end
                }
              else
                if (alias_target_a_record = a_records[fetch_dns_name(record.dns_name)])
                  expected_message = alias_target_a_record.map {|values, ttl| values.map {|i| "#{i}(#{ttl})" }.join(',') }.uniq.join (' or ')
                  logmsg_expected = "expected=#{expected_message}"
                  expected_ttl = alias_target_a_record.map {|values, ttl| ttl }.max
                  is_same = alias_target_a_record.any? {|values, ttl| values == actual_value }
                else
                  warning_messages << "#{name} #{type}: Cannot check `#{fetch_dns_name(record.dns_name)}`"
                  is_same = true
                end
              end
            else
              is_same = (expected_value == actual_value)
            end

            if is_same
              unless actual_ttls.all? {|i| i <= expected_ttl }
                is_same = false
              end
            end

            errors << [logmsg_expected, logmsg_actual] unless is_same

            if asterisk_answers
              asterisk_answers.each do |ast_key, answers|
                ast_name = ast_key[0]
                ast_regex = Regexp.new('\A' + ast_name.sub(/\.\Z/, '').gsub('.', '\.').gsub('*', '.+') + '\Z')

                if ast_regex =~ name.sub(/\.\Z/, '') and actual_value.any? {|i| answers.include?(i) }
                  warning_messages << "#{name} #{type}: same as `#{ast_name}`"
                end
              end
            end

            is_same
          }

          if is_valid
            print_success
          else
            failures += 1
            print_failure

            errors.each do |logmsg_expected, logmsg_actual|
              error_messages << "#{name} #{type}:\n  #{logmsg_expected}\n  #{logmsg_actual}"
            end
          end
        end

        asterisk_records = {}
        asterisk_answers = {}

        records.keys.each do |key|
          asterisk_records[key] = records.delete(key) if key[0]['*']
        end

        asterisk_records.map do |key, rrs|
          original_name = key[0]
          name = asterisk_to_anyname(original_name)
          type = key[1]

          response = query(name, type)

          if response
            asterisk_answers[key] = response.answer.map {|i| (%w(TXT SPF).include?(type) ? i.txt : i.value).strip }
          end
        end

        asterisk_records.each do |key, rrs|
          validate_record.call(key, rrs, nil)
        end

        records.each do |key, rrs|
          validate_record.call(key, rrs, asterisk_answers)
        end

        puts unless @options.debug

        error_messages.each do |msg|
          log(:error, msg, :intense_red)
        end

        warning_messages.each do |msg|
          log(:warn, "WARNING #{msg}", :intense_yellow)
        end

        [records_length, failures]
      end

      private

      def create_resolver
        log_file = @options.debug ? Net::DNS::Resolver::Defaults[:log_file] : '/dev/null'
        resolver_opts = {:log_file => log_file}

        if File.exist?(Net::DNS::Resolver::Defaults[:config_file])
          resolver_opts[:nameservers] = @options.nameservers if @options.nameservers
          Net::DNS::Resolver.new(resolver_opts)
        else
          Tempfile.open(File.basename(__FILE__)) do |f|
            resolver_opts.updated(:config_file => f.path, :nameservers => DEFAULT_NAMESERVERS)
            resolver_opts[:nameservers] = @options.nameservers if @options.nameservers
            Net::DNS::Resolver.new(resolver_opts)
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

      def query(name, type, error_messages = nil)
        ctype = Net::DNS.const_get(type)
        response = nil

        RETRY.times do |i|
          begin
            response = @resolver.query(name, ctype)
            break
          rescue => e
            if (i + 1) < RETRY
              sleep RETRY_WAIT
            else
              error_messages << "#{name} #{type}: #{e.message}" if error_messages
            end
          end
        end

        return response
      end

      def print_success
        print '.'.intense_green unless @options.debug
      end

      def print_failure
        print 'F'.intense_red unless @options.debug
      end

      def fetch_dns_name(dns_name)
        if dns_name
          dns_name.first
        else
          nil
        end
      end
    end # Tester
  end # DSL
end # Roadworker
