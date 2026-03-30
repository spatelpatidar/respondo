# frozen_string_literal: true
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter 'lib/respondo/version.rb'
  add_filter 'lib/respondo/railtie.rb'
  track_files 'lib/**/*.rb'
end

require "respondo"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    Respondo.reset!
  end
end
