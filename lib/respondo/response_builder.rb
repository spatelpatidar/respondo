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
  # Plus pagination when a pagination hash is supplied by the caller.
  class ResponseBuilder
    # @param success    [Boolean]
    # @param data       [Object]   anything — serialized automatically
    # @param message    [String]
    # @param meta       [Hash]     caller-supplied extra meta (merged in)
    # @param errors     [Hash]     field-level errors (for 422 responses)
    # @param pagination [Hash, nil] plain pagination hash supplied by the caller, e.g.
    #                               { current_page: 1, per_page: 25, total_pages: 4,
    #                                 total_count: 100, next_page: 2, prev_page: nil }
    # @param request    [Object]   ActionDispatch::Request (for request_id)
    def initialize(success:, data: nil, message: nil, meta: {}, errors: nil,
                   pagination: nil, request: nil)
      @success    = success
      @raw_data   = data
      @message    = message
      @extra_meta = meta || {}
      @errors     = errors
      @pagination = pagination
      @request    = request
    end

    # @return [Hash] the complete response payload
    def build
      # We initialize the hash in the exact order we want keys to appear
      payload = {
        success: @success,
        message: resolve_message,
        data:    serialize_data,
      }

      # Add errors before meta if they exist
      payload[:errors] = @errors if @errors && !@errors.empty?

      # Finally, add meta so it appears at the bottom
      payload[:meta] = build_meta

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
      meta = {}

      # 1. Request ID first (opt-in, always authoritative)
      if Respondo.config.include_request_id && @request&.respond_to?(:request_id)
        meta[:request_id] = @request.request_id
      end

      # 2. Timestamp second
      meta[:timestamp] = current_timestamp

      # 3. Global defaults in the middle (lowest priority)
      meta.merge!(Respondo.config.default_meta)

      # 4. Caller-supplied meta (overrides defaults)
      meta.merge!(@extra_meta)

      # 5. Pagination — plain hash from the caller, placed last before code/status
      meta[:pagination] = @pagination if @pagination.is_a?(Hash) && !@pagination.empty?

      # 6. Re-pin code and status to the very end
      code   = meta.delete(:code)
      status = meta.delete(:status)
      meta[:code]   = code   if code
      meta[:status] = status if status

      meta
    end

    # def build_meta
    #   meta = { timestamp: current_timestamp }

    #   # Only extract pagination when caller has not explicitly disabled it
    #   if @pagination
    #     pagination = if @pagy
    #       Pagination.extract(@pagy)
    #     else
    #       Pagination.extract(@raw_data)
    #     end
    #     meta[:pagination] = pagination if pagination
    #   end

    #   # Request ID (Rails only, opt-in via config)
    #   if Respondo.config.include_request_id && @request&.respond_to?(:request_id)
    #     meta[:request_id] = @request.request_id
    #   end

    #   # Merge any caller-supplied meta last (allows overriding)
    #   meta.merge(@extra_meta)
    # end

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
