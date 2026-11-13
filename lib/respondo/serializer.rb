# frozen_string_literal: true

module Respondo
  # Responsible for converting any Ruby object into a JSON-safe Hash or Array.
  #
  # Respondo is a response *wrapper*: data that is already serialized (a Hash,
  # an Array, a scalar, the output of `serializable_hash`) is passed through
  # untouched, and `config.serializer` is only used for objects that still need
  # converting (models, relations, plain Ruby objects).
  #
  # Priority order:
  #   1. nil                        -> nil
  #   2. Hash                       -> values serialized recursively (never sent to config.serializer)
  #   3. Array                      -> each element serialized recursively
  #   4. Scalars (String, Numeric, Symbol, true/false, Time, Date)
  #   5. Exception / ActiveModel::Errors
  #   6. Non-ActiveRecord objects that respond to #serializable_hash
  #      (a jsonapi-serializer / fast_jsonapi / AMS serializer instance) -> #serializable_hash
  #   7. Custom serializer from Respondo.config (if set)
  #   8. ActiveRecord::Relation / ActiveRecord::Base (with the raw-record guard)
  #   9. Objects responding to #as_json or #to_h
  #  10. Anything else -> returned as-is
  module Serializer
    module_function

    # @param object [Object] anything — AR model, collection, error, hash, array, primitive
    # @return [Hash, Array, String, Numeric, nil]
    def call(object)
      return nil if object.nil?

      # 1. Already-serialized data passes through. This is what lets
      #    `ListingSerializer.new(listing).serializable_hash` work with any
      #    serializer library, with or without config.serializer.
      return serialize_hash(object)  if object.is_a?(Hash)
      return serialize_array(object) if object.is_a?(Array)
      return serialize_scalar(object) if scalar?(object)

      # 2. Built-in handling for errors
      return serialize_errors(object) if active_model_errors?(object)
      return { message: object.message } if object.is_a?(Exception)

      record_like = ar_relation?(object) || ar_model?(object)

      # 3. A serializer instance (or any non-AR object that knows how to turn
      #    itself into a Hash). Use its own output instead of #as_json, which
      #    would dump instance variables (including the wrapped record).
      if !record_like && self_serializing?(object)
        return call(object.serializable_hash)
      end

      # 4. Custom serializer, for models and other objects that need converting
      if Respondo.config.serializer
        return Respondo.config.serializer.call(object)
      end

      # 5. ActiveRecord::Relation (lazy collection)
      if ar_relation?(object)
        guard_raw_record!(object)
        return load_relation(object).map { |record| serialize_record(record) }
      end

      # 6. ActiveRecord model instance
      if ar_model?(object)
        guard_raw_record!(object)
        return serialize_record(object)
      end

      # 7. Responds to #as_json (ActiveSupport)
      if object.respond_to?(:as_json)
        return object.as_json
      end

      # 8. Responds to #to_h
      if object.respond_to?(:to_h)
        return object.to_h
      end

      # 9. Anything else — return as-is
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

    def serialize_hash(hash)
      hash.transform_values { |value| call(value) }
    end

    def serialize_array(array)
      enforce_collection_limit!(array.size)
      array.map { |item| call(item) }
    end

    # Values that are already JSON-ready. They must never reach
    # config.serializer, otherwise every string/number inside a Hash would be
    # handed to a model serializer.
    def scalar?(object)
      case object
      when String, Symbol, Numeric, true, false, Time then true
      else defined?(::Date) ? ::Date === object : false # Date and DateTime
      end
    end

    # Keeps the previous behaviour for scalars: ActiveSupport turns Symbol,
    # BigDecimal, Time, Date... into JSON-safe values via #as_json.
    def serialize_scalar(object)
      object.respond_to?(:as_json) ? object.as_json : object
    end

    # Detects a serializer instance (jsonapi-serializer, fast_jsonapi, AMS,
    # ActiveModel::Serialization objects) without calling #respond_to? on the
    # object, so it never triggers method_missing / strict test doubles.
    def self_serializing?(object)
      object.class.method_defined?(:serializable_hash)
    end

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
