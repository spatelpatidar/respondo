# frozen_string_literal: true

require "spec_helper"

# ---------------------------------------------------------------------------
# Fake Rails-like controller to test ControllerHelpers without Rails
# ---------------------------------------------------------------------------
class FakeController
  include Respondo::ControllerHelpers

  attr_reader :rendered_json, :rendered_status

  def render(json:, status:)
    @rendered_json   = json
    @rendered_status = status
  end

  # Simulate ActionController's #try
  def try(method_name)
    respond_to?(method_name) ? send(method_name) : nil
  end
end

# ---------------------------------------------------------------------------
# Specs
# ---------------------------------------------------------------------------
RSpec.describe Respondo::ControllerHelpers do
  subject(:controller) { FakeController.new }

  def response_body
    controller.rendered_json
  end

  def response_status
    controller.rendered_status
  end

  # --- render_success -------------------------------------------------------

  describe "#render_success" do
    it "renders success: true with status :ok by default" do
      controller.render_success
      expect(response_body[:success]).to eq(true)
      expect(response_status).to         eq(:ok)
    end

    it "includes data in the response" do
      controller.render_success(data: { id: 1 })
      expect(response_body[:data]).to eq({ id: 1 })
    end

    it "includes message" do
      controller.render_success(message: "Done")
      expect(response_body[:message]).to eq("Done")
    end

    it "uses default success message when none given" do
      controller.render_success
      expect(response_body[:message]).to eq("Success")
    end

    it "accepts custom status" do
      controller.render_success(status: :created)
      expect(response_status).to eq(:created)
    end

    it "includes pagination meta for paginated collections" do
      collection = double("Kaminari",
        current_page: 1, limit_value: 10, total_pages: 3,
        total_count: 25, next_page: 2, prev_page: nil
      )
      controller.render_success(data: collection)
      expect(response_body[:meta]).to have_key(:pagination)
    end

    it "accepts extra meta" do
      controller.render_success(meta: { version: "v1" })
      expect(response_body[:meta][:version]).to eq("v1")
    end
  end

  # --- render_error ---------------------------------------------------------

  describe "#render_error" do
    it "renders success: false with status :unprocessable_entity by default" do
      controller.render_error
      expect(response_body[:success]).to eq(false)
      expect(response_status).to         eq(:unprocessable_entity)
    end

    it "includes message" do
      controller.render_error(message: "Something broke")
      expect(response_body[:message]).to eq("Something broke")
    end

    it "includes field errors from a Hash" do
      controller.render_error(errors: { email: ["is invalid"] })
      expect(response_body[:errors]).to eq({ email: ["is invalid"] })
    end

    it "includes error code in meta" do
      controller.render_error(code: "AUTH_EXPIRED")
      expect(response_body[:meta][:error_code]).to eq("AUTH_EXPIRED")
    end

    it "normalizes Array errors to base key" do
      controller.render_error(errors: ["too short", "is blank"])
      expect(response_body[:errors][:base]).to eq(["too short", "is blank"])
    end

    it "normalizes String errors to base key" do
      controller.render_error(errors: "Invalid input")
      expect(response_body[:errors][:base]).to eq(["Invalid input"])
    end

    it "accepts custom status" do
      controller.render_error(status: :not_found)
      expect(response_status).to eq(:not_found)
    end

    it "does not include errors key when errors is nil" do
      controller.render_error
      expect(response_body).not_to have_key(:errors)
    end
  end

  # --- Convenience helpers --------------------------------------------------

  describe "#render_unauthorized" do
    it "renders 401 with UNAUTHORIZED code" do
      controller.render_unauthorized
      expect(response_status).to                         eq(:unauthorized)
      expect(response_body[:meta][:error_code]).to       eq("UNAUTHORIZED")
    end

    it "accepts custom message" do
      controller.render_unauthorized("Token expired")
      expect(response_body[:message]).to eq("Token expired")
    end
  end

  describe "#render_forbidden" do
    it "renders 403" do
      controller.render_forbidden
      expect(response_status).to eq(:forbidden)
      expect(response_body[:meta][:error_code]).to eq("FORBIDDEN")
    end
  end

  describe "#render_not_found" do
    it "renders 404" do
      controller.render_not_found
      expect(response_status).to eq(:not_found)
      expect(response_body[:meta][:error_code]).to eq("NOT_FOUND")
    end
  end

  describe "#render_server_error" do
    it "renders 500" do
      controller.render_server_error
      expect(response_status).to eq(:internal_server_error)
      expect(response_body[:meta][:error_code]).to eq("SERVER_ERROR")
    end
  end

  describe "#render_created" do
    it "renders 201 with data" do
      controller.render_created(data: { id: 42 }, message: "User created")
      expect(response_status).to         eq(:created)
      expect(response_body[:data]).to    eq({ id: 42 })
      expect(response_body[:message]).to eq("User created")
    end
  end

  describe "#render_no_content" do
    it "renders with nil data and success message" do
      controller.render_no_content
      expect(response_body[:success]).to eq(true)
      expect(response_body[:data]).to    be_nil
    end
  end

  # --- Response shape guarantee ---------------------------------------------

  describe "response shape guarantee" do
    it "every success response has the four required keys" do
      controller.render_success(data: { id: 1 })
      %i[success message data meta].each do |key|
        expect(response_body).to have_key(key), "missing key: #{key}"
      end
    end

    it "every error response has the four required keys" do
      controller.render_error(message: "Oops")
      %i[success message data meta].each do |key|
        expect(response_body).to have_key(key), "missing key: #{key}"
      end
    end
  end
end
