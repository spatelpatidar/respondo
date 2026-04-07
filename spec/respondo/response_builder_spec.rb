# frozen_string_literal: true

require "spec_helper"

RSpec.describe Respondo::ResponseBuilder do
  def build(opts = {})
    described_class.new(**opts).build
  end

  # ---------------------------------------------------------------------------
  # Top-level structure
  # ---------------------------------------------------------------------------

  describe "response structure" do
    it "always includes success, message, data, meta" do
      result = build(success: true)
      expect(result.keys).to include(:success, :message, :data, :meta)
    end

    it "never includes unexpected top-level keys on a success response" do
      result = build(success: true)
      expect(result.keys).to match_array(%i[success message data meta])
    end

    it "includes errors key only when errors are present" do
      with_errors    = build(success: false, errors: { email: ["is invalid"] })
      without_errors = build(success: false)

      expect(with_errors.keys).to    include(:errors)
      expect(without_errors.keys).not_to include(:errors)
    end
  end

  # ---------------------------------------------------------------------------
  # success flag
  # ---------------------------------------------------------------------------

  describe "success field" do
    it "is true for success responses" do
      expect(build(success: true)[:success]).to eq(true)
    end

    it "is false for error responses" do
      expect(build(success: false)[:success]).to eq(false)
    end
  end

  # ---------------------------------------------------------------------------
  # message
  # ---------------------------------------------------------------------------

  describe "message field" do
    it "uses default success message when none provided" do
      expect(build(success: true)[:message]).to eq("Success")
    end

    it "uses default error message when none provided" do
      expect(build(success: false)[:message]).to eq("An error occurred")
    end

    it "uses provided message over default" do
      expect(build(success: true, message: "All good")[:message]).to eq("All good")
    end

    it "falls back to default when message is an empty string" do
      expect(build(success: true, message: "")[:message]).to eq("Success")
    end

    it "respects configured default_success_message" do
      Respondo.configure { |c| c.default_success_message = "OK" }
      expect(build(success: true)[:message]).to eq("OK")
    end

    it "respects configured default_error_message" do
      Respondo.configure { |c| c.default_error_message = "Oops" }
      expect(build(success: false)[:message]).to eq("Oops")
    end
  end

  # ---------------------------------------------------------------------------
  # data
  # ---------------------------------------------------------------------------

  describe "data field" do
    it "is nil when no data given" do
      expect(build(success: true)[:data]).to be_nil
    end

    it "returns a plain hash as-is" do
      result = build(success: true, data: { id: 1, name: "Alice" })
      expect(result[:data]).to eq({ id: 1, name: "Alice" })
    end

    it "returns a plain array as-is" do
      result = build(success: true, data: [1, 2, 3])
      expect(result[:data]).to eq([1, 2, 3])
    end

    it "returns a string primitive as-is" do
      expect(build(success: true, data: "hello")[:data]).to eq("hello")
    end

    it "returns an integer primitive as-is" do
      expect(build(success: true, data: 42)[:data]).to eq(42)
    end

    it "uses the custom serializer from config when set" do
      Respondo.configure { |c| c.serializer = ->(_obj) { { custom: true } } }
      result = build(success: true, data: { anything: 1 })
      expect(result[:data]).to eq({ custom: true })
    end
  end

  # ---------------------------------------------------------------------------
  # errors
  # ---------------------------------------------------------------------------

  describe "errors field" do
    it "includes errors hash when provided" do
      result = build(success: false, errors: { name: ["can't be blank"] })
      expect(result[:errors]).to eq({ name: ["can't be blank"] })
    end

    it "omits errors key when errors is nil" do
      expect(build(success: false, errors: nil).keys).not_to include(:errors)
    end

    it "omits errors key when errors is an empty hash" do
      expect(build(success: false, errors: {}).keys).not_to include(:errors)
    end

    it "appears before meta in the response hash" do
      result = build(success: false, errors: { x: ["bad"] })
      keys   = result.keys
      expect(keys.index(:errors)).to be < keys.index(:meta)
    end
  end

  # ---------------------------------------------------------------------------
  # meta — timestamp
  # ---------------------------------------------------------------------------

  describe "meta timestamp" do
    it "is always present" do
      expect(build(success: true)[:meta]).to have_key(:timestamp)
    end

    it "is an ISO8601 string" do
      ts = build(success: true)[:meta][:timestamp]
      expect(ts).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end
  end

  # ---------------------------------------------------------------------------
  # meta — request_id
  # ---------------------------------------------------------------------------

  describe "meta request_id" do
    let(:fake_request) do
      double("Request", request_id: "abc-123", respond_to?: true).tap do |r|
        allow(r).to receive(:respond_to?).with(:request_id).and_return(true)
      end
    end

    it "is absent when include_request_id is false (default)" do
      result = build(success: true, request: fake_request)
      expect(result[:meta]).not_to have_key(:request_id)
    end

    it "is present when include_request_id is true" do
      Respondo.configure { |c| c.include_request_id = true }
      result = build(success: true, request: fake_request)
      expect(result[:meta][:request_id]).to eq("abc-123")
    end

    it "is absent when request is nil even if include_request_id is true" do
      Respondo.configure { |c| c.include_request_id = true }
      result = build(success: true, request: nil)
      expect(result[:meta]).not_to have_key(:request_id)
    end

    it "appears before timestamp in meta" do
      Respondo.configure { |c| c.include_request_id = true }
      result = build(success: true, request: fake_request)
      keys   = result[:meta].keys
      expect(keys.index(:request_id)).to be < keys.index(:timestamp)
    end
  end

  # ---------------------------------------------------------------------------
  # meta — default_meta from config
  # ---------------------------------------------------------------------------

  describe "meta default_meta" do
    it "merges configured default_meta into every response" do
      Respondo.configure { |c| c.default_meta = { api_version: "v1" } }
      result = build(success: true)
      expect(result[:meta][:api_version]).to eq("v1")
    end

    it "allows caller meta to override default_meta" do
      Respondo.configure { |c| c.default_meta = { api_version: "v1" } }
      result = build(success: true, meta: { api_version: "v2" })
      expect(result[:meta][:api_version]).to eq("v2")
    end
  end

  # ---------------------------------------------------------------------------
  # meta — caller-supplied extra meta
  # ---------------------------------------------------------------------------

  describe "caller-supplied meta" do
    it "merges arbitrary keys into meta" do
      result = build(success: true, meta: { region: "us-east-1" })
      expect(result[:meta][:region]).to eq("us-east-1")
    end

    it "caller meta overrides built-in timestamp when explicitly supplied" do
      fixed = "2024-01-01T00:00:00Z"
      result = build(success: true, meta: { timestamp: fixed })
      expect(result[:meta][:timestamp]).to eq(fixed)
    end

    it "handles nil meta gracefully (treated as empty hash)" do
      expect { build(success: true, meta: nil) }.not_to raise_error
    end
  end

  # ---------------------------------------------------------------------------
  # meta — pagination (plain hash pass-through)
  # ---------------------------------------------------------------------------

  describe "pagination in meta" do
    let(:pagination_hash) do
      {
        current_page: 2,
        per_page:     10,
        total_pages:  5,
        total_count:  50,
        next_page:    3,
        prev_page:    1
      }
    end

    it "includes pagination under meta[:pagination] when a hash is passed" do
      result = build(success: true, pagination: pagination_hash)
      expect(result[:meta][:pagination]).to eq(pagination_hash)
    end

    it "preserves all pagination keys exactly as passed" do
      result = build(success: true, pagination: pagination_hash)
      pag    = result[:meta][:pagination]
      expect(pag[:current_page]).to eq(2)
      expect(pag[:per_page]).to     eq(10)
      expect(pag[:total_pages]).to  eq(5)
      expect(pag[:total_count]).to  eq(50)
      expect(pag[:next_page]).to    eq(3)
      expect(pag[:prev_page]).to    eq(1)
    end

    it "supports nil next_page and prev_page (first/last page)" do
      pag    = pagination_hash.merge(next_page: nil, prev_page: nil)
      result = build(success: true, pagination: pag)
      expect(result[:meta][:pagination][:next_page]).to be_nil
      expect(result[:meta][:pagination][:prev_page]).to be_nil
    end

    it "omits pagination from meta when not passed (default nil)" do
      result = build(success: true)
      expect(result[:meta]).not_to have_key(:pagination)
    end

    it "omits pagination from meta when an empty hash is passed" do
      result = build(success: true, pagination: {})
      expect(result[:meta]).not_to have_key(:pagination)
    end

    it "omits pagination from meta when nil is explicitly passed" do
      result = build(success: true, pagination: nil)
      expect(result[:meta]).not_to have_key(:pagination)
    end

    it "also works when pagination is nested inside meta:" do
      result = build(success: true, meta: { pagination: pagination_hash })
      expect(result[:meta][:pagination]).to eq(pagination_hash)
    end

    it "does NOT auto-detect pagination from the data collection" do
      # The gem never inspects data for pagination — that's the user's job
      collection = double("KaminariCollection",
        current_page: 1, limit_value: 10, total_pages: 3,
        total_count: 25, next_page: 2, prev_page: nil
      )
      result = build(success: true, data: collection)
      expect(result[:meta]).not_to have_key(:pagination)
    end
  end

  # ---------------------------------------------------------------------------
  # meta — code and status pinned to end
  # ---------------------------------------------------------------------------

  describe "meta key ordering (code and status)" do
    it "code and status appear last in meta" do
      result = build(success: true, meta: { code: 200, status: :ok, extra: "x" })
      keys   = result[:meta].keys
      expect(keys.last(2)).to match_array(%i[code status])
    end

    it "omits code when not present" do
      result = build(success: true, meta: { status: :ok })
      expect(result[:meta].keys).not_to include(:code)
    end
  end

  # ---------------------------------------------------------------------------
  # camelize_keys
  # ---------------------------------------------------------------------------

  describe "camelize_keys" do
    before { Respondo.configure { |c| c.camelize_keys = true } }

    it "camelizes snake_case data keys" do
      result = build(success: true, data: { first_name: "Alice", last_name: "Smith" })
      expect(result[:data]).to have_key(:firstName)
      expect(result[:data]).to have_key(:lastName)
    end

    it "camelizes pagination keys in meta" do
      result = build(success: true, pagination: {
        current_page: 1, per_page: 10, total_pages: 3,
        total_count: 25, next_page: 2, prev_page: nil
      })
      pag = result[:meta][:pagination]
      expect(pag).to have_key(:currentPage)
      expect(pag).to have_key(:perPage)
      expect(pag).to have_key(:totalPages)
      expect(pag).to have_key(:totalCount)
      expect(pag).to have_key(:nextPage)
      expect(pag).to have_key(:prevPage)
    end

    it "camelizes keys inside nested data hashes" do
      result = build(success: true, data: { user_profile: { home_city: "NYC" } })
      expect(result[:data]).to have_key(:userProfile)
      expect(result[:data][:userProfile]).to have_key(:homeCity)
    end

    it "camelizes keys inside array elements" do
      result = build(success: true, data: [{ first_name: "A" }, { first_name: "B" }])
      expect(result[:data].first).to have_key(:firstName)
    end

    it "leaves non-snake_case keys untouched" do
      result = build(success: true, data: { id: 1, name: "Alice" })
      expect(result[:data]).to have_key(:id)
      expect(result[:data]).to have_key(:name)
    end

    it "does not camelize when camelize_keys is false (default)" do
      Respondo.reset!
      result = build(success: true, data: { first_name: "Alice" })
      expect(result[:data]).to have_key(:first_name)
      expect(result[:data]).not_to have_key(:firstName)
    end
  end
end