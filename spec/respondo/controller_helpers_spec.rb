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
# Shared helper
# ---------------------------------------------------------------------------
RSpec.describe Respondo::ControllerHelpers do
  subject(:controller) { FakeController.new }

  def response_body   = controller.rendered_json
  def response_status = controller.rendered_status

  # Pagination hash the caller builds and passes in manually
  let(:pagination_hash) do
    {
      current_page: 1,
      per_page:     10,
      total_pages:  3,
      total_count:  25,
      next_page:    2,
      prev_page:    nil
    }
  end

  # =========================================================================
  # render_success (core)
  # =========================================================================

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

    it "includes pagination in meta when a pagination hash is passed" do
      controller.render_success(pagination: pagination_hash)
      expect(response_body[:meta][:pagination]).to eq(pagination_hash)
    end

    it "omits pagination from meta when no pagination hash is passed" do
      controller.render_success(data: { id: 1 })
      expect(response_body[:meta]).not_to have_key(:pagination)
    end

    it "omits pagination from meta when pagination: nil explicitly" do
      controller.render_success(pagination: nil)
      expect(response_body[:meta]).not_to have_key(:pagination)
    end

    it "accepts extra meta" do
      controller.render_success(meta: { version: "v1" })
      expect(response_body[:meta][:version]).to eq("v1")
    end

    it "always includes timestamp in meta" do
      controller.render_success
      expect(response_body[:meta]).to have_key(:timestamp)
    end

    it "includes code and status in meta when code is given" do
      controller.render_success(code: 200, status: :ok)
      expect(response_body[:meta][:code]).to   eq(200)
      expect(response_body[:meta][:status]).to eq(:ok)
    end
  end

  # =========================================================================
  # render_error (core)
  # =========================================================================

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

    it "never includes pagination in meta" do
      controller.render_error(message: "Oops")
      expect(response_body[:meta]).not_to have_key(:pagination)
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

  # =========================================================================
  # 1xx — Informational helpers
  # =========================================================================

  describe "1xx informational helpers" do
    describe "#render_continue" do
      it "renders success: true with code 100" do
        controller.render_continue
        expect(response_body[:success]).to      eq(true)
        expect(response_body[:meta][:code]).to  eq(100)
      end

      it "accepts a custom message" do
        controller.render_continue(message: "Keep going")
        expect(response_body[:message]).to eq("Keep going")
      end
    end

    describe "#render_switching_protocols" do
      it "renders success: true with code 101" do
        controller.render_switching_protocols
        expect(response_body[:success]).to      eq(true)
        expect(response_body[:meta][:code]).to  eq(101)
      end
    end

    describe "#render_processing" do
      it "renders success: true with code 102" do
        controller.render_processing
        expect(response_body[:success]).to      eq(true)
        expect(response_body[:meta][:code]).to  eq(102)
      end
    end

    describe "#render_early_hints" do
      it "renders success: true with code 103" do
        controller.render_early_hints
        expect(response_body[:success]).to      eq(true)
        expect(response_body[:meta][:code]).to  eq(103)
      end

      it "accepts extra meta for link headers" do
        controller.render_early_hints(meta: { link: "</style.css>; rel=preload" })
        expect(response_body[:meta][:link]).to eq("</style.css>; rel=preload")
      end
    end
  end

  # =========================================================================
  # 2xx — Success helpers
  # =========================================================================

  describe "2xx success helpers" do
    describe "#render_ok" do
      it "renders 200 with data" do
        controller.render_ok(data: { id: 1 }, message: "OK")
        expect(response_status).to             eq(:ok)
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:data]).to        eq({ id: 1 })
        expect(response_body[:meta][:code]).to eq(200)
      end

      it "includes pagination meta when pagination hash is passed" do
        controller.render_ok(data: [{ id: 1 }], pagination: pagination_hash)
        expect(response_body[:meta][:pagination]).to eq(pagination_hash)
      end

      it "omits pagination meta when no pagination hash is passed" do
        controller.render_ok(data: { id: 1 })
        expect(response_body[:meta]).not_to have_key(:pagination)
      end
    end

    describe "#render_created" do
      it "renders 201 with data" do
        controller.render_created(data: { id: 42 }, message: "User created")
        expect(response_status).to             eq(:created)
        expect(response_body[:data]).to        eq({ id: 42 })
        expect(response_body[:message]).to     eq("User created")
        expect(response_body[:meta][:code]).to eq(201)
      end

      it "uses default message" do
        controller.render_created
        expect(response_body[:message]).to eq("Created successfully")
      end

      it "can include pagination when passed" do
        controller.render_created(data: { id: 1 }, pagination: pagination_hash)
        expect(response_body[:meta][:pagination]).to eq(pagination_hash)
      end
    end

    describe "#render_accepted" do
      it "renders 202" do
        controller.render_accepted(message: "Job queued")
        expect(response_status).to             eq(:accepted)
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:message]).to     eq("Job queued")
        expect(response_body[:meta][:code]).to eq(202)
      end

      it "accepts data payload" do
        controller.render_accepted(data: { job_id: "abc123" })
        expect(response_body[:data]).to eq({ job_id: "abc123" })
      end
    end

    describe "#render_non_authoritative" do
      it "renders 203" do
        controller.render_non_authoritative(data: { id: 1 })
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:meta][:code]).to eq(203)
        expect(response_body[:data]).to        eq({ id: 1 })
      end

      it "accepts custom message" do
        controller.render_non_authoritative(message: "Data from cache")
        expect(response_body[:message]).to eq("Data from cache")
      end
    end

    describe "#render_no_content" do
      it "renders with nil data and success: true" do
        controller.render_no_content
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:data]).to        be_nil
        expect(response_body[:meta][:code]).to eq(204)
      end

      it "accepts a custom message" do
        controller.render_no_content(message: "Account deactivated")
        expect(response_body[:message]).to eq("Account deactivated")
      end
    end

    describe "#render_reset_content" do
      it "renders 205 with success: true and nil data" do
        controller.render_reset_content
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:data]).to        be_nil
        expect(response_body[:meta][:code]).to eq(205)
      end

      it "accepts a custom message" do
        controller.render_reset_content(message: "Form cleared")
        expect(response_body[:message]).to eq("Form cleared")
      end
    end

    describe "#render_partial_content" do
      it "renders 206" do
        controller.render_partial_content(data: [1, 2], message: "Page 1 of 5")
        expect(response_status).to             eq(:partial_content)
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:meta][:code]).to eq(206)
      end
    end

    describe "#render_multi_status" do
      it "renders 207" do
        controller.render_multi_status(data: { created: 3, failed: 1 })
        expect(response_status).to             eq(:multi_status)
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:meta][:code]).to eq(207)
      end
    end

    describe "#render_already_reported" do
      it "renders 208" do
        controller.render_already_reported(data: { id: 1 })
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:meta][:code]).to eq(208)
        expect(response_body[:data]).to        eq({ id: 1 })
      end
    end

    describe "#render_im_used" do
      it "renders 226" do
        controller.render_im_used(data: { id: 1 })
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:meta][:code]).to eq(226)
      end
    end
  end

  # =========================================================================
  # 3xx — Redirect helpers
  # =========================================================================

  describe "3xx redirect helpers" do
    describe "#render_multiple_choices" do
      it "renders 300 with success: true" do
        controller.render_multiple_choices
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:meta][:code]).to eq(300)
      end

      it "accepts data listing available representations" do
        choices = [{ format: "json", url: "/r.json" }, { format: "xml", url: "/r.xml" }]
        controller.render_multiple_choices(data: choices)
        expect(response_body[:data]).to eq(choices)
      end
    end

    describe "#render_moved_permanently" do
      it "renders 301 with success: true" do
        controller.render_moved_permanently
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:meta][:code]).to eq(301)
      end

      it "accepts redirect_url in meta" do
        controller.render_moved_permanently(meta: { redirect_url: "https://example.com/new" })
        expect(response_body[:meta][:redirect_url]).to eq("https://example.com/new")
      end
    end

    describe "#render_found" do
      it "renders 302 with success: true" do
        controller.render_found
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:meta][:code]).to eq(302)
      end

      it "accepts redirect_url in meta" do
        controller.render_found(meta: { redirect_url: "https://example.com/temp" })
        expect(response_body[:meta][:redirect_url]).to eq("https://example.com/temp")
      end
    end

    describe "#render_see_other" do
      it "renders 303 with success: true" do
        controller.render_see_other
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:meta][:code]).to eq(303)
      end
    end

    describe "#render_not_modified" do
      it "renders 304 with success: true and nil data" do
        controller.render_not_modified
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:data]).to        be_nil
        expect(response_body[:meta][:code]).to eq(304)
      end
    end

    describe "#render_temporary_redirect" do
      it "renders 307 with success: true" do
        controller.render_temporary_redirect
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:meta][:code]).to eq(307)
      end
    end

    describe "#render_permanent_redirect" do
      it "renders 308 with success: true" do
        controller.render_permanent_redirect
        expect(response_body[:success]).to     eq(true)
        expect(response_body[:meta][:code]).to eq(308)
      end
    end
  end

  # =========================================================================
  # 4xx — Client error helpers
  # =========================================================================

  describe "4xx client error helpers" do
    describe "#render_bad_request" do
      it "renders 400" do
        controller.render_bad_request(message: "Missing param")
        expect(response_status).to             eq(:bad_request)
        expect(response_body[:meta][:code]).to eq(400)
        expect(response_body[:message]).to     eq("Missing param")
      end

      it "accepts errors hash" do
        controller.render_bad_request(errors: { date: ["is required"] })
        expect(response_body[:errors]).to eq({ date: ["is required"] })
      end
    end

    describe "#render_unauthorized" do
      it "renders 401" do
        controller.render_unauthorized
        expect(response_status).to             eq(:unauthorized)
        expect(response_body[:meta][:code]).to eq(401)
      end

      it "accepts custom message" do
        controller.render_unauthorized(message: "Token expired")
        expect(response_body[:message]).to eq("Token expired")
      end
    end

    describe "#render_payment_required" do
      it "renders 402" do
        controller.render_payment_required
        expect(response_status).to             eq(:payment_required)
        expect(response_body[:meta][:code]).to eq(402)
      end
    end

    describe "#render_forbidden" do
      it "renders 403" do
        controller.render_forbidden
        expect(response_status).to             eq(:forbidden)
        expect(response_body[:meta][:code]).to eq(403)
      end
    end

    describe "#render_not_found" do
      it "renders 404" do
        controller.render_not_found
        expect(response_status).to             eq(:not_found)
        expect(response_body[:meta][:code]).to eq(404)
      end
    end

    describe "#render_method_not_allowed" do
      it "renders 405" do
        controller.render_method_not_allowed
        expect(response_status).to             eq(:method_not_allowed)
        expect(response_body[:meta][:code]).to eq(405)
      end
    end

    describe "#render_not_acceptable" do
      it "renders 406" do
        controller.render_not_acceptable
        expect(response_status).to             eq(:not_acceptable)
        expect(response_body[:meta][:code]).to eq(406)
      end
    end

    describe "#render_proxy_auth_required" do
      it "renders 407" do
        controller.render_proxy_auth_required
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(407)
      end

      it "accepts custom message" do
        controller.render_proxy_auth_required(message: "Authenticate with the proxy first")
        expect(response_body[:message]).to eq("Authenticate with the proxy first")
      end
    end

    describe "#render_request_timeout" do
      it "renders 408" do
        controller.render_request_timeout
        expect(response_status).to             eq(:request_timeout)
        expect(response_body[:meta][:code]).to eq(408)
      end
    end

    describe "#render_conflict" do
      it "renders 409 with errors" do
        controller.render_conflict(message: "Email already taken", errors: { email: ["is taken"] })
        expect(response_status).to             eq(:conflict)
        expect(response_body[:meta][:code]).to eq(409)
        expect(response_body[:errors]).to      eq({ email: ["is taken"] })
      end
    end

    describe "#render_gone" do
      it "renders 410" do
        controller.render_gone(message: "This account has been deleted")
        expect(response_status).to             eq(:gone)
        expect(response_body[:meta][:code]).to eq(410)
      end
    end

    describe "#render_length_required" do
      it "renders 411" do
        controller.render_length_required
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(411)
      end

      it "accepts custom message" do
        controller.render_length_required(message: "Content-Length header is required")
        expect(response_body[:message]).to eq("Content-Length header is required")
      end
    end

    describe "#render_precondition_failed" do
      it "renders 412" do
        controller.render_precondition_failed
        expect(response_status).to             eq(:precondition_failed)
        expect(response_body[:meta][:code]).to eq(412)
      end
    end

    describe "#render_payload_too_large" do
      it "renders 413" do
        controller.render_payload_too_large
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(413)
      end

      it "accepts custom message" do
        controller.render_payload_too_large(message: "File exceeds the 10 MB limit")
        expect(response_body[:message]).to eq("File exceeds the 10 MB limit")
      end
    end

    describe "#render_uri_too_long" do
      it "renders 414" do
        controller.render_uri_too_long
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(414)
      end
    end

    describe "#render_unsupported_media_type" do
      it "renders 415" do
        controller.render_unsupported_media_type
        expect(response_status).to             eq(:unsupported_media_type)
        expect(response_body[:meta][:code]).to eq(415)
      end
    end

    describe "#render_range_not_satisfiable" do
      it "renders 416" do
        controller.render_range_not_satisfiable
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(416)
      end

      it "accepts custom message" do
        controller.render_range_not_satisfiable(message: "Requested byte range is out of bounds")
        expect(response_body[:message]).to eq("Requested byte range is out of bounds")
      end
    end

    describe "#render_expectation_failed" do
      it "renders 417" do
        controller.render_expectation_failed
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(417)
      end
    end

    describe "#render_im_a_teapot" do
      it "renders 418" do
        controller.render_im_a_teapot
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(418)
      end

      it "accepts custom message" do
        controller.render_im_a_teapot(message: "I'm a teapot — I cannot brew coffee")
        expect(response_body[:message]).to eq("I'm a teapot — I cannot brew coffee")
      end
    end

    describe "#render_misdirected_request" do
      it "renders 421" do
        controller.render_misdirected_request
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(421)
      end
    end

    describe "#render_unprocessable" do
      it "renders 422 with errors" do
        controller.render_unprocessable(message: "Validation failed", errors: { name: ["can't be blank"] })
        expect(response_status).to             eq(:unprocessable_content)
        expect(response_body[:meta][:code]).to eq(422)
        expect(response_body[:errors]).to      eq({ name: ["can't be blank"] })
      end
    end

    describe "#render_locked" do
      it "renders 423" do
        controller.render_locked
        expect(response_status).to             eq(:locked)
        expect(response_body[:meta][:code]).to eq(423)
      end
    end

    describe "#render_failed_dependency" do
      it "renders 424" do
        controller.render_failed_dependency
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(424)
      end

      it "accepts custom message" do
        controller.render_failed_dependency(message: "Prerequisite resource creation failed")
        expect(response_body[:message]).to eq("Prerequisite resource creation failed")
      end
    end

    describe "#render_too_early" do
      it "renders 425" do
        controller.render_too_early
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(425)
      end
    end

    describe "#render_upgrade_required" do
      it "renders 426" do
        controller.render_upgrade_required
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(426)
      end

      it "accepts custom message" do
        controller.render_upgrade_required(message: "Please upgrade to TLS 1.3")
        expect(response_body[:message]).to eq("Please upgrade to TLS 1.3")
      end
    end

    describe "#render_precondition_required" do
      it "renders 428" do
        controller.render_precondition_required
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(428)
      end
    end

    describe "#render_too_many_requests" do
      it "renders 429" do
        controller.render_too_many_requests
        expect(response_status).to             eq(:too_many_requests)
        expect(response_body[:meta][:code]).to eq(429)
      end

      it "accepts custom message" do
        controller.render_too_many_requests(message: "You have exceeded 100 requests per minute")
        expect(response_body[:message]).to eq("You have exceeded 100 requests per minute")
      end

      it "accepts retry_after in meta" do
        controller.render_too_many_requests(meta: { retry_after: 60 })
        expect(response_body[:meta][:retry_after]).to eq(60)
      end
    end

    describe "#render_request_header_fields_too_large" do
      it "renders 431" do
        controller.render_request_header_fields_too_large
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(431)
      end

      it "accepts custom message" do
        controller.render_request_header_fields_too_large(message: "Cookie header is too large")
        expect(response_body[:message]).to eq("Cookie header is too large")
      end
    end

    describe "#render_unavailable_for_legal_reasons" do
      it "renders 451" do
        controller.render_unavailable_for_legal_reasons
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(451)
      end

      it "accepts custom message and meta" do
        controller.render_unavailable_for_legal_reasons(
          message: "Blocked in your region",
          meta:    { blocked_by: "DMCA" }
        )
        expect(response_body[:message]).to          eq("Blocked in your region")
        expect(response_body[:meta][:blocked_by]).to eq("DMCA")
      end
    end
  end

  # =========================================================================
  # 5xx — Server error helpers
  # =========================================================================

  describe "5xx server error helpers" do
    describe "#render_server_error" do
      it "renders 500" do
        controller.render_server_error
        expect(response_status).to             eq(:internal_server_error)
        expect(response_body[:meta][:code]).to eq(500)
      end

      it "accepts custom message" do
        controller.render_server_error(message: "Database connection failed")
        expect(response_body[:message]).to     eq("Database connection failed")
        expect(response_body[:meta][:code]).to eq(500)
      end
    end

    describe "#render_not_implemented" do
      it "renders 501" do
        controller.render_not_implemented
        expect(response_status).to             eq(:not_implemented)
        expect(response_body[:meta][:code]).to eq(501)
      end
    end

    describe "#render_bad_gateway" do
      it "renders 502" do
        controller.render_bad_gateway
        expect(response_status).to             eq(:bad_gateway)
        expect(response_body[:meta][:code]).to eq(502)
      end
    end

    describe "#render_service_unavailable" do
      it "renders 503" do
        controller.render_service_unavailable
        expect(response_status).to             eq(:service_unavailable)
        expect(response_body[:meta][:code]).to eq(503)
      end

      it "accepts retry_after in meta" do
        controller.render_service_unavailable(meta: { retry_after: 1800 })
        expect(response_body[:meta][:retry_after]).to eq(1800)
      end
    end

    describe "#render_gateway_timeout" do
      it "renders 504" do
        controller.render_gateway_timeout
        expect(response_status).to             eq(:gateway_timeout)
        expect(response_body[:meta][:code]).to eq(504)
      end
    end

    describe "#render_http_version_not_supported" do
      it "renders 505" do
        controller.render_http_version_not_supported
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(505)
      end

      it "accepts custom message" do
        controller.render_http_version_not_supported(message: "Only HTTP/1.1 and HTTP/2 supported")
        expect(response_body[:message]).to eq("Only HTTP/1.1 and HTTP/2 supported")
      end
    end

    describe "#render_variant_also_negotiates" do
      it "renders 506" do
        controller.render_variant_also_negotiates
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(506)
      end
    end

    describe "#render_insufficient_storage" do
      it "renders 507" do
        controller.render_insufficient_storage
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(507)
      end

      it "accepts custom message" do
        controller.render_insufficient_storage(message: "Disk quota exceeded")
        expect(response_body[:message]).to eq("Disk quota exceeded")
      end
    end

    describe "#render_loop_detected" do
      it "renders 508" do
        controller.render_loop_detected
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(508)
      end
    end

    describe "#render_not_extended" do
      it "renders 510" do
        controller.render_not_extended
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(510)
      end
    end

    describe "#render_network_authentication_required" do
      it "renders 511" do
        controller.render_network_authentication_required
        expect(response_body[:success]).to     eq(false)
        expect(response_body[:meta][:code]).to eq(511)
      end

      it "accepts custom message" do
        controller.render_network_authentication_required(message: "Sign in to the network portal first")
        expect(response_body[:message]).to eq("Sign in to the network portal first")
      end
    end
  end

  # =========================================================================
  # Pagination — hash-based (new API)
  # =========================================================================

  describe "pagination hash in meta" do
    it "appears in meta when a valid hash is passed" do
      controller.render_ok(data: [{ id: 1 }], pagination: pagination_hash)
      expect(response_body[:meta][:pagination]).to eq(pagination_hash)
    end

    it "is absent when pagination is nil (default)" do
      controller.render_ok(data: { id: 1 })
      expect(response_body[:meta]).not_to have_key(:pagination)
    end

    it "is absent when an empty hash is passed" do
      controller.render_ok(data: { id: 1 }, pagination: {})
      expect(response_body[:meta]).not_to have_key(:pagination)
    end

    it "is absent on error responses" do
      controller.render_unprocessable(message: "Bad input")
      expect(response_body[:meta]).not_to have_key(:pagination)
    end

    it "is present on render_created when pagination is passed" do
      controller.render_created(data: { id: 1 }, pagination: pagination_hash)
      expect(response_body[:meta][:pagination]).to eq(pagination_hash)
    end

    it "is present on render_accepted when pagination is passed" do
      controller.render_accepted(data: [{ id: 1 }], pagination: pagination_hash)
      expect(response_body[:meta][:pagination]).to eq(pagination_hash)
    end

    it "pagination keys are camelized when camelize_keys is true" do
      Respondo.configure { |c| c.camelize_keys = true }
      controller.render_ok(data: { id: 1 }, pagination: pagination_hash)
      pag = response_body[:meta][:pagination]
      expect(pag).to have_key(:currentPage)
      expect(pag).to have_key(:totalCount)
      expect(pag).to have_key(:nextPage)
      expect(pag).to have_key(:prevPage)
      expect(pag).to have_key(:totalPages)
      expect(pag).to have_key(:perPage)
    ensure
      Respondo.reset!
    end
  end

  # =========================================================================
  # Response shape guarantee — ALL 57 helpers
  # =========================================================================

  describe "response shape guarantee — every helper returns success, message, data, meta" do
    all_helpers = [
      # 1xx
      ->(c) { c.render_continue },
      ->(c) { c.render_switching_protocols },
      ->(c) { c.render_processing },
      ->(c) { c.render_early_hints },
      # 2xx
      ->(c) { c.render_ok },
      ->(c) { c.render_created },
      ->(c) { c.render_accepted },
      ->(c) { c.render_non_authoritative },
      ->(c) { c.render_no_content },
      ->(c) { c.render_reset_content },
      ->(c) { c.render_partial_content },
      ->(c) { c.render_multi_status },
      ->(c) { c.render_already_reported },
      ->(c) { c.render_im_used },
      # 3xx
      ->(c) { c.render_multiple_choices },
      ->(c) { c.render_moved_permanently },
      ->(c) { c.render_found },
      ->(c) { c.render_see_other },
      ->(c) { c.render_not_modified },
      ->(c) { c.render_temporary_redirect },
      ->(c) { c.render_permanent_redirect },
      # 4xx
      ->(c) { c.render_bad_request },
      ->(c) { c.render_unauthorized },
      ->(c) { c.render_payment_required },
      ->(c) { c.render_forbidden },
      ->(c) { c.render_not_found },
      ->(c) { c.render_method_not_allowed },
      ->(c) { c.render_not_acceptable },
      ->(c) { c.render_proxy_auth_required },
      ->(c) { c.render_request_timeout },
      ->(c) { c.render_conflict },
      ->(c) { c.render_gone },
      ->(c) { c.render_length_required },
      ->(c) { c.render_precondition_failed },
      ->(c) { c.render_payload_too_large },
      ->(c) { c.render_uri_too_long },
      ->(c) { c.render_unsupported_media_type },
      ->(c) { c.render_range_not_satisfiable },
      ->(c) { c.render_expectation_failed },
      ->(c) { c.render_im_a_teapot },
      ->(c) { c.render_misdirected_request },
      ->(c) { c.render_unprocessable },
      ->(c) { c.render_locked },
      ->(c) { c.render_failed_dependency },
      ->(c) { c.render_too_early },
      ->(c) { c.render_upgrade_required },
      ->(c) { c.render_precondition_required },
      ->(c) { c.render_too_many_requests },
      ->(c) { c.render_request_header_fields_too_large },
      ->(c) { c.render_unavailable_for_legal_reasons },
      # 5xx
      ->(c) { c.render_server_error },
      ->(c) { c.render_not_implemented },
      ->(c) { c.render_bad_gateway },
      ->(c) { c.render_service_unavailable },
      ->(c) { c.render_gateway_timeout },
      ->(c) { c.render_http_version_not_supported },
      ->(c) { c.render_variant_also_negotiates },
      ->(c) { c.render_insufficient_storage },
      ->(c) { c.render_loop_detected },
      ->(c) { c.render_not_extended },
      ->(c) { c.render_network_authentication_required },
    ]

    all_helpers.each_with_index do |helper, i|
      it "helper ##{i + 1} (#{helper.source_location&.last || i + 1}) returns success, message, data, meta" do
        helper.call(controller)
        %i[success message data meta].each do |key|
          expect(controller.rendered_json).to have_key(key), "helper ##{i + 1} missing key :#{key}"
        end
      end
    end
  end

end