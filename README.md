# Respondo 🎯

Smart JSON API response formatter for Rails — consistent structure every time, across every app.

```json
{
  "success": true,
  "message": "Users fetched",
  "data": [...],
  "meta": {
    "timestamp": "2024-06-15T10:30:00Z",
    "pagination": {
      "currentPage": 1,
      "perPage": 25,
      "totalPages": 4,
      "totalCount": 98,
      "nextPage": 2,
      "prevPage": null
    }
  }
}
```

## The Problem

Different developers return different JSON structures — some use `data`, some use `result`, some forget `success: true`. This makes frontend integration (Flutter, React, etc.) brittle and unpredictable.

Respondo enforces one structure, everywhere, automatically.

---

## Installation

```ruby
gem "respondo"
```

---

## Setup

```ruby
# config/initializers/respondo.rb
Respondo.configure do |config|
  config.default_success_message = "OK"
  config.default_error_message   = "Something went wrong"
  config.include_request_id      = true   # adds request_id to every meta
  config.camelize_keys           = true   # snake_case → camelCase for Flutter/JS
end
```

Respondo auto-includes itself into `ActionController::Base` and `ActionController::API` via Railtie. No manual `include` needed in `ApplicationController`.

---

## Controller Usage

### Success responses

```ruby
# 200 OK — plain data
render_success(data: @user, message: "Profile loaded")

# 201 Created
render_created(data: @post, message: "Post published")

# Paginated collection (Kaminari or Pagy — auto-detected)
users = User.page(params[:page]).per(25)
render_success(data: users, message: "Users fetched")

# With Pagy (pass the pagy object separately)
pagy, users = pagy(User.all)
render_success(data: users, pagy: pagy, message: "Users fetched")

# No content (soft delete, etc.)
render_no_content(message: "Post deleted")
```

### Error responses

```ruby
# 422 Unprocessable Entity (default)
render_error(message: "Validation failed", errors: user.errors)

# 401 Unauthorized
render_unauthorized("Token has expired")

# 403 Forbidden
render_forbidden("You don't have access to this resource")

# 404 Not Found
render_not_found("User not found")

# 500 Server Error
render_server_error("Unexpected error occurred")

# Custom status + machine-readable code
render_error(message: "Rate limit hit", code: "RATE_LIMITED", status: :too_many_requests)
```

---

## Response Structure

Every single response — success or error — returns the same four keys:

| Key       | Type             | Description                                  |
|-----------|------------------|----------------------------------------------|
| `success` | Boolean          | `true` or `false`                            |
| `message` | String           | Human-readable description                   |
| `data`    | Object/Array/nil | The payload                                  |
| `meta`    | Object           | Timestamp + pagination + optional request_id |

Error responses additionally include:

| Key      | Type | Description                          |
|----------|------|--------------------------------------|
| `errors` | Hash | Field-level errors `{field: [msgs]}` |

---

## Auto-Serialization

Respondo automatically handles:

| Input type                      | Output                                      |
|---------------------------------|---------------------------------------------|
| `ActiveRecord::Base` instance   | `record.as_json`                            |
| `ActiveRecord::Relation`        | Array of `as_json` records                  |
| `ActiveModel::Errors`           | `{ field: ["message", ...] }`               |
| `Hash`                          | Passed through (values serialized)          |
| `Array`                         | Each element serialized recursively         |
| `Exception`                     | `{ message: e.message }`                   |
| Anything with `#as_json`        | `.as_json`                                  |
| Anything with `#to_h`           | `.to_h`                                     |
| Primitives (String, Integer...)  | As-is                                      |

### Custom serializer

```ruby
Respondo.configure do |config|
  # Use ActiveModelSerializers, Blueprinter, Panko, etc.
  config.serializer = ->(obj) { UserSerializer.new(obj).as_json }
end
```

---

## Pagination Meta

Automatically detected — no extra code needed.

### Kaminari

```ruby
users = User.page(params[:page]).per(25)
render_success(data: users)
# meta.pagination is populated automatically
```

### Pagy

```ruby
pagy, users = pagy(User.all)
render_success(data: users, pagy: pagy)
```

### WillPaginate

```ruby
users = User.paginate(page: params[:page], per_page: 25)
render_success(data: users)
```

---

## camelCase for Flutter / JavaScript

```ruby
Respondo.configure { |c| c.camelize_keys = true }
```

All keys in the response — including nested `meta.pagination` — are camelized:
`current_page` → `currentPage`, `total_count` → `totalCount`, etc.

---

## Flutter Integration

```dart
// Every response follows the same shape
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final Map<String, dynamic> meta;
  final Map<String, dynamic>? errors;
}
```

---

## Architecture

```
lib/
├── respondo.rb                    # Entry point, configure, Railtie hook
└── respondo/
    ├── version.rb                 # VERSION
    ├── configuration.rb           # Config with defaults
    ├── serializer.rb              # Auto-detects and serializes any object
    ├── pagination.rb              # Kaminari / Pagy / WillPaginate extractor
    ├── response_builder.rb        # Assembles the final Hash
    ├── controller_helpers.rb      # render_success, render_error, convenience methods
    └── railtie.rb                 # Auto-includes into Rails controllers
```

---

## Running Tests

```bash
bundle install
bundle exec rspec --format documentation
```

---

## License

MIT
