# frozen_string_literal: true

module Respondo
  # Responsible for converting any Ruby object into a JSON-safe Hash or Array.
  #
  # Priority order:
  #   1. Custom serializer from Respondo.config (if set)
  #   2. ActiveRecord::Base / ActiveRecord::Relation
  #   3. ActiveModel::Errors / objects responding to #errors
  #   4. Objects responding to #as_json or #to_h
  #   5. Arrays — each element is serialized recursively
  #   6. Primitives — returned as-is
  module Serializer
    module_function

    # @param object [Object] anything — AR model, collection, error, hash, array, primitive
    # @return [Hash, Array, String, Numeric, nil]
    def call(object)
      return nil if object.nil?

      # 1. Custom serializer wins
      if Respondo.config.serializer
        return Respondo.config.serializer.call(object)
      end

      # 2. ActiveRecord::Relation or any object with #map (lazy collections)
      if ar_relation?(object)
        return object.map { |record| serialize_record(record) }
      end

      # 3. Array — recurse
      if object.is_a?(Array)
        return object.map { |item| call(item) }
      end

      # 4. ActiveRecord model instance
      if ar_model?(object)
        return serialize_record(object)
      end

      # 5. ActiveModel::Errors object
      if active_model_errors?(object)
        return serialize_errors(object)
      end

      # 6. Exception / StandardError
      if object.is_a?(Exception)
        return { message: object.message }
      end

      # 7. Hash — recursively serialize values
      if object.is_a?(Hash)
        return object.transform_values { |v| call(v) }
      end

      # 8. Responds to #as_json (ActiveSupport)
      if object.respond_to?(:as_json)
        return object.as_json
      end

      # 9. Responds to #to_h
      if object.respond_to?(:to_h)
        return object.to_h
      end

      # 10. Primitive — return as-is
      object
    end

    private

    module_function

    def ar_relation?(object)
      defined?(ActiveRecord::Relation) &&
        object.is_a?(ActiveRecord::Relation)
    end

    def ar_model?(object)
      defined?(ActiveRecord::Base) &&
        object.is_a?(ActiveRecord::Base)
    end

    def active_model_errors?(object)
      defined?(ActiveModel::Errors) &&
        object.is_a?(ActiveModel::Errors)
    end

    def serialize_record(record)
      if record.respond_to?(:as_json)
        record.as_json
      elsif record.respond_to?(:to_h)
        record.to_h
      else
        record
      end
    end

    def serialize_errors(errors)
      # ActiveModel::Errors — return { field: ["msg", ...] }
      if errors.respond_to?(:to_hash)
        errors.to_hash
      elsif errors.respond_to?(:messages)
        errors.messages
      else
        {}
      end
    end
  end
end
