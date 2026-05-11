<div align="center">

# Respondo 🎯

**Consistent JSON API responses for Rails — in one line.**

[![Gem Version](https://badge.fury.io/rb/respondo.svg)](https://rubygems.org/gems/respondo)
[![Downloads](https://img.shields.io/gem/dt/respondo.svg)](https://rubygems.org/gems/respondo)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-2.7%2B-red)](https://www.ruby-lang.org/)

</div>

---

## The problem every Rails API developer hits

You're building an API consumed by a React frontend and a Flutter app. Three developers on your team. Three different response shapes:

```json
// Developer A
{ "data": [...], "status": "ok" }

// Developer B
{ "result": [...], "success": true }

// Developer C
{ "users": [...] }
```

Your frontend devs are writing `if (res.data || res.result || res.users)`. Your Flutter devs are filing bugs. Your code reviews are arguments.

**Respondo fixes this permanently.** One response shape. Every controller. Every developer. Every time.

```json
{
  "success": true,
  "message": "Users fetched",
  "data": [...],
  "meta": {
    "timestamp": "2024-06-15T10:30:00Z",
    "pagination": { "currentPage": 1, "totalPages": 4, "totalCount": 98 }
  }
}
```

---

## Install

```ruby
# Gemfile
gem "respondo"
```

```bash
bundle install
rails generate respondo:install
```

That's it. No `include` in `ApplicationController`. No boilerplate. Respondo auto-injects via Railtie.

---

## Your first response (30 seconds)

```ruby
class UsersController < ApplicationController
  def index
    render_ok(data: User.all, message: "Users fetched")
  end

  def create
    user = User.new(user_params)
    if user.save
      render_created(data: user, message: "Account created")
    else
      render_unprocessable(message: "Validation failed", errors: user.errors)
    end
  end

  def show
    render_ok(data: User.find(params[:id]), message: "User found")
  rescue ActiveRecord::RecordNotFound
    render_not_found(message: "User not found")
  end
end
```

Your frontend now gets a **guaranteed** structure — forever.

---

## Why teams switch to Respondo

| Without Respondo | With Respondo |
|---|---|
| Each dev invents their own response format | One standard, enforced automatically |
| Frontend code full of defensive `||` checks | `response.data` always works |
| Pagination shape differs per endpoint | Pagination always in `meta.pagination` |
| Validation errors in different keys | Always in `errors`, always a hash |
| `render json:` boilerplate in every action | One expressive method call |
| camelCase conversion scattered across code | `config.camelize_keys = true` — done |

---

## What every response looks like

Every response — success or error — has the same four keys:

| Key | Type | Description |
|---|---|---|
| `success` | Boolean | `true` or `false` — always present |
| `message` | String | Human-readable description |
| `data` | Object / Array / nil | The payload |
| `meta` | Object | Timestamp + pagination + optional `request_id` |

Error responses additionally include `errors` — a hash of `{ field: ["message"] }`.

**Success:**
```json
{
  "success": true,
  "message": "Post published",
  "data": { "id": 42, "title": "Hello World" },
  "meta": { "timestamp": "2024-06-15T10:30:00Z" }
}
```

**Validation error:**
```json
{
  "success": false,
  "message": "Validation failed",
  "data": null,
  "errors": { "email": ["is invalid"], "name": ["can't be blank"] },
  "meta": { "timestamp": "2024-06-15T10:30:00Z" }
}
```

---

## Real-world controller (with pagination)

```ruby
class PostsController < ApplicationController

  def index
    @posts = Post.published.page(params[:page]).per(params[:per_page] || 20)

    render_ok(
      data:    @posts,
      message: "Posts fetched",
      pagination: {
        current_page: @posts.current_page,
        next_page:    @posts.next_page,
        prev_page:    @posts.prev_page,
        total_pages:  @posts.total_pages,
        total_count:  @posts.total_count,
        per_page:     @posts.limit_value
      }
    )
  end

  def create
    @post = current_user.posts.build(post_params)

    if @post.save
      render_created(data: @post, message: "Post published")
    else
      render_unprocessable(message: "Could not create post", errors: @post.errors)
    end
  end

  def update
    @post = Post.find(params[:id])

    return render_forbidden(message: "Not your post") unless @post.user == current_user

    if @post.update(post_params)
      render_ok(data: @post, message: "Post updated")
    else
      render_unprocessable(message: "Update failed", errors: @post.errors)
    end
  rescue ActiveRecord::RecordNotFound
    render_not_found(message: "Post not found")
  end

end
```

## Auto-Serialization

Respondo automatically handles:

| Input type                       | Output                              |
|----------------------------------|-------------------------------------|
| `ActiveRecord::Base` instance    | `record.as_json`                    |
| `ActiveRecord::Relation`         | Array of `as_json` records          |
| `ActiveModel::Errors`            | `{ field: ["message", ...] }`       |
| `Hash`                           | Passed through (values serialized)  |
| `Array`                          | Each element serialized recursively |
| `Exception`                      | `{ message: e.message }`            |
| Anything with `#as_json`         | `.as_json`                          |
| Anything with `#to_h`            | `.to_h`                             |
| Primitives (String, Integer...)  | As-is                               |

---

## Configuration

Run the interactive generator — it walks you through every option:

```bash
rails generate respondo:install
```

Or write it manually:

```ruby
# config/initializers/respondo.rb
Respondo.configure do |config|
  config.default_success_message = "OK"
  config.default_error_message   = "Something went wrong"
  config.include_request_id      = true   # adds request_id to every meta
  config.camelize_keys           = true   # snake_case → camelCase (Flutter/JS friendly)
  config.default_meta            = { api_version: "v1" }
end
```

### camelCase output (great for Flutter / React Native)

```ruby
config.camelize_keys = true
```

```json
{
  "success": true,
  "data": { "firstName": "Alice", "createdAt": "2024-01-01" },
  "meta": { "totalPages": 4, "currentPage": 1 }
}
```

### Custom serializer

```ruby
config.serializer = ->(obj) { MySerializer.new(obj).as_json }
```

---

## Global error handling (recommended pattern)

Add this to `ApplicationController` to handle exceptions app-wide without try/rescue in every action:

```ruby
class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do |e|
    render_not_found(message: e.message)
  end

  rescue_from ActionController::ParameterMissing do |e|
    render_bad_request(message: e.message)
  end

  rescue_from StandardError do |e|
    Rails.logger.error(e.full_message)
    render_server_error(message: "An unexpected error occurred")
  end
end
```

---

## Complete HTTP helper reference

Respondo covers every HTTP status code. Here are the helpers you'll use every day:

### 2xx — Success

| Helper | Status | When to use |
|---|---|---|
| `render_ok` | 200 | Standard success |
| `render_created` | 201 | After POST creates a resource |
| `render_accepted` | 202 | Async jobs — request queued |
| `render_no_content` | 200* | After DELETE — no body |

> *Rails renders 200 with a JSON body for `render_no_content` to preserve consistent structure.

```ruby
render_ok(data: @user, message: "Profile fetched")
render_created(data: @order, message: "Order placed")
render_accepted(data: { job_id: "abc123" }, message: "Export queued — you'll get an email")
render_no_content(message: "Account deleted")
```

### 4xx — Client errors

| Helper | Status | When to use |
|---|---|---|
| `render_bad_request` | 400 | Malformed input |
| `render_unauthorized` | 401 | Not logged in / token expired |
| `render_forbidden` | 403 | Logged in but not allowed |
| `render_not_found` | 404 | Record doesn't exist |
| `render_conflict` | 409 | Duplicate (e.g. email taken) |
| `render_unprocessable` | 422 | Validation errors |
| `render_too_many_requests` | 429 | Rate limiting |

```ruby
render_unauthorized(message: "Token has expired", errors: { token: ["has expired"] })
render_forbidden(message: "You can only edit your own posts")
render_not_found(message: "User ##{params[:id]} not found")
render_unprocessable(message: "Validation failed", errors: user.errors)
render_conflict(message: "Email already registered", errors: { email: ["has already been taken"] })
render_too_many_requests(message: "Slow down — 100 req/min max", meta: { retry_after: 60 })
```

### 5xx — Server errors

```ruby
render_server_error(message: "Something went wrong. Our team has been notified.")
render_service_unavailable(message: "Down for maintenance. Back in 30 minutes.", meta: { retry_after: 1800 })
render_bad_gateway(message: "Payment processor is unreachable — you have not been charged")
```

<details>
<summary><strong>Full list of all helpers (click to expand)</strong></summary>

#### 1xx — Informational
`render_continue` · `render_switching_protocols` · `render_processing` · `render_early_hints`

#### 2xx — Success
`render_ok` · `render_created` · `render_accepted` · `render_non_authoritative` · `render_no_content` · `render_reset_content` · `render_partial_content` · `render_multi_status` · `render_already_reported` · `render_im_used`

#### 3xx — Redirect
`render_multiple_choices` · `render_moved_permanently` · `render_found` · `render_see_other` · `render_not_modified` · `render_temporary_redirect` · `render_permanent_redirect`

#### 4xx — Client Error
`render_bad_request` · `render_unauthorized` · `render_payment_required` · `render_forbidden` · `render_not_found` · `render_method_not_allowed` · `render_not_acceptable` · `render_proxy_auth_required` · `render_request_timeout` · `render_conflict` · `render_gone` · `render_length_required` · `render_precondition_failed` · `render_payload_too_large` · `render_uri_too_long` · `render_unsupported_media_type` · `render_range_not_satisfiable` · `render_expectation_failed` · `render_im_a_teapot` · `render_misdirected_request` · `render_unprocessable` · `render_locked` · `render_failed_dependency` · `render_too_early` · `render_upgrade_required` · `render_precondition_required` · `render_too_many_requests` · `render_request_header_fields_too_large` · `render_unavailable_for_legal_reasons`

#### 5xx — Server Error
`render_server_error` · `render_not_implemented` · `render_bad_gateway` · `render_service_unavailable` · `render_gateway_timeout` · `render_http_version_not_supported` · `render_variant_also_negotiates` · `render_insufficient_storage` · `render_loop_detected` · `render_not_extended` · `render_network_authentication_required`

</details>

---

## Testing your responses

Respondo ships with test helpers for RSpec and Minitest so you can assert on response structure directly.

### RSpec

```ruby
# spec/rails_helper.rb
require "respondo/testing/rspec"

RSpec.describe UsersController, type: :request do
  describe "GET /users" do
    it "returns a success response" do
      get "/users"
      expect(response).to be_respondo_success
      expect(response).to have_respondo_message("Users fetched")
    end
  end

  describe "POST /users with invalid params" do
    it "returns validation errors" do
      post "/users", params: { user: { email: "" } }
      expect(response).to be_respondo_error
      expect(response).to have_respondo_errors(:email)
    end
  end
end
```

### Minitest

```ruby
# test/test_helper.rb
require "respondo/testing/minitest"

class UsersControllerTest < ActionDispatch::IntegrationTest
  def test_index_returns_success
    get users_url
    assert_respondo_success response
    assert_respondo_message "Users fetched", response
  end
end
```

---

## What's next

- [ ] ActiveModelSerializers / Blueprinter auto-integration
- [ ] OpenAPI / Swagger schema generation from Respondo helpers
- [ ] Rack middleware for zero-config global exception handling

Have a feature idea? [Open an issue →](https://github.com/spatelpatidar/respondo/issues)

---

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/spatelpatidar/respondo).

```bash
git clone https://github.com/spatelpatidar/respondo
cd respondo
bundle install
bundle exec rspec
```

---

## License

Released under the [MIT License](LICENSE).

---

<div align="center">
  <sub>If Respondo saved you an hour, give it a ⭐ — it helps other developers find it.</sub>
</div>