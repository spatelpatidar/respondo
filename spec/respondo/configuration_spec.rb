# frozen_string_literal: true

require "spec_helper"

RSpec.describe Respondo::Configuration do
  it "has sensible defaults" do
    config = described_class.new
    expect(config.default_success_message).to eq("Success")
    expect(config.default_error_message).to   eq("An error occurred")
    expect(config.include_request_id).to      eq(false)
    expect(config.camelize_keys).to           eq(false)
    expect(config.serializer).to              be_nil
  end

  it "is mutable" do
    Respondo.configure do |c|
      c.default_success_message = "OK"
      c.camelize_keys           = true
    end

    expect(Respondo.config.default_success_message).to eq("OK")
    expect(Respondo.config.camelize_keys).to           eq(true)
  end

  it "resets cleanly" do
    Respondo.configure { |c| c.default_success_message = "Changed" }
    Respondo.reset!
    expect(Respondo.config.default_success_message).to eq("Success")
  end

  it "accepts a custom serializer callable" do
    serializer = ->(obj) { { custom: obj } }
    Respondo.configure { |c| c.serializer = serializer }
    expect(Respondo.config.serializer).to eq(serializer)
  end
end
