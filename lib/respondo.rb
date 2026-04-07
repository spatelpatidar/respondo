# frozen_string_literal: true

require_relative "respondo/version"
require_relative "respondo/configuration"
require_relative "respondo/serializer"
# require_relative "respondo/pagination"
require_relative "respondo/response_builder"
require_relative "respondo/controller_helpers"

# Respondo — Smart JSON API response formatter for Rails.
#
# @example Configure once in an initializer
#   # config/initializers/respondo.rb
#   Respondo.configure do |config|
#     config.default_success_message = "OK"
#     config.default_error_message   = "Something went wrong"
#     config.include_request_id      = true
#     config.camelize_keys           = true   # for Flutter/JS clients
#   end
#
# @example Include manually (without Railtie / outside Rails)
#   class MyController
#     include Respondo::ControllerHelpers
#   end
module Respondo
  class << self
    # @return [Respondo::Configuration]
    def config
      @config ||= Configuration.new
    end

    # @yield [Respondo::Configuration]
    def configure
      yield config
    end

    # Reset config (useful in tests)
    def reset!
      @config = Configuration.new
    end
  end
end

# Auto-integrate with Rails if present
require_relative "respondo/railtie" if defined?(Rails::Railtie)
