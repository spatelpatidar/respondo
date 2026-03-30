# frozen_string_literal: true

module Respondo
  # Mixed into Rails controllers to provide render_success and render_error.
  #
  # Success helpers (2xx):
  #   render_success, render_created, render_accepted, render_no_content,
  #   render_partial_content, render_multi_status
  #
  # Client error helpers (4xx):
  #   render_bad_request, render_unauthorized, render_payment_required,
  #   render_forbidden, render_not_found, render_method_not_allowed,
  #   render_not_acceptable, render_conflict, render_gone,
  #   render_unprocessable, render_too_many_requests, render_locked,
  #   render_precondition_failed, render_unsupported_media_type,
  #   render_request_timeout
  #
  # Server error helpers (5xx):
  #   render_server_error, render_not_implemented, render_bad_gateway,
  #   render_service_unavailable, render_gateway_timeout
  module ControllerHelpers

    # =========================================================================
    # Core DSL — all helpers delegate to these two
    # =========================================================================

    # Render a successful JSON response.
    #
    # @param data       [Object]          payload — AR model, collection, Hash, Array, nil
    # @param message    [String]          human-readable description
    # @param meta       [Hash]            extra meta fields merged into the meta block
    # @param pagy       [Pagy]            optional Pagy object (pass when using Pagy backend)
    # @param pagination [Boolean]         true  = include pagination meta when available (default)
    #                                     false = always suppress pagination meta
    # @param status     [Symbol, Integer] HTTP status (default: :ok / 200)
    def render_success(data: nil, message: nil, meta: {}, code: nil, pagy: nil, pagination: true, status: :ok)
      merged_meta  = code ? meta.merge(code: code, status: status) : meta

      payload = ResponseBuilder.new(
        success:    true,
        data:       data,
        message:    message,
        meta:       merged_meta,
        pagy:       pagy,
        pagination: pagination,
        request:    try(:request)
      ).build

      render json: payload, status: status
    end

    # Render an error JSON response.
    #
    # @param message [String]                      human-readable error description
    # @param errors  [Hash, ActiveModel::Errors]   field-level validation errors
    # @param code    [String, nil]                 machine-readable error code e.g. "AUTH_EXPIRED"
    # @param meta    [Hash]                        extra meta fields
    # @param status  [Symbol, Integer]             HTTP status (default: :unprocessable_entity / 422)

    def render_error(message: nil, errors: nil, code: nil, meta: {}, status: :unprocessable_entity)
      extracted_errors = extract_errors(errors)
      merged_meta      = code ? meta.merge(code: code, status: status) : meta

      payload = ResponseBuilder.new(
        success:    false,
        data:       nil,
        message:    message,
        meta:       merged_meta,
        errors:     extracted_errors,
        pagination: false,
        request:    try(:request)
      ).build

      render json: payload, status: status
    end

    # =========================================================================
    # 2xx Success helpers
    # =========================================================================

    # 200 OK — alias for render_success with no pagination (single record)
    def render_ok(data: nil, message: nil, meta: {}, pagination: true)
      render_success(data: data, message: message, meta: meta, pagination: pagination, code:200, status: :ok)
    end

    # 201 Created
    def render_created(data: nil, message: "Created successfully", pagination: false)
      render_success(data: data, message: message, pagination: pagination, code:201, status: :created)
    end

    # 202 Accepted — async jobs, background processing
    def render_accepted(data: nil, message: "Request accepted and is being processed")
      render_success(data: data, message: message, pagination: false, code:202, status: :accepted)
    end

    # 204 No Content — deletions, actions with no response body
    # Note: we still return our standard JSON structure for consistency
    def render_no_content(message: "Deleted successfully")
      render_success(data: nil, message: message, pagination: false, code:204, status: :ok)
    end

    # 206 Partial Content — chunked / range responses
    def render_partial_content(data: nil, message: "Partial content returned", meta: {})
      render_success(data: data, message: message, meta: meta, pagination: false, code:206, status: :partial_content)
    end

    # 207 Multi-Status — batch operations with mixed results
    def render_multi_status(data: nil, message: "Multi-status response", meta: {})
      render_success(data: data, message: message, meta: meta, pagination: false, code:207, status: :multi_status)
    end

    # =========================================================================
    # 4xx Client error helpers
    # =========================================================================

    # 400 Bad Request — malformed request, invalid params
    def render_bad_request(message: "Bad request", errors: nil, code: "BAD_REQUEST")
      render_error(message: message, errors: errors, code: code, status: :bad_request)
    end

    # 401 Unauthorized — not authenticated
    def render_unauthorized(message: "Unauthorized", errors: nil, code: "UNAUTHORIZED")
      render_error(message: message, errors: errors, code: code, status: :unauthorized)
    end

    # 402 Payment Required — paywalled features
    def render_payment_required(message: "Payment required to access this resource", errors: nil, code: "PAYMENT_REQUIRED")
      render_error(message: message, errors: errors, code: code, status: :payment_required)
    end

    # 403 Forbidden — authenticated but not authorized
    def render_forbidden(message: "You do not have permission to perform this action", errors: nil, code: "FORBIDDEN")
      render_error(message: message, errors: errors, code: code, status: :forbidden)
    end

    # 404 Not Found
    def render_not_found(message: "Resource not found", errors: nil, code: "NOT_FOUND")
      render_error(message: message, errors: errors, code: code, status: :not_found)
    end

    # 405 Method Not Allowed
    def render_method_not_allowed(message: "HTTP method not allowed", errors: nil, code: "METHOD_NOT_ALLOWED")
      render_error(message: message, errors: errors, code: code, status: :method_not_allowed)
    end

    # 406 Not Acceptable — client Accept header can't be satisfied
    def render_not_acceptable(message: "Requested format not acceptable", errors: nil, code: "NOT_ACCEPTABLE")
      render_error(message: message, errors: errors, code: code, status: :not_acceptable)
    end

    # 408 Request Timeout
    def render_request_timeout(message: "Request timed out", errors: nil, code: "REQUEST_TIMEOUT")
      render_error(message: message, errors: errors, code: code, status: :request_timeout)
    end

    # 409 Conflict — duplicate record, state conflict
    def render_conflict(message: "Resource conflict", errors: nil, code: "CONFLICT")
      render_error(message: message, errors: errors, code: code, status: :conflict)
    end

    # 410 Gone — resource permanently deleted
    def render_gone(message: "Resource no longer available", errors: nil, code: "GONE")
      render_error(message: message, errors: errors, code: code, status: :gone)
    end

    # 412 Precondition Failed — conditional request failed
    def render_precondition_failed(message: "Precondition failed", errors: nil, code: "PRECONDITION_FAILED")
      render_error(message: message, errors: errors, code: code, status: :precondition_failed)
    end

    # 415 Unsupported Media Type — wrong Content-Type header
    def render_unsupported_media_type(message: "Unsupported media type", errors: nil, code: "UNSUPPORTED_MEDIA_TYPE")
      render_error(message: message, errors: errors, code: code, status: :unsupported_media_type)
    end

    # 422 Unprocessable Entity — validation errors (most common for APIs)
    def render_unprocessable(message: "Validation failed", errors: nil, code: "UNPROCESSABLE_ENTITY")
      render_error(message: message, errors: errors, code: code, status: :unprocessable_entity)
    end

    # 423 Locked — resource is locked
    def render_locked(message: "Resource is locked", errors: nil, code: "LOCKED")
      render_error(message: message, errors: errors, code: code, status: :locked)
    end

    # 429 Too Many Requests — rate limiting
    def render_too_many_requests(message: "Too many requests. Please slow down.", errors: nil, code: "RATE_LIMITED")
      render_error(message: message, errors: errors, code: code, status: :too_many_requests)
    end

    # =========================================================================
    # 5xx Server error helpers
    # =========================================================================

    # 500 Internal Server Error
    def render_server_error(message: "An unexpected error occurred", errors: nil, code: "SERVER_ERROR")
      render_error(message: message, errors: errors, code: code, status: :internal_server_error)
    end

    # 501 Not Implemented — feature not built yet
    def render_not_implemented(message: "This feature is not yet implemented", errors: nil, code: "NOT_IMPLEMENTED")
      render_error(message: message, errors: errors, code: code, status: :not_implemented)
    end

    # 502 Bad Gateway — upstream service failed
    def render_bad_gateway(message: "Bad gateway — upstream service error", errors: nil, code: "BAD_GATEWAY")
      render_error(message: message, errors: errors, code: code, status: :bad_gateway)
    end

    # 503 Service Unavailable — maintenance, overloaded
    def render_service_unavailable(message: "Service temporarily unavailable", errors: nil, code: "SERVICE_UNAVAILABLE")
      render_error(message: message, errors: errors, code: code, status: :service_unavailable)
    end

    # 504 Gateway Timeout — upstream service timed out
    def render_gateway_timeout(message: "Gateway timeout — upstream service did not respond", errors: nil, code: "GATEWAY_TIMEOUT")
      render_error(message: message, errors: errors, code: code, status: :gateway_timeout)
    end

    private

    # Normalize errors into a plain Hash regardless of source type.
    def extract_errors(errors)
      return nil if errors.nil?

      if defined?(ActiveModel::Errors) && errors.is_a?(ActiveModel::Errors)
        return errors.to_hash
      end

      return errors if errors.is_a?(Hash)

      if errors.is_a?(Array)
        return { base: errors }
      end

      if errors.is_a?(String)
        return { base: [errors] }
      end

      nil
    end
  end
end
