# Changelog

## [0.1.0] — Initial Release

### Added
- Standardized JSON response structure: `success`, `message`, `data`, `meta`
- `render_success` — 200 OK with optional data, message, meta, pagy
- `render_error` — 422 default with field errors, machine-readable code
- Convenience helpers: `render_unauthorized`, `render_forbidden`, `render_not_found`, `render_server_error`, `render_created`, `render_no_content`
- Auto-serialization: ActiveRecord, Relation, ActiveModel::Errors, Hash, Array, Exception
- Pagination meta: Kaminari, Pagy, WillPaginate — auto-detected, no extra code
- `camelize_keys` config — snake_case → camelCase for Flutter/JS clients
- `include_request_id` config — adds Rails request ID to every meta block
- Custom serializer hook — plug in ActiveModelSerializers, Blueprinter, Panko, etc.
- Railtie — auto-includes into ActionController::Base and ActionController::API
- Zero hard dependencies — Rails, Kaminari, Pagy are all optional
