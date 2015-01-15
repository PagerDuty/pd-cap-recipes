# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pd-cap-recipes/version"

Gem::Specification.new do |s|
  s.name        = "pd-cap-recipes"
  s.version     = Pd::Cap::Recipes::VERSION
  s.authors     = ["Simon Mathieu"]
  s.email       = ["simon@pagerduty.com"]
  s.homepage    = 'https://github.com/PagerDuty/pd-cap-recipes'
  s.summary     = %q{A collection of capistrano recipes used by PagerDuty Inc.}
  s.description = %q{A collection of capistrano recipes used by PagerDuty Inc.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency 'bundler', '~> 1.6'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec-core'
  s.add_development_dependency 'guard-rspec'
  s.add_development_dependency 'capistrano-spec', '~> 0.2.0'

  s.add_runtime_dependency 'capistrano', '~> 2.15'
  s.add_runtime_dependency 'grit', '~> 2.5.0'
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'mysql2'
end
