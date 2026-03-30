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

## Complete Helper Reference

### 2xx — Success Helpers

#### `render_ok` — 200 OK
Explicit alias for `render_success`. Use when you want to be more descriptive.

```ruby
render_ok(data: @user, message: "User found")
```

#### `render_created` — 201 Created
Use after a successful POST that creates a resource.

```ruby
render_created(data: @post, message: "Post published")
render_created(data: @user)  # uses default "Created successfully" message
```

#### `render_accepted` — 202 Accepted
Use for async operations — the request was received but processing happens in the background.

```ruby
render_accepted(message: "Your export is being processed. You will receive an email when ready.")
render_accepted(data: { job_id: "abc123" }, message: "Job queued")
```

#### `render_no_content` — 200 OK
Use after DELETE or actions with no meaningful response body. Returns standard JSON structure for consistency.

```ruby
render_no_content                                  # "Deleted successfully"
render_no_content(message: "Account deactivated")
```

#### `render_partial_content` — 206 Partial Content
Use for chunked or range-based responses.

```ruby
render_partial_content(data: @chunk, message: "Page 1 of 5")
render_partial_content(data: @results, meta: { range: "0-99/500" })
```

#### `render_multi_status` — 207 Multi-Status
Use for batch operations where some succeed and some fail.

```ruby
render_multi_status(
  data: { created: 8, failed: 2 },
  message: "Batch completed with partial failures"
)
```

---

### 4xx — Client Error Helpers

#### `render_bad_request` — 400 Bad Request
Malformed request, missing required parameters, invalid format.

```ruby
render_bad_request                                           # default message
render_bad_request("The 'date' parameter is required")
render_bad_request("Invalid input", errors: { date: ["must be a valid date"] })
render_bad_request("Invalid input", code: "INVALID_FORMAT") # custom error code
```

#### `render_unauthorized` — 401 Unauthorized
User is not authenticated. Use when no valid token/session is present.

```ruby
render_unauthorized                          # "Unauthorized"
render_unauthorized("Please log in to continue")
render_unauthorized("Token has expired", code: "TOKEN_EXPIRED")
```

#### `render_payment_required` — 402 Payment Required
Feature is behind a paywall or subscription.

```ruby
render_payment_required
render_payment_required("Upgrade to Pro to access this feature")
render_payment_required("Subscription expired", code: "SUBSCRIPTION_EXPIRED")
```

#### `render_forbidden` — 403 Forbidden
User is authenticated but lacks permission for this action.

```ruby
render_forbidden
render_forbidden("You can only edit your own posts")
render_forbidden("Admin access required", code: "ADMIN_REQUIRED")
```

#### `render_not_found` — 404 Not Found
Requested resource does not exist.

```ruby
render_not_found
render_not_found("User not found")
render_not_found("Post ##{params[:id]} does not exist")
```

#### `render_method_not_allowed` — 405 Method Not Allowed
The HTTP verb used is not supported for this endpoint.

```ruby
render_method_not_allowed
render_method_not_allowed("This endpoint only accepts POST requests")
```

#### `render_not_acceptable` — 406 Not Acceptable
The server cannot produce a response matching the client's Accept header.

```ruby
render_not_acceptable
render_not_acceptable("Only application/json is supported")
```

#### `render_request_timeout` — 408 Request Timeout
The request took too long to process.

```ruby
render_request_timeout
render_request_timeout("The query took too long. Try a smaller date range.")
```

#### `render_conflict` — 409 Conflict
Request conflicts with the current state of the resource. Use for duplicate records, state conflicts.

```ruby
render_conflict
render_conflict("Email address is already registered")
render_conflict("Cannot cancel a completed order", code: "INVALID_STATE_TRANSITION")
render_conflict("Duplicate entry", errors: { email: ["has already been taken"] })
```

#### `render_gone` — 410 Gone
Resource existed but has been permanently deleted.

```ruby
render_gone
render_gone("This account has been permanently deleted")
```

#### `render_precondition_failed` — 412 Precondition Failed
Conditional request headers (If-Match, If-None-Match) did not match.

```ruby
render_precondition_failed
render_precondition_failed("Resource has been modified since your last request")
```

#### `render_unsupported_media_type` — 415 Unsupported Media Type
The Content-Type header is not supported.

```ruby
render_unsupported_media_type
render_unsupported_media_type("Please send requests as application/json")
```

#### `render_unprocessable` — 422 Unprocessable Entity
Validation errors. The most commonly used error helper in Rails APIs.

```ruby
render_unprocessable("Validation failed", errors: user.errors)
render_unprocessable("Invalid data", errors: { name: ["can't be blank"], age: ["must be over 18"] })
```

#### `render_locked` — 423 Locked
Resource is locked and cannot be modified.

```ruby
render_locked
render_locked("This record is locked by another user")
render_locked("Invoice is locked after approval", code: "INVOICE_LOCKED")
```

#### `render_too_many_requests` — 429 Too Many Requests
Rate limit exceeded.

```ruby
render_too_many_requests
render_too_many_requests("You have exceeded 100 requests per minute. Retry after 60 seconds.")
render_too_many_requests("API limit reached", code: "API_LIMIT_EXCEEDED")
```

---

### 5xx — Server Error Helpers

#### `render_server_error` — 500 Internal Server Error
An unexpected error occurred on the server.

```ruby
render_server_error
render_server_error("Something went wrong. Our team has been notified.")

# Common pattern — rescue unexpected exceptions
rescue StandardError => e
  Rails.logger.error(e)
  render_server_error("An unexpected error occurred")
```

#### `render_not_implemented` — 501 Not Implemented
The requested feature has not been built yet.

```ruby
render_not_implemented
render_not_implemented("CSV export is coming soon")
```

#### `render_bad_gateway` — 502 Bad Gateway
An upstream service (third-party API, microservice) returned an invalid response.

```ruby
render_bad_gateway
render_bad_gateway("Payment gateway is currently unavailable")
render_bad_gateway("Could not reach the SMS service", code: "SMS_GATEWAY_ERROR")
```

#### `render_service_unavailable` — 503 Service Unavailable
Server is temporarily unable to handle the request — maintenance, overloaded.

```ruby
render_service_unavailable
render_service_unavailable("We are currently under maintenance. Back in 30 minutes.")
```

#### `render_gateway_timeout` — 504 Gateway Timeout
An upstream service timed out before responding.

```ruby
render_gateway_timeout
render_gateway_timeout("The payment processor did not respond in time. Please try again.")
```

---

## Real-World Controller Examples

```ruby
class UsersController < ApplicationController

  def index
    users = User.active.page(params[:page]).per(25)
    render_ok(data: users, message: "Users fetched")
    # → 200, with pagination meta auto-included
  end

  def show
    user = User.find(params[:id])
    render_ok(data: user, message: "User found")
  rescue ActiveRecord::RecordNotFound
    render_not_found("User ##{params[:id]} not found")
    # → 404, { success: false, errors_code: "NOT_FOUND" }
  end

  def create
    user = User.new(user_params)
    if user.save
      render_created(data: user, message: "Account created successfully")
      # → 201
    else
      render_unprocessable("Validation failed", errors: user.errors)
      # → 422, { errors: { email: ["is invalid"] } }
    end
  end

  def update
    user = User.find(params[:id])

    unless user == current_user || current_user.admin?
      render_forbidden("You can only update your own profile")
      # → 403
      return
    end

    if user.update(user_params)
      render_ok(data: user, message: "Profile updated")
    else
      render_conflict("Could not update profile", errors: user.errors)
      # → 409
    end
  end

  def destroy
    User.find(params[:id]).destroy!
    render_no_content(message: "Account deleted")
    # → 200
  rescue ActiveRecord::RecordNotFound
    render_gone("This account no longer exists")
    # → 410
  end

end

class PaymentsController < ApplicationController

  def create
    result = PaymentGateway.charge(amount: params[:amount], token: params[:token])
    render_created(data: result, message: "Payment successful")
  rescue PaymentGateway::CardDeclined => e
    render_unprocessable(e.message)
  rescue PaymentGateway::Timeout
    render_gateway_timeout("Payment processor timed out. You have not been charged.")
  rescue PaymentGateway::Error => e
    render_bad_gateway("Payment gateway error: #{e.message}")
  end

end

class ReportsController < ApplicationController

  def generate
    ReportJob.perform_later(current_user.id, params[:type])
    render_accepted(
      data: { estimated_time: "2 minutes" },
      message: "Report is being generated. We will email you when it is ready."
    )
    # → 202
  end

end
```

---

## Quick Reference Card

```ruby
# 2xx — Success
render_success(data:, message:, meta:, pagy:, pagination:,code: , status:)
render_ok(data:, message:, meta:, pagination:)
render_created(data:, message:, pagination:)
render_accepted(data:, message:)
render_no_content(message:)
render_partial_content(data:, message:, meta:)
render_multi_status(data:, message:, meta:)

# 4xx — Client Errors
render_bad_request(message, errors:, code:)
render_unauthorized(message, code:)
render_payment_required(message, code:)
render_forbidden(message, code:)
render_not_found(message, code:)
render_method_not_allowed(message, code:)
render_not_acceptable(message, code:)
render_request_timeout(message, code:)
render_conflict(message, errors:, code:)
render_gone(message, code:)
render_precondition_failed(message, code:)
render_unsupported_media_type(message, code:)
render_unprocessable(message, errors:)
render_locked(message, code:)
render_too_many_requests(message, code:)

# 5xx — Server Errors
render_server_error(message, code:)
render_not_implemented(message, code:)
render_bad_gateway(message, code:)
render_service_unavailable(message, code:)
render_gateway_timeout(message, code:)
```

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
render_ok(data: users)
# meta.pagination is populated automatically
```

### Pagy

```ruby
pagy, users = pagy(User.all)
render_ok(data: users, pagy: pagy)
```

### WillPaginate

```ruby
users = User.paginate(page: params[:page], per_page: 25)
render_ok(data: users)
```

### Suppress pagination

```ruby
# Even if the collection is paginated, hide the meta
render_ok(data: users, pagination: false)
```

---

## camelCase for Flutter / JavaScript

```ruby
Respondo.configure { |c| c.camelize_keys = true }
```

All keys in the response — including nested `meta.pagination` — are camelized:
`current_page` → `currentPage`, `total_count` → `totalCount`, `error_code` → `errorCode`.

### Flutter Integration

```dart
// Every response follows the same shape
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final Map<String, dynamic> meta;
  final Map<String, dynamic>? errors;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    required this.meta,
    this.errors,
  });
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
    ├── controller_helpers.rb      # All render_* helpers (2xx, 4xx, 5xx)
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
