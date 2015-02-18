# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "rate-limiter"
  spec.version       = "0.0.1"
  spec.authors       = ["Przemysław Szyszka"]
  spec.email         = ["przemeklo@o2.pl"]
  spec.summary       = "Pilot Academy Workshop: Rack"
  spec.description   = ""
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler",   "~> 1.7.4"
  spec.add_development_dependency "rake",      "~> 10.4.2"
  spec.add_development_dependency 'rack-test', "~> 0.6.3"
  spec.add_development_dependency "minitest",  "~> 5.5.1"
  spec.add_development_dependency "timecop",   "~> 0.7.1"
end
