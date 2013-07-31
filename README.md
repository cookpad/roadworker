# Roadworker

Roadworker is a tool to manage Route53.

It defines the state of Route53 using DSL, and updates Route53 according to DSL.

**Notice**

* HealthCheck is not supported.
* Cannot update TTL of two or more same records (with different SetIdentifier) after creation.

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

## Link
* [RubyGems.org site](http://rubygems.org/gems/roadworker)
* [drone.io(CI)](https://drone.io/bitbucket.org/winebarrel/roadworker) [![Build Status](https://drone.io/bitbucket.org/winebarrel/roadworker/status.png)](https://drone.io/bitbucket.org/winebarrel/roadworker/latest)
