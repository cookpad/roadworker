require 'aws-sdk-route53'

module Aws
  module Route53

    # http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region
    S3_WEBSITE_ENDPOINTS = {
      's3-website-ap-northeast-1.amazonaws.com' => 'Z2M4EHUR26P7ZW',
      's3-website.ap-northeast-2.amazonaws.com' => 'Z3W03O7B5YMIYP',
      's3-website.ap-south-1.amazonaws.com'     => 'Z11RGJOFQNVJUP',
      's3-website-ap-southeast-1.amazonaws.com' => 'Z3O0J2DXBE1FTB',
      's3-website-ap-southeast-2.amazonaws.com' => 'Z1WCIGYICN2BYD',
      's3-website.eu-central-1.amazonaws.com'   => 'Z21DNDUVLTQW6Q',
      's3-website-eu-west-1.amazonaws.com'      => 'Z1BKCTXD74EZPE',
      's3-website-sa-east-1.amazonaws.com'      => 'Z7KQH4QJS55SO',
      's3-website-us-east-1.amazonaws.com'      => 'Z3AQBSTGFYJSTF',
      's3-website-us-gov-west-1.amazonaws.com'  => 'Z31GFT0UA1I2HV',
      's3-website-us-west-1.amazonaws.com'      => 'Z2F56UZL2M1ACD',
      's3-website-us-west-2.amazonaws.com'      => 'Z3BJ6K6RIION7M',
    }

    CANONICAL_HOSTED_ZONE_NAME_IDS = {
      'ap-northeast-1' => 'Z2YN17T5R711GT',
      #'ap-northeast-2' => '',
      #'ap-south-1'     => '',
      'ap-southeast-1' => 'Z1WI8VXHPB1R38',
      'ap-southeast-2' => 'Z2999QAZ9SRTIC',
      'eu-central-1'   => 'Z215JYRZR1TBD5',
      'eu-west-1'      => 'Z3NF1Z3NOM5OY2',
      'sa-east-1'      => 'Z2ES78Y61JGQKS',
      'us-east-1'      => 'Z3DZXE0Q79N41H',
      'us-west-1'      => 'Z1M58G0W56PQJA',
      'us-west-2'      => 'Z33MTJ483KN6FU',
    }

    DUALSTACK_CANONICAL_HOSTED_ZONE_NAME_IDS = {
      'ap-northeast-1' => 'Z14GRHDCWA56QT',
      'ap-northeast-2' => 'ZWKZPGTI48KDX',
      'ap-south-1'     => 'ZP97RAFLXTNZK',
      'ap-southeast-1' => 'Z1LMS91P8CMLE5',
      'ap-southeast-2' => 'Z1GM3OXH4ZPM65',
      'eu-central-1'   => 'Z215JYRZR1TBD5',
      'eu-west-1'      => 'Z32O12XQLNTSW2',
      'sa-east-1'      => 'Z2P70J7HTTTPLU',
      'us-east-1'      => 'Z35SXDOTRQ7X7K',
      'us-west-1'      => 'Z368ELLRRE2KJ0',
      'us-west-2'      => 'Z1H1FL5HABSF5',
   }

    # http://docs.aws.amazon.com/Route53/latest/APIReference/API_ChangeResourceRecordSets.html
    CF_HOSTED_ZONE_ID = 'Z2FDTNDATAQYW2'

    # http://docs.aws.amazon.com/general/latest/gr/rande.html#elasticbeanstalk_region
    ELASTIC_BEANSTALK_HOSTED_ZONE_NAME_IDS = {
      'ap-northeast-1' => 'Z1R25G3KIG2GBW',
      'ap-northeast-2' => 'Z3JE5OI70TWKCP',
      'ap-south-1'     => 'Z18NTBI3Y7N9TZ',
      'ap-southeast-1' => 'Z16FZ9L249IFLT',
      'ap-southeast-2' => 'Z2PCDNR3VC2G1N',
      'eu-central-1'   => 'Z1FRNW7UH4DEZJ',
      'eu-west-1'      => 'Z2NYPWQ7DFZAZH',
      'sa-east-1'      => 'Z10X7K2B4QSOFV',
      'us-east-1'      => 'Z117KPS5GTRQ2G',
      'us-east-2'      => 'Z14LCN19Q5QHIC',
      'us-west-1'      => 'Z1LQECGX5PH1X',
      'us-west-2'      => 'Z38NKT9BP95V3O',
    }

    # https://docs.aws.amazon.com/general/latest/gr/rande.html#apigateway_region
    API_GATEWAY_HOSTED_ZONE_NAME_IDS = {
      "us-east-2"       => "ZOJJZC49E0EPZ",
      "us-east-1"       => "Z1UJRXOUMOOFQ8",
      "us-west-1"       => "Z2MUQ32089INYE",
      "us-west-2"       => "Z2OJLYMUO9EFXC",
      "ap-south-1"      => "Z3VO1THU9YC4UR",
      "ap-northeast-3"  => "Z2YQB5RD63NC85",
      "ap-northeast-2"  => "Z20JF4UZKIW1U8",
      "ap-southeast-1"  => "ZL327KTPIQFUL",
      "ap-southeast-2"  => "Z2RPCDW04V8134",
      "ap-northeast-1"  => "Z1YSHQZHG15GKL",
      "ca-central-1"    => "Z19DQILCV0OWEC",
      "eu-central-1"    => "Z1U9ULNL0V5AJ3",
      "eu-west-1"       => "ZLY8HYME6SFDD",
      "eu-west-2"       =>  "ZJ5UAJN8Y3Z2Q",
      "eu-west-3"       =>  "Z3KY65QIEKYHQQ",
      "sa-east-1"       =>  "ZCMLWB8V5SYIT"
    }

    class << self
      def normalize_dns_name_options(src)
        dst = {}

        {
          :evaluate_target_health => false,
        }.each do |key, defalut_value|
          dst[key] = src[key] || false
        end

        return dst
      end

      def dns_name_to_alias_target(name, options, hosted_zone_id, hosted_zone_name)
        hosted_zone_name = hosted_zone_name.sub(/\.\z/, '')
        name = name.sub(/\.\z/, '')
        options ||= {}

        if name =~ /([^.]+)\.elb\.amazonaws.com\z/i
          region = $1.downcase
          alias_target = elb_dns_name_to_alias_target(name, region, options)

          # XXX:
          alias_target.merge(options)
        elsif (s3_hosted_zone_id = S3_WEBSITE_ENDPOINTS[name.downcase]) and name =~ /\As3-website-([^.]+)\.amazonaws\.com\z/i
          region = $1.downcase
          s3_dns_name_to_alias_target(name, region, s3_hosted_zone_id)
        elsif name =~ /\.cloudfront\.net\z/i
          cf_dns_name_to_alias_target(name)
        elsif name =~ /(\A|\.)#{Regexp.escape(hosted_zone_name)}\z/i
          this_hz_dns_name_to_alias_target(name, hosted_zone_id, options)
        elsif name =~ /\.([^.]+)\.elasticbeanstalk\.com\z/i
          region = $1.downcase
          eb_dns_name_to_alias_target(name, region)
        elsif name =~ /\.execute-api\.([^.]+)\.amazonaws\.com\z/i
          apigw_dns_name_to_alias_target(name, region, hosted_zone_id)
        else
          raise "Invalid DNS Name: #{name}"
        end
      end

      private

      def elb_dns_name_to_alias_target(name, region, options)
        if options[:hosted_zone_id]
          {
            :hosted_zone_id => options[:hosted_zone_id],
            :dns_name       => name,
            :evaluate_target_health => false, # XXX:
          }
        else
          hosted_zone_id = nil

          if name =~ /\Adualstack\./i
            hosted_zone_id = DUALSTACK_CANONICAL_HOSTED_ZONE_NAME_IDS[region]
          else
            hosted_zone_id = CANONICAL_HOSTED_ZONE_NAME_IDS[region]
          end

          unless hosted_zone_id
            raise "Cannot find CanonicalHostedZoneNameID for `#{name}`. Please pass :hosted_zone_id"
          end

          {
            :hosted_zone_id         => hosted_zone_id,
            :dns_name               => name,
            :evaluate_target_health => false, # XXX:
          }
        end
      end

      def s3_dns_name_to_alias_target(name, region, hosted_zone_id)
        {
          :hosted_zone_id         => hosted_zone_id,
          :dns_name               => name,
          :evaluate_target_health => false, # XXX:
        }
      end

      def apigw_dns_name_to_alias_target(name, region, hosted_zone_id)
        {
          :hosted_zone_id         => API_GATEWAY_HOSTED_ZONE_NAME_IDS[region],
          :dns_name               => name,
          :evaluate_target_health => false, # XXX:
        }
      end

      def cf_dns_name_to_alias_target(name)
        {
          :hosted_zone_id         => CF_HOSTED_ZONE_ID,
          :dns_name               => name,
          :evaluate_target_health => false, # XXX:
        }
      end

      def this_hz_dns_name_to_alias_target(name, hosted_zone_id, options)
        {
          :hosted_zone_id         => hosted_zone_id,
          :dns_name               => name,
          :evaluate_target_health => options[:evaluate_target_health] || false
        }
      end

      def eb_dns_name_to_alias_target(name, region)
        {
          :hosted_zone_id         => ELASTIC_BEANSTALK_HOSTED_ZONE_NAME_IDS[region],
          :dns_name               => name,
          :evaluate_target_health => false, # XXX:
        }
      end
    end # of class method

  end # Route53
end # Roadworker
