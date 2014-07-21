# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pd-cap-recipes/version"

Gem::Specification.new do |s|
  s.name        = "pd-cap-recipes"
  s.version     = Pd::Cap::Recipes::VERSION
  s.authors     = ["Simon Mathieu"]
  s.email       = ["simon@pagerduty.com"]
  s.homepage    = ""
  s.summary     = %q{A collection of capistrano recipes used by PagerDuty Inc.}
  s.description = %q{A collection of capistrano recipes used by PagerDuty Inc.}

  s.rubyforge_project = "pd-cap-recipes"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "grit", ">= 2.5.0"
  s.add_dependency "git", ">= 1.2.5"
  s.add_dependency "capistrano", "~> 2.15"

  # Also add these to your gem file
  # gem 'cap_gun', :git => "git://github.com/ffmike/cap_gun.git"
  # gem 'hipchat', :git => 'git://github.com/lkosewsk/hipchat.git'
end
