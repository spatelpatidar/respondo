# Changelog

## [1.0.0] — Production Ready

### Breaking Changes
- `render_error` and all error helpers (`render_bad_request`, `render_unauthorized`,
  `render_forbidden`, `render_not_found`, etc.) — removed `status` as a public
  parameter; status is now derived internally and can no longer be overridden by callers
- All error helpers now accept `meta: {}` — allows per-call meta injection
  (previously only `render_success` and success helpers supported this)

### Added
- `meta: {}` parameter on all error helpers — pass per-request meta such as
  `api_version`, `env`, `region` directly at the call site
- `config.default_meta` — static key-value pairs merged into every response's
  meta block automatically (e.g. `{ api_version: "v1", platform: "api" }`)
- Deterministic meta key ordering — `request_id` → `timestamp` → `default_meta`
  → caller `meta` → `code` → `status`

### Fixed
- Error helper `code:` values were strings (e.g. `"404"`) while success helpers
  used integers — all codes are now consistently integers across all helpers
- Trailing commas removed from `render_service_unavailable` and
  `render_gateway_timeout` signatures
- `render_no_content` had mismatched `status: :ok` (200) with `code: 204` in
  meta — now consistent
- Caller-supplied `meta` could previously override system fields (`timestamp`,
  `request_id`) — system fields are now always authoritative

---

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
