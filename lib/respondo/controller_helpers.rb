# frozen_string_literal: true

module Respondo
  # Mixed into Rails controllers to provide render_success and render_error.
  #
  # @example
  #   class ApplicationController < ActionController::Base
  #     include Respondo::ControllerHelpers
  #   end
  #
  #   class UsersController < ApplicationController
  #     def index
  #       users = User.page(params[:page]).per(25)
  #
  #       # pagination auto-detected and included (default)
  #       render_success(data: users, message: "Users fetched")
  #
  #       # caller explicitly suppresses pagination
  #       render_success(data: users, message: "Users fetched", pagination: false)
  #     end
  #
  #     def create
  #       user = User.new(user_params)
  #       if user.save
  #         render_success(data: user, message: "User created", status: :created)
  #       else
  #         render_error(message: "Validation failed", errors: user.errors)
  #       end
  #     end
  #
  #     def show
  #       render_success(data: User.find(params[:id]))
  #     rescue ActiveRecord::RecordNotFound
  #       render_not_found("User not found")
  #     end
  #   end
  module ControllerHelpers
    # Render a successful JSON response.
    #
    # @param data       [Object]          payload — AR model, collection, Hash, Array, nil
    # @param message    [String]          human-readable description
    # @param meta       [Hash]            extra meta fields merged into the meta block
    # @param pagy       [Pagy]            optional Pagy object (pass when using Pagy backend)
    # @param pagination [Boolean]         true  = include pagination meta when available (default)
    #                                     false = always suppress pagination meta
    # @param status     [Symbol, Integer] HTTP status (default: :ok / 200)
    def render_success(data: nil, message: nil, meta: {}, pagy: nil, pagination: true, status: :ok)
      payload = ResponseBuilder.new(
        success:    true,
        data:       data,
        message:    message,
        meta:       meta,
        pagy:       pagy,
        pagination: pagination,
        request:    try(:request)
      ).build

      render json: payload, status: status
    end

    # Render an error JSON response.
    #
    # @param message [String]             human-readable error description
    # @param errors  [Hash, ActiveModel::Errors]  field-level validation errors
    # @param code    [String, nil]        machine-readable error code e.g. "AUTH_EXPIRED"
    # @param meta    [Hash]               extra meta fields
    # @param status  [Symbol, Integer]    HTTP status (default: :unprocessable_entity / 422)
    def render_error(message: nil, errors: nil, code: nil, meta: {}, status: :unprocessable_entity)
      extracted_errors = extract_errors(errors)
      merged_meta      = code ? meta.merge(error_code: code) : meta

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

    # Convenience: 401 Unauthorized
    def render_unauthorized(message = "Unauthorized")
      render_error(message: message, code: "UNAUTHORIZED", status: :unauthorized)
    end

    # Convenience: 403 Forbidden
    def render_forbidden(message = "Forbidden")
      render_error(message: message, code: "FORBIDDEN", status: :forbidden)
    end

    # Convenience: 404 Not Found
    def render_not_found(message = "Resource not found")
      render_error(message: message, code: "NOT_FOUND", status: :not_found)
    end

    # Convenience: 500 Internal Server Error
    def render_server_error(message = "Internal server error")
      render_error(message: message, code: "SERVER_ERROR", status: :internal_server_error)
    end

    # Convenience: 201 Created
    def render_created(data: nil, message: "Created successfully", pagination: false)
      render_success(data: data, message: message, pagination: pagination, status: :created)
    end

    # Convenience: 200 OK with nil data (soft deletes, actions with no payload)
    def render_no_content(message: "Deleted successfully")
      render_success(data: nil, message: message, pagination: false, status: :ok)
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
