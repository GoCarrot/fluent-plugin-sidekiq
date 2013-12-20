# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fluent/plugin/sidekiq/version'

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-sidekiq"
  spec.version       = File.read("VERSION").strip
  spec.authors       = ["Alex Scarborough"]
  spec.email         = ["alex@gocarrot.com"]
  spec.description   = %q{Sidekiq plugin for Fluentd}
  spec.summary       = spec.description
  spec.homepage      = "https://github.com/GoCarrot/fluent-plugin-sidekiq"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "fluentd"
  spec.add_dependency "redis"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
