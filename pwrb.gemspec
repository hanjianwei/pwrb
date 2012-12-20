# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pwrb/version'

Gem::Specification.new do |gem|
  gem.name          = "pwrb"
  gem.version       = Pwrb::VERSION
  gem.authors       = ["Jianwei Han"]
  gem.email         = ["hanjianwei@gmail.com"]
  gem.description   = %q{pwrb is a cli password management software.}
  gem.summary       = %q{pwrb is a command line password management software based on GPG. Please run `pwrb -h` for more information. }
  gem.homepage      = "https://github.com/hanjianwei/pwrb"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency('gpgme', "~> 2.0.1")
  gem.add_runtime_dependency('tabularize', "~> 0.2.9")
  gem.add_runtime_dependency('clipboard', "~> 1.0.1")
  gem.add_runtime_dependency('highline', "~> 1.6.15")

  gem.add_development_dependency "bundler", ">= 1.2.3"
end
