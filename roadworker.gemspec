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
  spec.homepage      = "http://roadworker.codenize.tools/"
  spec.license       = "MIT"
  spec.files         = %w(README.md) + Dir.glob('bin/**/*') + Dir.glob('lib/**/*')

  #spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  #spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-v1", ">= 1.62.0"
  spec.add_dependency "term-ansicolor"
  spec.add_dependency "net-dns2", "~> 0.8.6"
  spec.add_dependency "uuid"
  spec.add_dependency "systemu"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", ">= 3.0.0"
  spec.add_development_dependency "rspec-instafail"
  spec.add_development_dependency "rubydns", "~> 0.8.5"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "transpec"
end
