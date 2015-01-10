# Roadworker

Roadworker is a tool to manage Route53.

It defines the state of Route53 using DSL, and updates Route53 according to DSL.

[![Gem Version](https://badge.fury.io/rb/roadworker.png)](http://badge.fury.io/rb/roadworker)
[![Build Status](https://travis-ci.org/winebarrel/roadworker.svg?branch=master)](https://travis-ci.org/winebarrel/roadworker)
[![Coverage Status](https://coveralls.io/repos/winebarrel/roadworker/badge.png?branch=master)](https://coveralls.io/r/winebarrel/roadworker?branch=master)

**Notice**

* Roadworker cannot update TTL of two or more same weighted A records (with different SetIdentifier) after creation.
* `>= 0.4.3` compare resource records ignoring the order.

## Installation

Add this line to your application's Gemfile:

    gem 'roadworker'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install roadworker

## Usage

```sh
export AWS_ACCESS_KEY_ID='...'
export AWS_SECRET_ACCESS_KEY='...'
roadwork -e -o Routefile
vi Routefile
roadwork -a --dry-run
roudwork -a
```

## Help

```
Usage: roadwork [options]
    -p, --profile PROFILE_NAME
        --credentials-path PATH
    -k, --access-key ACCESS_KEY
    -s, --secret-key SECRET_KEY
    -a, --apply
    -f, --file FILE
        --dry-run
        --force
        --no-health-check-gc
    -e, --export
    -o, --output FILE
        --split
        --with-soa-ns
    -t, --test
        --nameservers SERVERS
        --port PORT
        --target-zone REGEXP
        --no-color
        --debug
```

## Routefile example

```ruby
require 'other/routefile'

hosted_zone "winebarrel.jp." do
  rrset "winebarrel.jp.", "A" do
    ttl 300
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "winebarrel.jp.", "MX" do
    ttl 300
    resource_records(
      "10 mx.winebarrel.jp",
      "10 mx2.winebarrel.jp"
    )
  end
end

hosted_zone "info.winebarrel.jp." do
  rrset "xxx.info.winebarrel.jp.", "A" do
    dns_name "elb-dns-name.elb.amazonaws.com"
  end

  rrset "yyy.info.winebarrel.jp.", "A" do
    dns_name "elb-dns-name2.elb.amazonaws.com", :evaluate_target_health => true
  end

  rrset "zzz.info.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "http://example.com:80/path", :search_string => "ANY_RESPONSE_STRING", :request_interval => 30, :failure_threshold => 3
    # If you want to specify the IP address:
    #health_check "http://192.0.43.10:80/path", :host => "example.com",...
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "zzz.info.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "tcp://192.0.43.10:3306", :request_interval => 30, :failure_threshold => 3
    ttl 456
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end
end

# Private HostedZone
hosted_zone "winebarrel.local." do
  vpc "us-east-1", "vpc-xxxxxxxx"
  vpc "us-east-2", "vpc-xxxxxxxx"

  rrset "winebarrel.local.", "A" do
    ttl 300
    resource_records(
      "10.0.0.1",
      "10.0.0.2"
    )
  end
end
```

### Dynamic private DNS example

```ruby
hosted_zone "us-east-1.my.local." do
  vpc "us-east-1", "vpc-xxxxxxxx"

  AWS::EC2.new(region: "us-east-1").vpcs["vpc-xxxxxxxx"].instances.each {|instance|
    rrset "#{instance.tags.Name}.us-east-1.my.local.", "A" do
      ttl 300
      resource_records instance.private_ip_address
    end
  }
end
```

## Test

Routefile compares the results of a query to the DNS and DSL in the test mode.

```
shell> roadwork -t
..F..
info.winebarrel.jp. A:
  expected=127.0.0.1(300),127.0.0.3(300)
  actual=127.0.0.1(300),127.0.0.2(300)
5 examples, 1 failure
```

(Please note test of A(Alias) is not possible to perfection...)

## Demo

![Roadworker Demo](https://raw.githubusercontent.com/winebarrel/roadworker/master/etc/demo.gif)

## DNS management using GitHub/Bitbucket

![DNS management using Git](https://cacoo.com/diagrams/geJfslZqd8qne90t-BC7C7.png)

* [Bitbucket example repository](https://bitbucket.org/winebarrel/roadworker-example/src)
* [drone.io example project](https://drone.io/bitbucket.org/winebarrel/roadworker-example/latest)

## Link
* [RubyGems.org site](http://rubygems.org/gems/roadworker)

## Similar tools
* [Codenize.tools](http://codenize.tools/)
