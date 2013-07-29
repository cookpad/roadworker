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
      DEFAULT_NAMESERVERS = '8.8.8.8'

      class << self
        def test(dsl)
          resolver = nil

          if File.exist?(Net::DNS::Resolver::Defaults[:config_file])
            resolver = Net::DNS::Resolver.new
          else
            Tempfile.open(File.basename(__FILE__)) do |f|
              resolver = Net::DNS::Resolver.new(:config_file => f.path, :nameservers => DEFAULT_NAMESERVERS)
            end
          end

          record_list = {}

          dsl.hosted_zones.each do |zone|
            zone.rrsets.each do |record|
              key = [record.name, record.type]
              record_list[key] ||= []
              record_list[key] << record
            end
          end

          record_list.each do |key, rrs|
            puts "check #{key.inspect}"
            name, type = key
            type = Net::DNS.const_get(type)
            response = resolver.query(name, type)
            p response

            p rrs.any? do |record|
              expected = record.resource_records.map {|i| i[:value] }.sort
              expected_ttl = record.dns_name ? 60 : record.ttl
              actual = answer.map {|i| i.value }.sort
              actual_ttls = answer.map {|i| i.ttl }

              case type
              when 'SOA', 'NS'
                expected = 1
                actual = 1
              when 'PTR', 'MX', 'CNAME'
                expected = expected.map {|i| i.downcase.sub(/\.\Z/, '') }
                actual = actual.map {|i| i.downcase.sub(/\.\Z/, '') }
              end

              p actual_ttls.all? {|i| i <= expected_ttl }

              if record.dns_name
              else
                p expected == actual
                p expected
                p actual
                expected == actual
              end
            end
          end

          true
        end
      end # of class method

    end # Tester
  end # DSL
end # Roadworker
