require 'aws-sdk'

module AWS
  class Route53

    class << self
      def dns_name_to_alias_target(name)
        name = name.sub(/\.\Z/, '')

        if name =~ /([^.]+)\.elb\.amazonaws.com\Z/i
          region = $1.downcase
          elb_dns_name_to_alias_target(name, region)
        else
          raise "Invalid DNS Name: #{name}"
        end
      end

      private

      def elb_dns_name_to_alias_target(name, region)
        elb = AWS::ELB.new(:region => region)

        load_balancer = elb.load_balancers.find do |lb|
          lb.dns_name == name
        end

        unless load_balancer
          raise "Cannot find ELB: #{name}"
        end

        {
          :hosted_zone_id         => load_balancer.canonical_hosted_zone_name_id,
          :dns_name               => load_balancer.dns_name,
          :evaluate_target_health => false, # XXX:
        }
      end
    end # of class method

  end # Route53
end # Roadworker
