# frozen_string_literal: true

module Respondo
  # Extracts pagination metadata from Kaminari or Pagy collection objects.
  #
  # Returned hash shape (always the same regardless of pagination library):
  #   {
  #     current_page:  Integer,
  #     per_page:      Integer,
  #     total_pages:   Integer,
  #     total_count:   Integer,
  #     next_page:     Integer | nil,
  #     prev_page:     Integer | nil
  #   }
  module Pagination
    module_function

    # @param collection [Object] any object — returns nil if not a paginated collection
    # @return [Hash, nil]
    def extract(collection)
      return nil if collection.nil?

      if pagy?(collection)
        from_pagy(collection)
      elsif kaminari?(collection)
        from_kaminari(collection)
      elsif will_paginate?(collection)
        from_will_paginate(collection)
      else
        nil
      end
    end

    private

    module_function

    # ----- Pagy ---------------------------------------------------------------
    # Pagy stores metadata on a separate Pagy object, not the collection itself.
    # We support both: passing the Pagy object directly, or a collection that
    # has been decorated with pagy metadata via pagy_metadata.
    def pagy?(object)
      defined?(Pagy) && object.is_a?(Pagy)
    end

    def from_pagy(pagy)
      {
        current_page: pagy.page,
        per_page:     pagy.items,
        total_pages:  pagy.pages,
        total_count:  pagy.count,
        next_page:    pagy.next,
        prev_page:    pagy.prev
      }
    end

    # ----- Kaminari -----------------------------------------------------------
    def kaminari?(object)
      object.respond_to?(:current_page) &&
        object.respond_to?(:total_pages) &&
        object.respond_to?(:limit_value)
    end

    def from_kaminari(collection)
      {
        current_page: collection.current_page,
        per_page:     collection.limit_value,
        total_pages:  collection.total_pages,
        total_count:  collection.total_count,
        next_page:    collection.next_page,
        prev_page:    collection.prev_page
      }
    end

    # ----- WillPaginate -------------------------------------------------------
    def will_paginate?(object)
      object.respond_to?(:current_page) &&
        object.respond_to?(:total_pages) &&
        object.respond_to?(:per_page) &&
        !object.respond_to?(:limit_value) # distinguishes from Kaminari
    end

    def from_will_paginate(collection)
      {
        current_page: collection.current_page,
        per_page:     collection.per_page,
        total_pages:  collection.total_pages,
        total_count:  collection.total_entries,
        next_page:    collection.next_page,
        prev_page:    collection.previous_page
      }
    end
  end
end
