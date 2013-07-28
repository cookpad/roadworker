require 'logger'
require 'ostruct'
require 'roadworker/string-ext'
require 'roadworker/dsl'
require 'roadworker/route53-wrapper'

module Roadworker
  class Client

    def initialize(options)
      @options = OpenStruct.new(options)
      @options.logger ||= Logger.new($stderr)
      #String.colorize = @options.colorize
      String.colorize = true

      @options.route53 = AWS::Route53.new({
        :access_key_id     => @options.access_key_id,
        :secret_access_key => @options.secret_access_key,
      })

      @route53 = Route53Wrapper.new(@options)
    end

    def apply(source)
      source = source.read if source.kind_of?(IO)
      dsl = DSL.define(source).result
      walk_hosted_zones(dsl)
    end

    def export
      DSL.convert(@route53.export)
    end

    private

    def walk_hosted_zones(dsl)
      expected = collection_to_hash(dsl.hosted_zones, :name)
      actual   = collection_to_hash(@route53.hosted_zones, :name)

      expected.each do |keys, expected_zone|
        name = keys[0]
        actual_zone = actual.delete(keys) || @route53.hosted_zones.create(name)
        walk_rrsets(expected_zone, actual_zone)
      end

      actual.each do |keys, zone|
        zone.rrsets.each do |record|
          record.delete
        end

        zone.delete
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

        if actual_record
          unless actual_record.eql?(expected_record)
            actual_record.update(expected_record)
          end
        else
          actual_record = actual_zone.rrsets.create(name, type, expected_record)
        end
      end

      actual.each do |keys, record|
        record.delete
      end
    end

    def collection_to_hash(collection, *keys)
      hash = {}

      collection.each do |item|
        key_list = keys.map {|k| item.send(k) }
        hash[key_list] = item
      end

      return hash
    end

  end # Client
end # Roadworker
