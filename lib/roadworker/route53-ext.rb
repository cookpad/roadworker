require 'aws-sdk'

module AWS
  class Route53

    def dns_name_to_alias_target(name)
      name = name.gsub(/\.\Z/, '')

      unless name =~ /([^.]+)\.elb\.amazonaws.com\Z/i
        raise "Invalid DNS Name: #{name}"
      end

      region = $1.downcase
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

  end # Route53
end # Roadworker
