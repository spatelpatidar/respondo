# frozen_string_literal: true

module Respondo
  # Mixed into Rails controllers to provide render_success and render_error.
  #
  # Success helpers (2xx):
  #   render_success, render_ok, render_created, render_accepted,
  #   render_non_authoritative, render_no_content, render_reset_content,
  #   render_partial_content, render_multi_status, render_already_reported,
  #   render_im_used
  #
  # Informational helpers (1xx):
  #   render_continue, render_switching_protocols, render_processing,
  #   render_early_hints
  #
  # Redirect helpers (3xx):
  #   render_multiple_choices, render_moved_permanently, render_found,
  #   render_see_other, render_not_modified, render_temporary_redirect,
  #   render_permanent_redirect
  #
  # Client error helpers (4xx):
  #   render_bad_request, render_unauthorized, render_payment_required,
  #   render_forbidden, render_not_found, render_method_not_allowed,
  #   render_not_acceptable, render_proxy_auth_required, render_request_timeout,
  #   render_conflict, render_gone, render_length_required,
  #   render_precondition_failed, render_payload_too_large, render_uri_too_long,
  #   render_unsupported_media_type, render_range_not_satisfiable,
  #   render_expectation_failed, render_im_a_teapot, render_misdirected_request,
  #   render_unprocessable, render_locked, render_failed_dependency,
  #   render_too_early, render_upgrade_required, render_precondition_required,
  #   render_too_many_requests, render_request_header_fields_too_large,
  #   render_unavailable_for_legal_reasons
  #
  # Server error helpers (5xx):
  #   render_server_error, render_not_implemented, render_bad_gateway,
  #   render_service_unavailable, render_gateway_timeout,
  #   render_http_version_not_supported, render_variant_also_negotiates,
  #   render_insufficient_storage, render_loop_detected, render_not_extended,
  #   render_network_authentication_required
  module ControllerHelpers

    # =========================================================================
    # Core DSL — all helpers delegate to these two
    # =========================================================================

    # Render a successful JSON response.
    #
    # @param data       [Object]          payload — AR model, collection, Hash, Array, nil
    # @param message    [String]          human-readable description
    # @param meta       [Hash]            extra meta fields merged into the meta block
    # @param pagination [Hash, nil]       pagination hash built by the caller, e.g.
    #                                     { current_page: 1, per_page: 25, total_pages: 4,
    #                                       total_count: 100, next_page: 2, prev_page: nil }
    #                                     Pass nil (default) to omit pagination from meta.
    # @param status     [Symbol, Integer] HTTP status (default: :ok / 200)
    def render_success(data: nil, message: nil, meta: {}, code: nil, pagination: nil, status: :ok)
      merged_meta = code ? meta.merge(code: code, status: status) : meta

      payload = ResponseBuilder.new(
        success:    true,
        data:       data,
        message:    message,
        meta:       merged_meta,
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
        request:    try(:request)
      ).build

      render json: payload, status: status
    end

    # =========================================================================
    # 1xx Informational helpers
    # NOTE: 1xx responses are protocol-level and don't carry a body in HTTP/1.1.
    # These helpers return a JSON body for API consistency / logging purposes,
    # but most HTTP clients will not receive them as normal responses.
    # =========================================================================

    # 100 Continue
    def render_continue(message: "Continue", meta: {})
      render_success(data: nil, message: message, meta: meta, code: 100, status: :continue)
    end

    # 101 Switching Protocols
    def render_switching_protocols(message: "Switching protocols", meta: {})
      render_success(data: nil, message: message, meta: meta, code: 101, status: :switching_protocols)
    end

    # 102 Processing (WebDAV)
    def render_processing(message: "Processing", meta: {})
      render_success(data: nil, message: message, meta: meta, code: 102, status: :processing)
    end

    # 103 Early Hints
    def render_early_hints(message: "Early hints", meta: {})
      render_success(data: nil, message: message, meta: meta, code: 103, status: :early_hints)
    end

    # =========================================================================
    # 2xx Success helpers
    # =========================================================================

    # 200 OK — alias for render_success with no pagination (single record)
    def render_ok(data: nil, message: nil, meta: {}, pagination: nil)
      render_success(data: data, message: message, meta: meta, pagination: pagination, code: 200, status: :ok)
    end

    # 201 Created
    def render_created(data: nil, message: "Created successfully", meta: {}, pagination: nil)
      render_success(data: data, message: message, meta: meta, pagination: pagination, code: 201, status: :created)
    end

    # 202 Accepted — async jobs, background processing
    def render_accepted(data: nil, message: "Request accepted and is being processed", meta: {}, pagination: nil)
      render_success(data: data, message: message, meta: meta, pagination: pagination, code: 202, status: :accepted)
    end

    # 203 Non-Authoritative Information — response from a third-party cache/proxy
    def render_non_authoritative(data: nil, message: "Non-authoritative information", meta: {}, pagination: nil)
      render_success(data: data, message: message, meta: meta, pagination: pagination, code: 203, status: :non_authoritative_information)
    end

    # 204 No Content — deletions, actions with no response body
    # Note: we still return our standard JSON structure for consistency
    def render_no_content(message: "Deleted successfully", meta: {}, pagination: nil)
      render_success(data: nil, message: message, meta: meta, pagination: pagination, code: 204, status: :no_content)
    end

    # 205 Reset Content — tell the client to reset the document view
    def render_reset_content(message: "Reset content", meta: {}, pagination: nil)
      render_success(data: nil, message: message, meta: meta, pagination: pagination, code: 205, status: :reset_content)
    end

    # 206 Partial Content — chunked / range responses
    def render_partial_content(data: nil, message: "Partial content returned", meta: {}, pagination: nil)
      render_success(data: data, message: message, meta: meta, pagination: pagination, code: 206, status: :partial_content)
    end

    # 207 Multi-Status (WebDAV) — batch operations with mixed results
    def render_multi_status(data: nil, message: "Multi-status response", meta: {}, pagination: nil)
      render_success(data: data, message: message, meta: meta, pagination: pagination, code: 207, status: :multi_status)
    end

    # 208 Already Reported (WebDAV) — members already enumerated
    def render_already_reported(data: nil, message: "Already reported", meta: {}, pagination: nil)
      render_success(data: data, message: message, meta: meta, pagination: pagination, code: 208, status: :already_reported)
    end

    # 226 IM Used — instance manipulations applied
    def render_im_used(data: nil, message: "IM used", meta: {}, pagination: nil)
      render_success(data: data, message: message, meta: meta, pagination: pagination, code: 226, status: :im_used)
    end

    # =========================================================================
    # 3xx Redirect helpers
    # NOTE: Pass the target URL via meta: render_moved_permanently(meta: { redirect_url: new_url })
    # =========================================================================

    # 300 Multiple Choices
    def render_multiple_choices(data: nil, message: "Multiple choices available", meta: {}, pagination: nil)
      render_success(data: data, message: message, meta: meta, pagination: pagination, code: 300, status: :multiple_choices)
    end

    # 301 Moved Permanently
    def render_moved_permanently(message: "Resource has moved permanently", meta: {}, pagination: nil)
      render_success(data: nil, message: message, meta: meta, pagination: pagination, code: 301, status: :moved_permanently)
    end

    # 302 Found (temporary redirect)
    def render_found(message: "Resource temporarily located elsewhere", meta: {}, pagination: nil)
      render_success(data: nil, message: message, meta: meta, pagination: pagination, code: 302, status: :found)
    end

    # 303 See Other — redirect to another URI with GET
    def render_see_other(message: "See other resource", meta: {}, pagination: nil)
      render_success(data: nil, message: message, meta: meta, pagination: pagination, code: 303, status: :see_other)
    end

    # 304 Not Modified — client cache is still valid
    def render_not_modified(message: "Resource not modified", meta: {}, pagination: nil)
      render_success(data: nil, message: message, meta: meta, pagination: pagination, code: 304, status: :not_modified)
    end

    # 307 Temporary Redirect — repeat request with same method to new URL
    def render_temporary_redirect(message: "Temporary redirect", meta: {}, pagination: nil)
      render_success(data: nil, message: message, meta: meta, pagination: pagination, code: 307, status: :temporary_redirect)
    end

    # 308 Permanent Redirect — like 301 but method must not change
    def render_permanent_redirect(message: "Permanent redirect", meta: {}, pagination: nil)
      render_success(data: nil, message: message, meta: meta, pagination: pagination, code: 308, status: :permanent_redirect)
    end

    # =========================================================================
    # 4xx Client error helpers
    # =========================================================================

    # 400 Bad Request — malformed request, invalid params
    def render_bad_request(message: "Bad request", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 400, status: :bad_request)
    end

    # 401 Unauthorized — not authenticated
    def render_unauthorized(message: "Unauthorized", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 401, status: :unauthorized)
    end

    # 402 Payment Required — paywalled features
    def render_payment_required(message: "Payment required to access this resource", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 402, status: :payment_required)
    end

    # 403 Forbidden — authenticated but not authorized
    def render_forbidden(message: "You do not have permission to perform this action", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 403, status: :forbidden)
    end

    # 404 Not Found
    def render_not_found(message: "Resource not found", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 404, status: :not_found)
    end

    # 405 Method Not Allowed
    def render_method_not_allowed(message: "HTTP method not allowed", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 405, status: :method_not_allowed)
    end

    # 406 Not Acceptable — client Accept header can't be satisfied
    def render_not_acceptable(message: "Requested format not acceptable", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 406, status: :not_acceptable)
    end

    # 407 Proxy Authentication Required
    def render_proxy_auth_required(message: "Proxy authentication required", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 407, status: :proxy_authentication_required)
    end

    # 408 Request Timeout
    def render_request_timeout(message: "Request timed out", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 408, status: :request_timeout)
    end

    # 409 Conflict — duplicate record, state conflict
    def render_conflict(message: "Resource conflict", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 409, status: :conflict)
    end

    # 410 Gone — resource permanently deleted
    def render_gone(message: "Resource no longer available", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 410, status: :gone)
    end

    # 411 Length Required — Content-Length header missing
    def render_length_required(message: "Content-Length header required", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 411, status: :length_required)
    end

    # 412 Precondition Failed — conditional request failed
    def render_precondition_failed(message: "Precondition failed", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 412, status: :precondition_failed)
    end

    # 413 Payload Too Large — request body exceeds server limit
    def render_payload_too_large(message: "Payload too large", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 413, status: :payload_too_large)
    end

    # 414 URI Too Long — request URI exceeds server limit
    def render_uri_too_long(message: "URI too long", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 414, status: :uri_too_long)
    end

    # 415 Unsupported Media Type — wrong Content-Type header
    def render_unsupported_media_type(message: "Unsupported media type", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 415, status: :unsupported_media_type)
    end

    # 416 Range Not Satisfiable — Range header cannot be fulfilled
    def render_range_not_satisfiable(message: "Range not satisfiable", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 416, status: :range_not_satisfiable)
    end

    # 417 Expectation Failed — Expect header cannot be met
    def render_expectation_failed(message: "Expectation failed", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 417, status: :expectation_failed)
    end

    # 418 I'm a Teapot — RFC 2324
    def render_im_a_teapot(message: "I'm a teapot", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 418, status: :im_a_teapot)
    end

    # 421 Misdirected Request — request sent to wrong server
    def render_misdirected_request(message: "Misdirected request", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 421, status: :misdirected_request)
    end

    # 422 Unprocessable Entity — validation errors (most common for APIs)
    def render_unprocessable(message: "Validation failed", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 422, status: :unprocessable_content)
    end

    # 423 Locked — resource is locked
    def render_locked(message: "Resource is locked", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 423, status: :locked)
    end

    # 424 Failed Dependency (WebDAV) — previous request failed
    def render_failed_dependency(message: "Failed dependency", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 424, status: :failed_dependency)
    end

    # 425 Too Early — server unwilling to risk processing replayed request
    def render_too_early(message: "Too early", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 425, status: :too_early)
    end

    # 426 Upgrade Required — client must switch protocols
    def render_upgrade_required(message: "Upgrade required", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 426, status: :upgrade_required)
    end

    # 428 Precondition Required — request must be conditional
    def render_precondition_required(message: "Precondition required", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 428, status: :precondition_required)
    end

    # 429 Too Many Requests — rate limiting
    def render_too_many_requests(message: "Too many requests. Please slow down.", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 429, status: :too_many_requests)
    end

    # 431 Request Header Fields Too Large
    def render_request_header_fields_too_large(message: "Request header fields too large", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 431, status: :request_header_fields_too_large)
    end

    # 451 Unavailable for Legal Reasons — censored/DMCA etc.
    def render_unavailable_for_legal_reasons(message: "Unavailable for legal reasons", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 451, status: :unavailable_for_legal_reasons)
    end

    # =========================================================================
    # 5xx Server error helpers
    # =========================================================================

    # 500 Internal Server Error
    def render_server_error(message: "An unexpected error occurred", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 500, status: :internal_server_error)
    end

    # 501 Not Implemented — feature not built yet
    def render_not_implemented(message: "This feature is not yet implemented", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 501, status: :not_implemented)
    end

    # 502 Bad Gateway — upstream service failed
    def render_bad_gateway(message: "Bad gateway — upstream service error", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 502, status: :bad_gateway)
    end

    # 503 Service Unavailable — maintenance, overloaded
    def render_service_unavailable(message: "Service temporarily unavailable", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 503, status: :service_unavailable)
    end

    # 504 Gateway Timeout — upstream service timed out
    def render_gateway_timeout(message: "Gateway timeout — upstream service did not respond", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 504, status: :gateway_timeout)
    end

    # 505 HTTP Version Not Supported
    def render_http_version_not_supported(message: "HTTP version not supported", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 505, status: :http_version_not_supported)
    end

    # 506 Variant Also Negotiates — server configuration error
    def render_variant_also_negotiates(message: "Variant also negotiates", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 506, status: :variant_also_negotiates)
    end

    # 507 Insufficient Storage (WebDAV)
    def render_insufficient_storage(message: "Insufficient storage", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 507, status: :insufficient_storage)
    end

    # 508 Loop Detected (WebDAV)
    def render_loop_detected(message: "Loop detected", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 508, status: :loop_detected)
    end

    # 510 Not Extended — further extensions needed
    def render_not_extended(message: "Not extended", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 510, status: :not_extended)
    end

    # 511 Network Authentication Required — must authenticate to access network
    def render_network_authentication_required(message: "Network authentication required", errors: nil, meta: {})
      render_error(message: message, errors: errors, meta: meta, code: 511, status: :network_authentication_required)
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
