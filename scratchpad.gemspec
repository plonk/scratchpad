# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'scratchpad/version'

Gem::Specification.new do |spec|
  spec.name          = "scratchpad-app"
  spec.version       = Scratchpad::VERSION
  spec.authors       = ["Yoteichi"]
  spec.email         = ["plonk@piano.email.ne.jp"]

  spec.summary       = %q{A paint program for note taking.}
  spec.description   = %q{A paint program for note taking.}
  spec.homepage      = "https://github.com/plonk/scratchpad"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "toml"
  spec.add_dependency "gtk2"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
