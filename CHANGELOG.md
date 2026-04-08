# Changelog

## [2.0.0] — Full HTTP Coverage

### Breaking Changes

#### Pagination API completely redesigned
The old approach auto-detected Kaminari, Pagy, and WillPaginate collections and
extracted pagination metadata silently. This was over-engineered — Respondo is a
**response formatter**, not a pagination library.

**Before (1.x):**
```ruby
# Kaminari / WillPaginate — auto-detected from collection
render_ok(data: @users)

# Pagy — required a separate pagy: argument
render_ok(data: @users, pagy: @pagy)

# Suppress pagination
render_ok(data: @users, pagination: false)
```

**After (2.x):**
```ruby
# All libraries — you build the hash, Respondo places it in meta
render_ok(
  data:       @users,
  pagination: {
    current_page: @users.current_page,
    per_page:     @users.limit_value,   # Kaminari
    total_pages:  @users.total_pages,
    total_count:  @users.total_count,
    next_page:    @users.next_page,
    prev_page:    @users.prev_page
  }
)

# No pagination — just omit the param
render_ok(data: @user)
```

**Why:** The caller already has the paginated data in hand. Building the hash
themselves is one extra step, but it makes the behavior completely explicit,
works with any library (or no library), and removes a hidden dependency from
the gem's internals.

**Migration steps:**
1. Delete any `pagy:` arguments — replace with `pagination: { ... }` hash
2. Delete any `pagination: false` arguments — just omit `pagination:` instead
3. Remove `pagination.rb` from your gem if you vendored it

#### `render_success` signature change
- `pagy:` parameter removed
- `pagination:` parameter type changed from `Boolean` → `Hash | nil`

**Before:** `render_success(data:, message:, meta:, code:, pagy:, pagination: Boolean, status:)`  
**After:** `render_success(data:, message:, meta:, code:, pagination: Hash | nil, status:)`

---

### Added

#### 1xx — Informational helpers (all new)
These return a JSON body for API consistency. Note that 1xx responses are
protocol-level and most HTTP clients will not receive them as normal responses.

| Helper | Code |
|--------|------|
| `render_continue` | 100 |
| `render_switching_protocols` | 101 |
| `render_processing` | 102 |
| `render_early_hints` | 103 |

#### 2xx — Additional success helpers
| Helper | Code |
|--------|------|
| `render_non_authoritative` | 203 |
| `render_reset_content` | 205 |
| `render_already_reported` | 208 |
| `render_im_used` | 226 |

#### 3xx — Redirect helpers (all new)
Pass the target URL via `meta: { redirect_url: "..." }`.

| Helper | Code |
|--------|------|
| `render_multiple_choices` | 300 |
| `render_moved_permanently` | 301 |
| `render_found` | 302 |
| `render_see_other` | 303 |
| `render_not_modified` | 304 |
| `render_temporary_redirect` | 307 |
| `render_permanent_redirect` | 308 |

#### 4xx — Additional client error helpers
| Helper | Code |
|--------|------|
| `render_proxy_auth_required` | 407 |
| `render_length_required` | 411 |
| `render_payload_too_large` | 413 |
| `render_uri_too_long` | 414 |
| `render_range_not_satisfiable` | 416 |
| `render_expectation_failed` | 417 |
| `render_im_a_teapot` | 418 |
| `render_misdirected_request` | 421 |
| `render_failed_dependency` | 424 |
| `render_too_early` | 425 |
| `render_upgrade_required` | 426 |
| `render_precondition_required` | 428 |
| `render_request_header_fields_too_large` | 431 |
| `render_unavailable_for_legal_reasons` | 451 |

#### 5xx — Additional server error helpers
| Helper | Code |
|--------|------|
| `render_http_version_not_supported` | 505 |
| `render_variant_also_negotiates` | 506 |
| `render_insufficient_storage` | 507 |
| `render_loop_detected` | 508 |
| `render_not_extended` | 510 |
| `render_network_authentication_required` | 511 |

#### `pagination:` on all 2xx and 3xx helpers
Previously only `render_ok` exposed a pagination parameter. Now every 2xx and
3xx helper accepts `pagination: Hash | nil` so you can include pagination meta
from any success response type, not just 200.

---

### Removed

- `pagination.rb` — entire file deleted. Auto-detection of Kaminari, Pagy, and
  WillPaginate is no longer part of the gem. Respondo has zero pagination
  library dependencies.
- `pagy:` parameter from `render_success` and `render_ok`
- `pagination: Boolean` flag — no longer needed since passing `nil` (the default)
  simply omits the key from meta

---

### Stats

| | v1.0.0 | v2.0.0 |
|---|---|---|
| Total helpers | 7 | 57 |
| HTTP codes covered | 13 | 52 |
| Files | 7 | 6 (pagination.rb removed) |
| Pagination gem dependencies | 3 (optional) | 0 |

---

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
