# Roadworker

Roadworker is a tool to manage Route53.

It defines the state of Route53 using DSL, and updates Route53 according to DSL.

[![Build Status](https://drone.io/bitbucket.org/winebarrel/roadworker/status.png)](https://drone.io/bitbucket.org/winebarrel/roadworker/latest)

**Notice**

* Cannot update TTL of two or more same weighted A records (with different SetIdentifier) after creation.

## Installation

Add this line to your application's Gemfile:

    gem 'roadworker'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install roadworker

## Usage

```
shell> export AWS_ACCESS_KEY_ID='...'
shell> export AWS_SECRET_ACCESS_KEY='...'
shell> roadwork -e -o Routefile
shell> vi Routefile
shell> roadwork -a --dry-run
shell> roudwork -a
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

  rrset "zzz.info.winebarrel.jp", "A" do
    set_identifier "Primary"
    failover "PRIMARY"
    health_check "http://192.0.43.10:80/path", "example.com"
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "zzz.info.winebarrel.jp", "A" do
    set_identifier "Secondary"
    failover "SECONDARY"
    health_check "tcp://192.0.43.10:3306"
    ttl 456
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end
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

## Automatic DNS update

![Automatic DNS update](https://cacoo.com/diagrams/geJfslZqd8qne90t-BC7C7.png)

### ex)

* [Bitbucket](https://bitbucket.org/winebarrel/roadworker-example/src)
* [drone.io](https://drone.io/bitbucket.org/winebarrel/roadworker-example/latest)

## Link
* [RubyGems.org site](http://rubygems.org/gems/roadworker)
