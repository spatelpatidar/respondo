# frozen_string_literal: true

require "spec_helper"

RSpec.describe Respondo::Serializer do
  describe ".call" do
    it "returns nil for nil input" do
      expect(described_class.call(nil)).to be_nil
    end

    it "returns primitives as-is" do
      expect(described_class.call("hello")).to eq("hello")
      expect(described_class.call(42)).to      eq(42)
      expect(described_class.call(true)).to    eq(true)
    end

    it "serializes a plain Hash" do
      input = { name: "Alice", age: 30 }
      expect(described_class.call(input)).to eq({ name: "Alice", age: 30 })
    end

    it "serializes an Array of primitives" do
      input = [1, 2, 3]
      expect(described_class.call(input)).to eq([1, 2, 3])
    end

    it "serializes an Array of Hashes" do
      input = [{ id: 1 }, { id: 2 }]
      expect(described_class.call(input)).to eq([{ id: 1 }, { id: 2 }])
    end

    it "serializes an Exception" do
      error = RuntimeError.new("something broke")
      result = described_class.call(error)
      expect(result).to eq({ message: "something broke" })
    end

    it "serializes objects responding to #to_h" do
      obj = double("MyObject")
      allow(obj).to receive(:respond_to?).with(:as_json).and_return(false)
      allow(obj).to receive(:respond_to?).with(:to_h).and_return(true)
      allow(obj).to receive(:to_h).and_return({ id: 99 })
      expect(described_class.call(obj)).to eq({ id: 99 })
    end

    it "uses custom serializer when configured" do
      Respondo.configure { |c| c.serializer = ->(obj) { { wrapped: obj } } }
      expect(described_class.call("test")).to eq({ wrapped: "test" })
    end

    it "recursively serializes nested Hash values" do
      input = { user: { name: "Bob" }, tags: [1, 2] }
      result = described_class.call(input)
      expect(result[:user]).to eq({ name: "Bob" })
      expect(result[:tags]).to eq([1, 2])
    end
  end
end
