# frozen_string_literal: true

require "respondo"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    Respondo.reset!
  end
end
