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
        guard_raw_record!(object)
        return load_relation(object).map { |record| serialize_record(record) }
      end

      # 3. Array — recurse
      if object.is_a?(Array)
        enforce_collection_limit!(object.size)
        return object.map { |item| call(item) }
      end

      # 4. ActiveRecord model instance
      if ar_model?(object)
        guard_raw_record!(object)
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

    def load_relation(relation)
      max = Respondo.config.max_collection_size
      return relation unless max

      records = relation.respond_to?(:limit) ? relation.limit(max + 1).to_a : relation.to_a
      enforce_collection_limit!(records.size)
      records
    end

    def enforce_collection_limit!(size)
      max = Respondo.config.max_collection_size
      return unless max && size > max

      raise CollectionTooLargeError,
            "Collection has more than #{max} items (config.max_collection_size)"
    end

    # Raw ActiveRecord objects expose every column through #as_json, including
    # tokens and digests. Fail (strict) or warn once per class (default).
    def guard_raw_record!(object)
      klass = object.class

      if Respondo.config.strict_serialization
        raise UnsafeSerializationError,
              "#{klass.name || klass} was passed as data: without a serializer. Set config.serializer " \
              "or pass an explicit hash (e.g. record.as_json(only: [...]))."
      end

      label = klass.name || klass.to_s
      @warned_classes ||= {}
      return if @warned_classes[label]

      @warned_classes[label] = true
      message = "[Respondo] #{label} serialized with all attributes via #as_json. " \
                "Configure config.serializer or pass `record.as_json(only: [...])` " \
                "to avoid exposing sensitive columns (set config.strict_serialization = true to enforce)."
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.warn(message)
      else
        Kernel.warn(message)
      end
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
