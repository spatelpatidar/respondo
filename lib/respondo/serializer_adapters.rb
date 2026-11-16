# frozen_string_literal: true

module Respondo
  # Optional, opt-in reshaping of already-serialized data, chosen with
  # `config.serializer_type`.
  #
  # Most serializers already return the shape you want (Blueprinter's `render_as_hash`,
  # `as_json`, plain hashes), so for those nothing is changed. jsonapi-serializer /
  # fast_jsonapi return a JSON:API *document*:
  #
  #   { data: { id: "1", type: :user, attributes: { name: "Alice" } },
  #     links: { ... }, included: [ ... ] }
  #
  # Passed to `render_ok(data: ...)` unchanged this gives `data.data.attributes`. With
  # `config.serializer_type = :fast_jsonapi` (or :jsonapi / :jsonapi_serializer) Respondo
  # flattens it, so the response is:
  #
  #   "data": { "id": "1", "name": "Alice" }                       # or an Array for collections
  #   "meta": { "links": { ... }, "included": [ ... ], ... }       # document extras move into meta
  #
  # Rules
  # * Only objects that really look like a JSON:API document are touched: a Hash whose keys are
  #   all from data/links/included/meta/jsonapi, with `data` being nil, a resource, or an Array
  #   of resources ({ id:, type: } hashes). Everything else passes through unchanged.
  # * A document at the top level of `data:` also lifts `links`, `included` (each flattened, and
  #   keeping its `type`) and the document's own `meta` into the response meta.
  # * A document nested inside a bigger hash (e.g. { token: "..", user: <document> }) is flattened
  #   in place; its links/included are dropped because there is nowhere to put them.
  # * `relationships` are not copied into the flat resource. Foreign keys that your serializer
  #   lists as attributes (e.g. user_id) stay, and related records arrive via meta.included.
  module SerializerAdapters
    module_function

    DOCUMENT_KEYS = %i[data links included meta jsonapi].freeze

    # @param serialized [Object] output of Respondo::Serializer.call
    # @return [Array(Object, Hash)] the data to render, and meta pairs lifted out of the document
    def apply(serialized)
      return [serialized, {}] unless Respondo.config.unwrap_jsonapi?

      if jsonapi_document?(serialized)
        [flatten_data(fetch(serialized, :data)), lifted_meta(serialized)]
      else
        [unwrap_nested(serialized), {}]
      end
    end

    # True for { data: nil | resource | [resource, ...], links:, included:, meta:, jsonapi: }
    def jsonapi_document?(object)
      return false unless object.is_a?(Hash) && !object.empty?
      return false unless object.keys.all? { |key| key.respond_to?(:to_sym) && DOCUMENT_KEYS.include?(key.to_sym) }
      return false unless key?(object, :data)

      data = fetch(object, :data)
      data.nil? || resource?(data) || (data.is_a?(Array) && data.all? { |item| resource?(item) })
    end

    def resource?(object)
      object.is_a?(Hash) && key?(object, :id) && key?(object, :type)
    end

    def flatten_data(data)
      case data
      when Array then data.map { |resource| flatten_resource(resource) }
      when Hash  then flatten_resource(data)
      else data
      end
    end

    # { id:, type:, attributes: {...}, relationships: {...} } -> { id:, **attributes }
    def flatten_resource(resource, keep_type: Respondo.config.jsonapi_include_type)
      attributes = fetch(resource, :attributes)
      attributes = {} unless attributes.is_a?(Hash)

      # Keep the key style of the input (Symbol keys from serializable_hash, String keys from parsed JSON)
      symbols = resource.key?(:id)
      flat = { (symbols ? :id : "id") => fetch(resource, :id) }
      flat[symbols ? :type : "type"] = fetch(resource, :type) if keep_type
      flat.merge(attributes)
    end

    def lifted_meta(document)
      lifted = {}

      links = fetch(document, :links)
      lifted[:links] = links if links.is_a?(Hash) && !links.empty?

      included = fetch(document, :included)
      if included.is_a?(Array) && !included.empty?
        lifted[:included] = included.map { |resource| resource?(resource) ? flatten_resource(resource, keep_type: true) : resource }
      end

      document_meta = fetch(document, :meta)
      document_meta = document_meta.each_with_object({}) { |(k, v), memo| memo[k.to_sym] = v } if document_meta.is_a?(Hash)

      (document_meta.is_a?(Hash) ? document_meta : {}).merge(lifted)
    end

    # Walks a Hash/Array and flattens any nested JSON:API document in place.
    def unwrap_nested(object)
      case object
      when Hash
        return flatten_data(fetch(object, :data)) if jsonapi_document?(object)

        object.transform_values { |value| unwrap_nested(value) }
      when Array
        object.map { |item| unwrap_nested(item) }
      else
        object
      end
    end

    # Symbol-or-String key access (data may come from `serializable_hash` or a parsed JSON body).
    def key?(hash, key)
      hash.key?(key) || hash.key?(key.to_s)
    end

    def fetch(hash, key)
      hash.key?(key) ? hash[key] : hash[key.to_s]
    end
  end
end
