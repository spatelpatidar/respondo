# frozen_string_literal: true

require "spec_helper"

RSpec.describe Respondo::ResponseBuilder do
  def build(opts = {})
    described_class.new(**opts).build
  end

  # --- Structure ------------------------------------------------------------

  describe "response structure" do
    it "always includes success, message, data, meta" do
      result = build(success: true)
      expect(result).to have_key(:success)
      expect(result).to have_key(:message)
      expect(result).to have_key(:data)
      expect(result).to have_key(:meta)
    end

    it "meta always includes timestamp" do
      result = build(success: true)
      expect(result[:meta]).to have_key(:timestamp)
      expect(result[:meta][:timestamp]).to match(/\d{4}-\d{2}-\d{2}T/)
    end
  end

  # --- Success --------------------------------------------------------------

  describe "success response" do
    it "sets success: true" do
      expect(build(success: true)[:success]).to eq(true)
    end

    it "uses default success message when none provided" do
      expect(build(success: true)[:message]).to eq("Success")
    end

    it "uses provided message" do
      result = build(success: true, message: "User created")
      expect(result[:message]).to eq("User created")
    end

    it "serializes data" do
      result = build(success: true, data: { id: 1, name: "Alice" })
      expect(result[:data]).to eq({ id: 1, name: "Alice" })
    end

    it "sets data to nil when not provided" do
      expect(build(success: true)[:data]).to be_nil
    end

    it "does not include errors key on success" do
      result = build(success: true)
      expect(result).not_to have_key(:errors)
    end
  end

  # --- Error ----------------------------------------------------------------

  describe "error response" do
    it "sets success: false" do
      expect(build(success: false)[:success]).to eq(false)
    end

    it "uses default error message when none provided" do
      expect(build(success: false)[:message]).to eq("An error occurred")
    end

    it "includes errors when provided" do
      result = build(success: false, errors: { email: ["is invalid"] })
      expect(result[:errors]).to eq({ email: ["is invalid"] })
    end

    it "omits errors key when errors is nil" do
      result = build(success: false)
      expect(result).not_to have_key(:errors)
    end

    it "omits errors key when errors is empty" do
      result = build(success: false, errors: {})
      expect(result).not_to have_key(:errors)
    end
  end

  # --- Meta -----------------------------------------------------------------

  describe "meta block" do
    it "merges extra meta provided by caller" do
      result = build(success: true, meta: { version: "v2" })
      expect(result[:meta][:version]).to eq("v2")
    end

    it "caller meta overrides built-in meta keys" do
      fixed_time = "2024-01-01T00:00:00Z"
      result = build(success: true, meta: { timestamp: fixed_time })
      expect(result[:meta][:timestamp]).to eq(fixed_time)
    end

    it "includes pagination when collection has pagination methods" do
      collection = double("Collection",
        current_page: 1,
        limit_value:  10,
        total_pages:  3,
        total_count:  25,
        next_page:    2,
        prev_page:    nil
      )
      result = build(success: true, data: collection)
      expect(result[:meta]).to have_key(:pagination)
      expect(result[:meta][:pagination][:current_page]).to eq(1)
      expect(result[:meta][:pagination][:total_count]).to  eq(25)
    end

    it "does not include pagination for plain arrays" do
      result = build(success: true, data: [1, 2, 3])
      expect(result[:meta]).not_to have_key(:pagination)
    end
  end

  # --- Camelization ---------------------------------------------------------

  describe "camelize_keys" do
    before { Respondo.configure { |c| c.camelize_keys = true } }

    it "camelizes top-level keys" do
      result = build(success: true)
      expect(result).to have_key(:success)   # already camel
      expect(result).to have_key(:message)
    end

    it "camelizes nested meta keys" do
      collection = double("Collection",
        current_page: 1,
        limit_value:  5,
        total_pages:  2,
        total_count:  8,
        next_page:    2,
        prev_page:    nil
      )
      result = build(success: true, data: collection)
      pagination = result[:meta][:pagination]
      expect(pagination).to have_key(:currentPage)
      expect(pagination).to have_key(:totalPages)
      expect(pagination).to have_key(:totalCount)
      expect(pagination).to have_key(:nextPage)
      expect(pagination).to have_key(:prevPage)
      expect(pagination).to have_key(:perPage)
    end

    it "camelizes data hash keys" do
      result = build(success: true, data: { first_name: "Alice", last_name: "Smith" })
      expect(result[:data]).to have_key(:firstName)
      expect(result[:data]).to have_key(:lastName)
    end
  end
end
