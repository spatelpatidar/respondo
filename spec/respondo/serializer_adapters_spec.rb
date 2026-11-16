# frozen_string_literal: true

require "spec_helper"

RSpec.describe Respondo::SerializerAdapters do
  def build(data:, **opts)
    Respondo::ResponseBuilder.new(success: true, data: data, **opts).build
  end

  let(:one_doc) do
    { data: { id: "7", type: :user, attributes: { name: "Frank", email: "f@x.com" },
              relationships: { posts: { data: [] } } } }
  end

  let(:many_doc) do
    {
      data: [
        { id: "61", type: :post, attributes: { user_id: 7, title: "A" }, relationships: { user: { data: { id: "7", type: :user } } } },
        { id: "60", type: :post, attributes: { user_id: 7, title: "B" }, relationships: { user: { data: { id: "7", type: :user } } } }
      ],
      links: { self: "http://x/posts?page=1", next: "http://x/posts?page=2" },
      included: [{ id: "7", type: :user, attributes: { name: "Frank" } }]
    }
  end

  describe "config.serializer_type" do
    it "defaults to :none" do
      expect(Respondo.config.serializer_type).to eq(:none)
      expect(Respondo.config.unwrap_jsonapi?).to be(false)
    end

    it "accepts strings, any case, dashes and nil" do
      Respondo.config.serializer_type = "Fast-JSONAPI"
      expect(Respondo.config.serializer_type).to eq(:fast_jsonapi)
      Respondo.config.serializer_type = nil
      expect(Respondo.config.serializer_type).to eq(:none)
    end

    it "raises for an unknown type" do
      expect { Respondo.config.serializer_type = :bogus }
        .to raise_error(ArgumentError, /Unknown serializer_type :bogus/)
    end
  end

  describe "with serializer_type :none (default)" do
    it "passes the JSON:API document through (data.data)" do
      result = build(data: one_doc)
      expect(result[:data][:data][:id]).to eq("7")
      expect(result[:meta]).not_to have_key(:links)
    end
  end

  %i[fast_jsonapi jsonapi jsonapi_serializer].each do |type|
    context "with serializer_type :#{type}" do
      before { Respondo.config.serializer_type = type }

      it "flattens a single resource" do
        expect(build(data: one_doc)[:data]).to eq(id: "7", name: "Frank", email: "f@x.com")
      end
    end
  end

  context "with a JSON:API serializer_type" do
    before { Respondo.config.serializer_type = :fast_jsonapi }

    it "flattens a collection and lifts links / included into meta" do
      result = build(data: many_doc, pagination: { current_page: 1 })

      expect(result[:data]).to eq([{ id: "61", user_id: 7, title: "A" }, { id: "60", user_id: 7, title: "B" }])
      expect(result[:meta][:links][:next]).to eq("http://x/posts?page=2")
      expect(result[:meta][:included]).to eq([{ id: "7", type: :user, name: "Frank" }])
      expect(result[:meta][:pagination]).to eq(current_page: 1)
    end

    it "keeps type when jsonapi_include_type is on" do
      Respondo.config.jsonapi_include_type = true
      expect(build(data: one_doc)[:data]).to eq(id: "7", type: :user, name: "Frank", email: "f@x.com")
    end

    it "handles a serializer instance" do
      serializer = Class.new { def initialize(doc) = @doc = doc; def serializable_hash(*) = @doc }.new(one_doc)
      expect(build(data: serializer)[:data][:name]).to eq("Frank")
    end

    it "handles nil and empty collections" do
      expect(build(data: { data: nil })[:data]).to be_nil
      expect(build(data: { data: [], links: { self: "x" } })[:data]).to eq([])
    end

    it "flattens a document nested inside another hash" do
      result = build(data: { token: "abc", user: one_doc })
      expect(result[:data]).to eq(token: "abc", user: { id: "7", name: "Frank", email: "f@x.com" })
    end

    it "leaves things that are not JSON:API documents alone" do
      expect(build(data: { a: 1, nested: { ok: true } })[:data]).to eq(a: 1, nested: { ok: true })
      expect(build(data: { data: "text" })[:data]).to eq(data: "text")
      expect(build(data: { data: { id: 1, type: "x" }, other: 1 })[:data]).to eq(data: { id: 1, type: "x" }, other: 1)
      expect(build(data: [1, "two"])[:data]).to eq([1, "two"])
    end

    it "lets caller meta override lifted meta but never request_id / timestamp" do
      result = build(data: many_doc, meta: { links: "mine", timestamp: "SPOOFED" })
      expect(result[:meta][:links]).to eq("mine")
      expect(result[:meta][:timestamp]).not_to eq("SPOOFED")
    end

    it "camelizes the flattened output" do
      Respondo.config.camelize_keys = true
      expect(build(data: many_doc)[:data].first.keys).to eq(%i[id userId title])
    end

    it "still enforces max_collection_size" do
      Respondo.config.max_collection_size = 1
      expect { build(data: many_doc) }.to raise_error(Respondo::CollectionTooLargeError)
    end

    it "does not touch error responses" do
      result = Respondo::ResponseBuilder.new(success: false, message: "bad", errors: { title: ["blank"] }).build
      expect(result[:data]).to be_nil
      expect(result[:errors]).to eq(title: ["blank"])
    end
  end

  %i[blueprinter ams json].each do |type|
    it "does not reshape output for :#{type}" do
      Respondo.config.serializer_type = type
      expect(build(data: { id: 1, name: "n" })[:data]).to eq(id: 1, name: "n")
      expect(build(data: one_doc)[:data][:data][:id]).to eq("7")
    end
  end
end
