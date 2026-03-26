# frozen_string_literal: true

require "time"

module Respondo
  # Builds the standardized response hash.
  #
  # Every response always contains these top-level keys:
  #   {
  #     success: Boolean,
  #     message: String,
  #     data:    Object | Array | nil,
  #     meta:    Hash
  #   }
  #
  # The meta block always contains:
  #   { timestamp: ISO8601 String }
  # Plus pagination keys when pagination: true and the data is a paginated collection.
  # Plus request_id when config.include_request_id is true.
  class ResponseBuilder
    # @param success    [Boolean]
    # @param data       [Object]   anything — serialized automatically
    # @param message    [String]
    # @param meta       [Hash]     caller-supplied extra meta (merged in)
    # @param errors     [Hash]     field-level errors (for 422 responses)
    # @param pagy       [Pagy]     optional Pagy object for pagination meta
    # @param pagination [Boolean]  true = include pagination meta (default),
    #                              false = always suppress pagination meta
    # @param request    [Object]   ActionDispatch::Request (for request_id)
    def initialize(success:, data: nil, message: nil, meta: {}, errors: nil,
                   pagy: nil, pagination: true, request: nil)
      @success    = success
      @raw_data   = data
      @message    = message
      @extra_meta = meta || {}
      @errors     = errors
      @pagy       = pagy
      @pagination = pagination
      @request    = request
    end

    # @return [Hash] the complete response payload
    def build
      payload = {
        success: @success,
        message: resolve_message,
        data:    serialize_data,
        meta:    build_meta
      }

      payload[:errors] = @errors if @errors && !@errors.empty?

      apply_camelize(payload)
    end

    private

    def resolve_message
      return @message if @message && !@message.empty?
      @success ? Respondo.config.default_success_message : Respondo.config.default_error_message
    end

    def serialize_data
      Serializer.call(@raw_data)
    end

    def build_meta
      meta = { timestamp: current_timestamp }

      # Only extract pagination when caller has not explicitly disabled it
      if @pagination
        pagination = if @pagy
          Pagination.extract(@pagy)
        else
          Pagination.extract(@raw_data)
        end
        meta[:pagination] = pagination if pagination
      end

      # Request ID (Rails only, opt-in via config)
      if Respondo.config.include_request_id && @request&.respond_to?(:request_id)
        meta[:request_id] = @request.request_id
      end

      # Merge any caller-supplied meta last (allows overriding)
      meta.merge(@extra_meta)
    end

    def current_timestamp
      if defined?(Time.current)
        Time.current.iso8601
      else
        Time.now.utc.iso8601
      end
    end

    def apply_camelize(hash)
      return hash unless Respondo.config.camelize_keys
      camelize_hash(hash)
    end

    def camelize_hash(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), memo|
          memo[camelize_key(k)] = camelize_hash(v)
        end
      when Array
        obj.map { |item| camelize_hash(item) }
      else
        obj
      end
    end

    def camelize_key(key)
      key.to_s.gsub(/_([a-z])/) { $1.upcase }.to_sym
    end
  end
end
