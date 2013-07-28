# Roadworker

Roadworker is a tool to manage Route53.

It defines the state of Route53 using DSL, and updates Route53 according to DSL.

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
shell> roadwork --dry-run
shell> roudwork
```

## Routefile esample

```ruby
require 'other/routefile'

hosted_zone "winebarrel.jp." do
  rrset "winebarrel.jp.", "MX" do
    ttl 300
    resource_records(
      "10 mx.winebarrel.jp",
      "10 mx2.winebarrel.jp"
    )
  end

  rrset "winebarrel.jp.", "NS" do
    ttl 86400
    resource_records(
      "ns-463.awsdns-57.com.",
      "ns-1382.awsdns-44.org.",
      "ns-752.awsdns-30.net.",
      "ns-1621.awsdns-10.co.uk."
    )
  end

  rrset "winebarrel.jp.", "SOA" do
    ttl 86400
    resource_records(
      "ns-463.awsdns-57.com. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"
    )
  end
end

hosted_zone "info.winebarrel.jp." do
  rrset "xxx.info.winebarrel.jp.", "A" do
    dns_name "elb-dns-name.elb.amazonaws.com"
  end
end
```
