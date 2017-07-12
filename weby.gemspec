# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'weby/version'

Gem::Specification.new do |spec|
  lpath = File.dirname(lib)
  spec.name          = "weby"
  spec.version       = Weby::VERSION
  spec.authors       = ["artix"]
  spec.email         = ["artix2@gmail.com"]
  spec.summary       = %q{Web programming for Ruby made easy.}
  spec.description   = File.read(File.join(lpath, 'GEMDESC'))
  spec.homepage      = "https://github.com/artix75/weby"
  spec.license       = "BSD"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency "nokogiri", "~> 1.8"

end
