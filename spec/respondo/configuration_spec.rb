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
    expect(config.serializer_type).to         eq(:none)
    expect(config.jsonapi_include_type).to    eq(false)
    expect(config.unwrap_jsonapi?).to         eq(false)
  end

  describe "#serializer_type=" do
    it "accepts symbols and strings, normalising case and dashes" do
      config = described_class.new
      config.serializer_type = "Fast-JSONAPI"
      expect(config.serializer_type).to eq(:fast_jsonapi)
    end

    it "treats nil and blank as :none" do
      config = described_class.new
      config.serializer_type = nil
      expect(config.serializer_type).to eq(:none)
      config.serializer_type = " "
      expect(config.serializer_type).to eq(:none)
    end

    it "turns on JSON:API flattening only for JSON:API types" do
      config = described_class.new
      %i[fast_jsonapi jsonapi jsonapi_serializer].each do |type|
        config.serializer_type = type
        expect(config.unwrap_jsonapi?).to eq(true)
      end
      %i[none json blueprinter ams active_model_serializers].each do |type|
        config.serializer_type = type
        expect(config.unwrap_jsonapi?).to eq(false)
      end
    end

    it "raises ArgumentError for an unknown type" do
      expect { described_class.new.serializer_type = :bogus }.to raise_error(ArgumentError, /Unknown serializer_type/)
    end

    it "is cleared by Respondo.reset!" do
      Respondo.configure { |c| c.serializer_type = :fast_jsonapi }
      Respondo.reset!
      expect(Respondo.config.serializer_type).to eq(:none)
    end
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
