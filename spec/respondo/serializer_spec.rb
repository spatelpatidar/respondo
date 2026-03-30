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

  describe "Rails-specific objects (Mocked)" do
    it "serializes an ActiveRecord::Relation" do
      stub_const("ActiveRecord::Relation", Class.new)
      relation = double("ActiveRecord::Relation")

      # Fix: allow multiple is_a? checks
      allow(relation).to receive(:is_a?).with(ActiveRecord::Relation).and_return(true)
      allow(relation).to receive(:is_a?).with(Array).and_return(false)
      allow(relation).to receive(:is_a?).with(Hash).and_return(false)
      allow(relation).to receive(:is_a?).with(Exception).and_return(false)

      record = double("Record", as_json: { id: 1, name: "Mock" })
      # Relation behaves like an array
      allow(relation).to receive(:map).and_return([{ id: 1, name: "Mock" }])

      expect(described_class.call(relation)).to eq([{ id: 1, name: "Mock" }])
    end

    it "serializes an ActiveRecord model instance" do
      stub_const("ActiveRecord::Base", Class.new)
      model = double("ActiveRecordModel")

      # Fix: Allow all is_a? calls
      allow(model).to receive(:is_a?).and_return(false) # default
      allow(model).to receive(:is_a?).with(ActiveRecord::Base).and_return(true)

      allow(model).to receive(:as_json).and_return({ id: 5, status: "active" })

      expect(described_class.call(model)).to eq({ id: 5, status: "active" })
    end

    it "serializes ActiveModel::Errors" do
      stub_const("ActiveModel::Errors", Class.new)
      errors = double("ActiveModel::Errors")

      allow(errors).to receive(:is_a?).and_return(false) # default
      allow(errors).to receive(:is_a?).with(ActiveModel::Errors).and_return(true)

      allow(errors).to receive(:to_hash).and_return({ email: ["blank"] })

      expect(described_class.call(errors)).to eq({ email: ["blank"] })
    end
  end

  describe "Edge cases for coverage" do
    it "handles objects with #as_json but not ActiveRecord" do
      obj = double("CustomObj", as_json: { key: "value" })
      # Ensure it's not caught by AR checks
      expect(described_class.call(obj)).to eq({ key: "value" })
    end

    it "returns the object as-is if no serialization method exists" do
      # A basic object that doesn't respond to to_h or as_json
      obj = Object.new
      expect(described_class.call(obj)).to eq(obj)
    end
  end

  describe "serialize_errors branching" do
    before do
      stub_const("ActiveModel::Errors", Class.new)
    end

    it "serializes using #messages when #to_hash is not present" do
      errors = double("ActiveModel::Errors")

      allow(errors).to receive(:respond_to?).and_return(false)
      allow(errors).to receive(:is_a?).and_return(false)
      allow(errors).to receive(:is_a?).with(ActiveModel::Errors).and_return(true)
      allow(errors).to receive(:respond_to?).with(:to_hash).and_return(false)
      allow(errors).to receive(:respond_to?).with(:messages).and_return(true)
      allow(errors).to receive(:messages).and_return({ base: ["error"] })

      expect(Respondo::Serializer.call(errors)).to eq({ base: ["error"] })
    end

    it "returns an empty hash when no error methods are present" do
      errors = double("ActiveModel::Errors")
      allow(errors).to receive(:respond_to?).and_return(false)
      allow(errors).to receive(:is_a?).and_return(false)
      allow(errors).to receive(:is_a?).with(ActiveModel::Errors).and_return(true)
      allow(errors).to receive(:respond_to?).with(:to_hash).and_return(false)
      allow(errors).to receive(:respond_to?).with(:messages).and_return(false)

      expect(Respondo::Serializer.call(errors)).to eq({})
    end
  end
end
