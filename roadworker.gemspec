# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'roadworker/version'

Gem::Specification.new do |spec|
  spec.name          = "roadworker"
  spec.version       = Roadworker::VERSION
  spec.authors       = ["winebarrel", "Cookpad Inc."]
  spec.email         = ["sgwr_dts@yahoo.co.jp", "kaihatsu@cookpad.com"]
  spec.description   = "Roadworker is a tool to manage Route53. It defines the state of Route53 using DSL, and updates Route53 according to DSL."
  spec.summary       = "Roadworker is a tool to manage Route53."
  spec.homepage      = "https://github.com/cookpad/roadworker"
  spec.license       = "MIT"
  spec.files         = %w(README.md) + Dir.glob('bin/**/*') + Dir.glob('lib/**/*')

  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-route53", ">= 1.22.0"
  spec.add_dependency "term-ansicolor"
  spec.add_dependency "dnsruby"
  spec.add_dependency "uuid"
  spec.add_dependency "systemu"
  spec.add_dependency "diffy"
  spec.add_dependency "hashie"
  spec.add_dependency "ipaddr"
  spec.add_dependency "ostruct"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", ">= 3.0.0"
  spec.add_development_dependency "rspec-instafail", ">= 1.0.0"
  spec.add_development_dependency "rubydns", "~> 0.8.5"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "nokogiri"
end
