# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'roadworker/version'

Gem::Specification.new do |spec|
  spec.name          = "roadworker"
  spec.version       = Roadworker::VERSION
  spec.authors       = "winebarrel"
  spec.email         = "sgwr_dts@yahoo.co.jp"
  spec.description   = "Roadworker is a tool to manage Route53. It defines the state of Route53 using DSL, and updates Route53 according to DSL."
  spec.summary       = "Roadworker is a tool to manage Route53."
  spec.homepage      = "https://bitbucket.org/winebarrel/roadworker"
  spec.license       = "MIT"
  spec.files         = %w(README.md) + Dir.glob('bin/**/*') + Dir.glob('lib/**/*')

  #spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  #spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk", "= 1.39.0" # PTF:
  spec.add_dependency "term-ansicolor"
  spec.add_dependency "net-dns", "~> 0.8.0"
  spec.add_dependency "uuid"
  spec.add_dependency "systemu"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.14.1"
  spec.add_development_dependency "rspec-instafail"
end
