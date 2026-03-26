# frozen_string_literal: true

module Respondo
  # Railtie automatically includes Respondo::ControllerHelpers into
  # ActionController::Base and ActionController::API when Rails is present.
  # No manual include needed in ApplicationController.
  class Railtie < Rails::Railtie
    initializer "respondo.include_controller_helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        include Respondo::ControllerHelpers
      end

      ActiveSupport.on_load(:action_controller_api) do
        include Respondo::ControllerHelpers
      end
    end
  end
end
