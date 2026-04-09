# frozen_string_literal: true

require_relative "lib/respondo/version"

Gem::Specification.new do |spec|
  spec.name          = "respondo"
  spec.version       = Respondo::VERSION
  spec.authors       = ["shailendra Kumar"]
  spec.email         = ["shailendrapatidar00@gmail.com"]

  spec.summary       = "Smart JSON API response formatter for Rails — consistent structure every time."
  spec.description   = <<~DESC
    Respondo standardizes JSON API responses across Rails applications.
    Every response gets success, data, message, and meta fields.
    Automatic pagination meta for Kaminari and Pagy collections.
    ActiveRecord serialization, error extraction, and flexible HTTP codes built in.
  DESC
  spec.homepage      = "https://github.com/spatelpatidar/respondo"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/auditron/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE.txt", "CHANGELOG.md", "respondo.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "railties",        "~> 8.1.3"
  spec.add_development_dependency "rspec",           "~> 3.12"
  spec.add_development_dependency "rake",            "~> 13.0"
  spec.add_development_dependency "activesupport",   "~> 8.1.3"
  spec.add_development_dependency 'simplecov',       "~> 0.22"
end
