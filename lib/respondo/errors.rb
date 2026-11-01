# frozen_string_literal: true

module Respondo
  class Error < StandardError; end

  # Raised when strict_serialization is on and a raw ActiveRecord object is
  # passed as `data:` without a custom serializer.
  class UnsafeSerializationError < Error; end

  # Raised when a collection exceeds config.max_collection_size.
  class CollectionTooLargeError < Error; end

  # Raised when a redirect location is malformed or points to another host.
  class UnsafeRedirectError < Error; end
end
