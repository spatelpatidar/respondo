# frozen_string_literal: true

module Respondo
  # Global configuration for Respondo.
  #
  # @example
  #   Respondo.configure do |config|
  #     config.default_success_message = "OK"
  #     config.default_error_message   = "Something went wrong"
  #     config.include_request_id      = true
  #     config.camelize_keys           = true
  #   end
  class Configuration
    # Message used when none is supplied to render_success
    attr_accessor :default_success_message

    # Message used when none is supplied to render_error
    attr_accessor :default_error_message

    # When true, includes request.request_id in every meta block (Rails only)
    attr_accessor :include_request_id

    # When true, all response keys are camelized (suits Flutter/JS clients)
    attr_accessor :camelize_keys

    # Custom serializer callable — receives (object) and must return a Hash.
    # Defaults to nil (built-in serialization strategy is used).
    #
    # It is only called for objects that still need converting (ActiveRecord
    # models/relations and plain Ruby objects). Data that is already serialized
    # — a Hash such as `MySerializer.new(record).serializable_hash`, an Array,
    # a String/Number — is passed through untouched, so developers stay free to
    # use their own serializer in a controller.
    # @example use ActiveModelSerializers
    #   config.serializer = ->(obj) { SomeSerializer.new(obj).as_json }
    attr_accessor :serializer

    # Static key-value pairs merged into every response's meta block.
    # @example
    #   config.default_meta = { api_version: "v1", platform: "mobile" }
    attr_accessor :default_meta

    # When true, passing a raw ActiveRecord model/relation as `data:` without a
    # custom `config.serializer` raises Respondo::UnsafeSerializationError
    # instead of emitting every column via #as_json. Recommended for production.
    # When false (default) a one-time warning is logged per model class.
    attr_accessor :strict_serialization

    # Maximum number of records/elements a collection may contain when it is
    # serialized. Larger collections raise Respondo::CollectionTooLargeError
    # instead of loading everything into memory. nil (default) = no limit.
    attr_accessor :max_collection_size

    # Which serializer the app uses, so Respondo can shape `data` to match.
    #
    #   :none (default)    pass your serializer's output through untouched (response has data.data
    #                      for JSON:API serializers, exactly as before)
    #   :fast_jsonapi, :jsonapi, :jsonapi_serializer
    #                      flatten the JSON:API document: data = { id, **attributes } (or an Array),
    #                      links / included / document meta move into the response meta
    #   :blueprinter, :ams, :json
    #                      output is already flat, passed through untouched (accepted so the
    #                      setting documents which serializer the app uses). For AMS with the
    #                      json_api adapter use :jsonapi.
    SERIALIZER_TYPES = %i[
      none json blueprinter ams active_model_serializers fast_jsonapi jsonapi jsonapi_serializer
    ].freeze
    JSONAPI_TYPES = %i[fast_jsonapi jsonapi jsonapi_serializer].freeze

    attr_reader :serializer_type

    # When flattening JSON:API, also keep each resource's `type` next to `id`
    # (`included` resources always keep it). Default false.
    attr_accessor :jsonapi_include_type

    # @param value [Symbol, String, nil] one of SERIALIZER_TYPES (nil means :none)
    # @raise [ArgumentError] for an unknown type, so a typo fails at boot rather than silently
    def serializer_type=(value)
      type = value.nil? || value.to_s.strip.empty? ? :none : value.to_s.strip.downcase.tr("-", "_").to_sym

      unless SERIALIZER_TYPES.include?(type)
        raise ArgumentError,
              "Unknown serializer_type #{value.inspect}. Use one of: #{SERIALIZER_TYPES.map(&:inspect).join(', ')}"
      end

      @serializer_type = type
    end

    # @return [Boolean] true when JSON:API documents should be flattened
    def unwrap_jsonapi?
      JSONAPI_TYPES.include?(@serializer_type)
    end

    def initialize
      @serializer_type         = :none
      @jsonapi_include_type    = false
      @default_success_message = "Success"
      @default_error_message   = "An error occurred"
      @include_request_id      = false
      @camelize_keys           = false
      @serializer              = nil
      @default_meta            = {}  # e.g. { api_version: "v1", env: "production" }
      @strict_serialization    = false
      @max_collection_size     = nil
    end
  end
end
