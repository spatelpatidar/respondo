# # frozen_string_literal: true

# module Respondo
#   # Extracts pagination metadata from Kaminari, Pagy, or WillPaginate collections.
#   #
#   # --- How pagination works in Respondo ---
#   #
#   # Respondo does NOT paginate data for you. Pagination is always performed by
#   # your chosen library (Kaminari, Pagy, or WillPaginate) in your controller
#   # BEFORE you call render_success / render_ok.
#   #
#   # Respondo's role is purely to DETECT that the collection is paginated and
#   # EXTRACT the metadata so it appears in the `meta.pagination` block.
#   #
#   # --- Usage patterns by library ---
#   #
#   # Kaminari (pagination lives on the collection itself):
#   #   @users = User.page(params[:page]).per(params[:per_page] || 10)
#   #   render_ok(data: @users)          # ← just pass the collection; Respondo detects Kaminari
#   #
#   # WillPaginate (same — pagination lives on the collection):
#   #   @users = User.paginate(page: params[:page], per_page: 10)
#   #   render_ok(data: @users)          # ← same pattern
#   #
#   # Pagy (metadata lives on a SEPARATE Pagy object, not the collection):
#   #   @pagy, @users = pagy(User.all, items: 10)
#   #   render_ok(data: @users, pagy: @pagy)   # ← pass the Pagy object explicitly
#   #
#   #   Alternatively, if you decorate your collection with pagy_metadata:
#   #   render_ok(data: @pagy)           # ← pass the Pagy object as data (unusual)
#   #
#   # --- Returned hash shape (same regardless of library) ---
#   #   {
#   #     current_page:  Integer,
#   #     per_page:      Integer,
#   #     total_pages:   Integer,
#   #     total_count:   Integer,
#   #     next_page:     Integer | nil,
#   #     prev_page:     Integer | nil
#   #   }
#   #
#   # --- Disabling pagination meta ---
#   # Pass pagination: false to any render_* helper to suppress the block entirely:
#   #   render_ok(data: @users, pagination: false)
#   #
#   module Pagination
#     module_function

#     # @param collection [Object] any object — returns nil if not a paginated collection
#     # @return [Hash, nil]
#     def extract(collection)
#       return nil if collection.nil?

#       if pagy?(collection)
#         from_pagy(collection)
#       elsif kaminari?(collection)
#         from_kaminari(collection)
#       elsif will_paginate?(collection)
#         from_will_paginate(collection)
#       else
#         nil
#       end
#     end

#     private

#     module_function

#     # -------------------------------------------------------------------------
#     # Pagy
#     # -------------------------------------------------------------------------
#     # Pagy stores metadata on a SEPARATE Pagy object, not the collection.
#     # You must pass it explicitly via the `pagy:` keyword in render_success/render_ok.
#     #
#     # Example in controller:
#     #   @pagy, @records = pagy(User.all, items: 10)
#     #   render_ok(data: @records, pagy: @pagy)
#     #
#     def pagy?(object)
#       defined?(Pagy) && object.is_a?(Pagy)
#     end

#     def from_pagy(pagy)
#       {
#         current_page: pagy.page,
#         per_page:     pagy.items,
#         total_pages:  pagy.pages,
#         total_count:  pagy.count,
#         next_page:    pagy.next,
#         prev_page:    pagy.prev
#       }
#     end

#     # -------------------------------------------------------------------------
#     # Kaminari
#     # -------------------------------------------------------------------------
#     # Kaminari attaches pagination directly to the ActiveRecord relation.
#     # No extra argument needed — just pass the collection.
#     #
#     # Example in controller:
#     #   @records = User.page(params[:page]).per(10)
#     #   render_ok(data: @records)
#     #
#     def kaminari?(object)
#       object.respond_to?(:current_page) &&
#         object.respond_to?(:total_pages) &&
#         object.respond_to?(:limit_value)
#     end

#     def from_kaminari(collection)
#       {
#         current_page: collection.current_page,
#         per_page:     collection.limit_value,
#         total_pages:  collection.total_pages,
#         total_count:  collection.total_count,
#         next_page:    collection.next_page,
#         prev_page:    collection.prev_page
#       }
#     end

#     # -------------------------------------------------------------------------
#     # WillPaginate
#     # -------------------------------------------------------------------------
#     # WillPaginate also attaches pagination to the collection.
#     # No extra argument needed — just pass the collection.
#     #
#     # Example in controller:
#     #   @records = User.paginate(page: params[:page], per_page: 10)
#     #   render_ok(data: @records)
#     #
#     # We distinguish WillPaginate from Kaminari by the absence of #limit_value.
#     #
#     def will_paginate?(object)
#       object.respond_to?(:current_page) &&
#         object.respond_to?(:total_pages) &&
#         object.respond_to?(:per_page) &&
#         !object.respond_to?(:limit_value)
#     end

#     def from_will_paginate(collection)
#       {
#         current_page: collection.current_page,
#         per_page:     collection.per_page,
#         total_pages:  collection.total_pages,
#         total_count:  collection.total_entries,
#         next_page:    collection.next_page,
#         prev_page:    collection.previous_page
#       }
#     end
#   end
# end

