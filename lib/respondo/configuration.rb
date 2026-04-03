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
    # @example use ActiveModelSerializers
    #   config.serializer = ->(obj) { SomeSerializer.new(obj).as_json }
    attr_accessor :serializer

    # Static key-value pairs merged into every response's meta block.
    # @example
    #   config.default_meta = { api_version: "v1", platform: "mobile" }
    attr_accessor :default_meta

    def initialize
      @default_success_message = "Success"
      @default_error_message   = "An error occurred"
      @include_request_id      = false
      @camelize_keys           = false
      @serializer              = nil
      @default_meta            = {}  # e.g. { api_version: "v1", env: "production" }
    end
  end
end
