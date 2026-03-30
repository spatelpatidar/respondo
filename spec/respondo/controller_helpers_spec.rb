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
      expect(response_body[:meta][:code]).to eq("AUTH_EXPIRED")
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

    it "extracts errors from an ActiveModel::Errors object" do
      stub_const("ActiveModel::Errors", Class.new)
      mock_errors = double("ActiveModel::Errors")
      allow(mock_errors).to receive(:is_a?).with(ActiveModel::Errors).and_return(true)
      allow(mock_errors).to receive(:to_hash).and_return({ name: ["can't be blank"] })

      controller.render_error(errors: mock_errors)

      expect(response_body[:errors]).to eq({ name: ["can't be blank"] })
    end
  end

  # --- Convenience helpers --------------------------------------------------

  describe "#render_unauthorized" do
    it "renders 401 with UNAUTHORIZED code" do
      controller.render_unauthorized
      expect(response_status).to                         eq(:unauthorized)
      expect(response_body[:meta][:code]).to       eq("UNAUTHORIZED")
    end

    it "accepts custom message" do
      controller.render_unauthorized(message: "Token expired")
      expect(response_body[:message]).to eq("Token expired")
    end
  end

  describe "#render_forbidden" do
    it "renders 403" do
      controller.render_forbidden
      expect(response_status).to eq(:forbidden)
      expect(response_body[:meta][:code]).to eq("FORBIDDEN")
    end
  end

  describe "#render_not_found" do
    it "renders 404" do
      controller.render_not_found
      expect(response_status).to eq(:not_found)
      expect(response_body[:meta][:code]).to eq("NOT_FOUND")
    end
  end

  describe "#render_server_error" do
    it "renders 500" do
      controller.render_server_error
      expect(response_status).to eq(:internal_server_error)
      expect(response_body[:meta][:code]).to eq("SERVER_ERROR")
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

  # --- pagination: false ----------------------------------------------------

  describe "pagination: false" do
    let(:paginated) do
      double("Kaminari",
        current_page: 1, limit_value: 10, total_pages: 3,
        total_count: 25, next_page: 2, prev_page: nil
      )
    end

    it "suppresses pagination meta when pagination: false" do
      controller.render_success(data: paginated, pagination: false)
      expect(response_body[:meta]).not_to have_key(:pagination)
    end

    it "includes pagination meta when pagination: true (default)" do
      controller.render_success(data: paginated)
      expect(response_body[:meta]).to have_key(:pagination)
    end

    it "includes pagination meta when pagination: true explicitly" do
      controller.render_success(data: paginated, pagination: true)
      expect(response_body[:meta]).to have_key(:pagination)
    end

    it "render_error always suppresses pagination regardless" do
      controller.render_error(message: "Oops")
      expect(response_body[:meta]).not_to have_key(:pagination)
    end

    it "render_created suppresses pagination by default" do
      controller.render_created(data: paginated)
      expect(response_body[:meta]).not_to have_key(:pagination)
    end

    it "render_created can include pagination when explicitly requested" do
      controller.render_created(data: paginated, pagination: true)
      expect(response_body[:meta]).to have_key(:pagination)
    end
  end

  # --- 2xx helpers ----------------------------------------------------------

  describe "2xx success helpers" do
    it "#render_ok renders 200" do
      controller.render_ok(data: { id: 1 }, message: "OK")
      expect(response_status).to eq(:ok)
      expect(response_body[:success]).to eq(true)
      expect(response_body[:data]).to eq({ id: 1 })
    end

    it "#render_accepted renders 202" do
      controller.render_accepted(message: "Job queued")
      expect(response_status).to eq(:accepted)
      expect(response_body[:success]).to eq(true)
      expect(response_body[:message]).to eq("Job queued")
    end

    it "#render_partial_content renders 206" do
      controller.render_partial_content(data: [1, 2], message: "Page 1 of 5")
      expect(response_status).to eq(:partial_content)
      expect(response_body[:success]).to eq(true)
    end

    it "#render_multi_status renders 207" do
      controller.render_multi_status(data: { created: 3, failed: 1 })
      expect(response_status).to eq(:multi_status)
      expect(response_body[:success]).to eq(true)
    end
  end

  # --- 4xx helpers ----------------------------------------------------------

  describe "4xx client error helpers" do
    it "#render_bad_request renders 400 with BAD_REQUEST code" do
      controller.render_bad_request(message: "Missing param")
      expect(response_status).to eq(:bad_request)
      expect(response_body[:meta][:code]).to eq("BAD_REQUEST")
      expect(response_body[:message]).to eq("Missing param")
    end

    it "#render_bad_request accepts errors hash" do
      controller.render_bad_request(message: "Invalid", errors: { date: ["is required"] })
      expect(response_body[:errors]).to eq({ date: ["is required"] })
    end

    it "#render_payment_required renders 402" do
      controller.render_payment_required
      expect(response_status).to eq(:payment_required)
      expect(response_body[:meta][:code]).to eq("PAYMENT_REQUIRED")
    end

    it "#render_method_not_allowed renders 405" do
      controller.render_method_not_allowed
      expect(response_status).to eq(:method_not_allowed)
      expect(response_body[:meta][:code]).to eq("METHOD_NOT_ALLOWED")
    end

    it "#render_not_acceptable renders 406" do
      controller.render_not_acceptable
      expect(response_status).to eq(:not_acceptable)
      expect(response_body[:meta][:code]).to eq("NOT_ACCEPTABLE")
    end

    it "#render_request_timeout renders 408" do
      controller.render_request_timeout
      expect(response_status).to eq(:request_timeout)
      expect(response_body[:meta][:code]).to eq("REQUEST_TIMEOUT")
    end

    it "#render_conflict renders 409 with CONFLICT code" do
      controller.render_conflict(message: "Email already taken", errors: { email: ["is taken"] })
      expect(response_status).to eq(:conflict)
      expect(response_body[:meta][:code]).to eq("CONFLICT")
      expect(response_body[:errors]).to eq({ email: ["is taken"] })
    end

    it "#render_gone renders 410" do
      controller.render_gone(message: "This account has been deleted")
      expect(response_status).to eq(:gone)
      expect(response_body[:meta][:code]).to eq("GONE")
    end

    it "#render_precondition_failed renders 412" do
      controller.render_precondition_failed
      expect(response_status).to eq(:precondition_failed)
      expect(response_body[:meta][:code]).to eq("PRECONDITION_FAILED")
    end

    it "#render_unsupported_media_type renders 415" do
      controller.render_unsupported_media_type
      expect(response_status).to eq(:unsupported_media_type)
      expect(response_body[:meta][:code]).to eq("UNSUPPORTED_MEDIA_TYPE")
    end

    it "#render_unprocessable renders 422 with UNPROCESSABLE code" do
      controller.render_unprocessable(message: "Validation failed", errors: { name: ["can't be blank"] })
      expect(response_status).to eq(:unprocessable_entity)
      expect(response_body[:meta][:code]).to eq("UNPROCESSABLE_ENTITY")
      expect(response_body[:errors]).to eq({ name: ["can't be blank"] })
    end

    it "#render_locked renders 423" do
      controller.render_locked
      expect(response_status).to eq(:locked)
      expect(response_body[:meta][:code]).to eq("LOCKED")
    end

    it "#render_too_many_requests renders 429 with RATE_LIMITED code" do
      controller.render_too_many_requests
      expect(response_status).to eq(:too_many_requests)
      expect(response_body[:meta][:code]).to eq("RATE_LIMITED")
    end

    it "#render_too_many_requests accepts custom message" do
      controller.render_too_many_requests(message: "You have exceeded 100 requests per minute")
      expect(response_body[:message]).to eq("You have exceeded 100 requests per minute")
    end
  end

  # --- 5xx helpers ----------------------------------------------------------

  describe "5xx server error helpers" do
    it "#render_not_implemented renders 501" do
      controller.render_not_implemented
      expect(response_status).to eq(:not_implemented)
      expect(response_body[:meta][:code]).to eq("NOT_IMPLEMENTED")
    end

    it "#render_bad_gateway renders 502" do
      controller.render_bad_gateway
      expect(response_status).to eq(:bad_gateway)
      expect(response_body[:meta][:code]).to eq("BAD_GATEWAY")
    end

    it "#render_service_unavailable renders 503" do
      controller.render_service_unavailable
      expect(response_status).to eq(:service_unavailable)
      expect(response_body[:meta][:code]).to eq("SERVICE_UNAVAILABLE")
    end

    it "#render_gateway_timeout renders 504" do
      controller.render_gateway_timeout
      expect(response_status).to eq(:gateway_timeout)
      expect(response_body[:meta][:code]).to eq("GATEWAY_TIMEOUT")
    end

    it "#render_server_error accepts custom message" do
      controller.render_server_error(message: "Database connection failed")
      expect(response_body[:message]).to eq("Database connection failed")
      expect(response_body[:meta][:code]).to eq("SERVER_ERROR")
    end
  end

  # --- All helpers share the 4-key structure --------------------------------

  describe "structure guarantee for all helpers" do
    helpers_2xx = [
      -> (c) { c.render_ok },
      -> (c) { c.render_created },
      -> (c) { c.render_accepted },
      -> (c) { c.render_no_content },
      -> (c) { c.render_partial_content },
      -> (c) { c.render_multi_status }
    ]

    helpers_4xx = [
      -> (c) { c.render_bad_request },
      -> (c) { c.render_unauthorized },
      -> (c) { c.render_payment_required },
      -> (c) { c.render_forbidden },
      -> (c) { c.render_not_found },
      -> (c) { c.render_method_not_allowed },
      -> (c) { c.render_not_acceptable },
      -> (c) { c.render_request_timeout },
      -> (c) { c.render_conflict },
      -> (c) { c.render_gone },
      -> (c) { c.render_precondition_failed },
      -> (c) { c.render_unsupported_media_type },
      -> (c) { c.render_unprocessable },
      -> (c) { c.render_locked },
      -> (c) { c.render_too_many_requests }
    ]

    helpers_5xx = [
      -> (c) { c.render_server_error },
      -> (c) { c.render_not_implemented },
      -> (c) { c.render_bad_gateway },
      -> (c) { c.render_service_unavailable },
      -> (c) { c.render_gateway_timeout }
    ]

    (helpers_2xx + helpers_4xx + helpers_5xx).each_with_index do |helper, i|
      it "helper ##{i + 1} always returns success, message, data, meta" do
        helper.call(controller)
        %i[success message data meta].each do |key|
          expect(controller.rendered_json).to have_key(key), "helper ##{i + 1} missing key: #{key}"
        end
      end
    end
  end


end