# mihai-rails-style

This skill should be used when writing Ruby and Rails code in Mihai's distinctive style, which emphasizes the principles of simplicity and Rails conventions while embracing a practical, no-nonsense approach to modern tooling.

**Triggers:**
- Writing Ruby/Rails code
- Creating models, controllers, views, or any Rails file
- Ruby/Rails code generation or refactoring
- Code review requests for Rails code
- When the user mentions "my style", "simple Rails", or "practical Rails"

---

## Core Philosophy

### Simplicity Over Cleverness

Write code that a junior developer can understand. Every line should be obvious.

```ruby
# Good - obvious intent
def active_clients
  clients.where(active: true)
end

# Bad - clever but obscure
def active_clients
  clients.select(&:active?)
end
```

### Rails Conventions First

Don't fight Rails. Use its conventions even when you think you know better.

```ruby
# Good - Rails convention
class ClientsController < ApplicationController
  def index
    @clients = Current.organization.clients
  end
end

# Bad - fighting Rails
class ClientController < BaseController  # Singular, custom base
  def list  # Non-standard action name
    @data = ClientService.fetch_all
  end
end
```

### Minimal Dependencies

Before adding a gem, ask: "Can Rails do this already?"

```ruby
# Good - Rails built-in
has_secure_password
normalizes :email, with: -> { _1.strip.downcase }

# Avoid - unnecessary gems for things Rails handles
gem 'devise'  # unless you truly need its complexity
gem 'strip_attributes'
```

---

## Controller Patterns

### Thin Controllers, Fat Models

Controllers orchestrate. Models contain business logic.

```ruby
# Good - controller orchestrates
def create
  @client = Current.organization.clients.new(client_params)

  if @client.save
    track_activity(:client_created, @client)
    redirect_to @client, notice: t(".created")
  else
    render :new, status: :unprocessable_entity
  end
end

# Bad - business logic in controller
def create
  @client = Client.new(client_params)
  @client.organization = Current.organization
  @client.slug = @client.name.parameterize
  @client.generate_reference_number
  @client.send_welcome_email if @client.email.present?
  # ...
end
```

### Always Scope Through Current.organization

Multi-tenant isolation is non-negotiable.

```ruby
# Good - scoped through organization
Current.organization.clients.find(params[:id])
Current.organization.contacts.alphabetically

# Bad - manual scoping
Client.where(organization_id: Current.organization.id).find(params[:id])
```

### Use before_action for Setup

```ruby
class ClientsController < ApplicationController
  before_action :set_client, only: [:show, :edit, :update, :destroy]

  private

  def set_client
    @client = Current.organization.clients.find_by!(slug: params[:id])
  end
end
```

---

## Model Patterns

### Validation at Model Level

```ruby
class Client < ApplicationRecord
  belongs_to :organization

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :organization_id }

  normalizes :name, with: -> { _1.strip }
  normalizes :email, with: -> { _1&.strip&.downcase }
end
```

### Scopes for Common Queries

```ruby
class Client < ApplicationRecord
  scope :active, -> { where(active: true) }
  scope :alphabetically, -> { order(:name) }
  scope :recent, -> { order(created_at: :desc) }
end
```

### Range Syntax for Date Queries

```ruby
# Good - Ruby range syntax
where(created_at: Time.current.beginning_of_day..)
where(created_at: 1.week.ago..)
where(created_at: start_date..end_date)

# Bad - string SQL
where("created_at >= ?", Time.current.beginning_of_day)
```

### Enums with Explicit Values and Prefix

```ruby
enum :status, {
  draft: "draft",
  published: "published",
  archived: "archived"
}, prefix: true

# Usage: record.status_published?, Record.status_published
```

---

## View Patterns

### Hotwire First

Use Turbo Frames and Streams before reaching for JavaScript.

```erb
<%# Turbo Frame for inline editing %>
<%= turbo_frame_tag dom_id(@client) do %>
  <%= render @client %>
<% end %>

<%# Form that updates via Turbo Stream %>
<%= form_with model: @client, data: { turbo_frame: "_top" } do |form| %>
  ...
<% end %>
```

### Partials for Everything

Extract sections into partials. Keep views flat.

```erb
<%# Good - clean show page %>
<div class="grid grid-cols-3 gap-6">
  <%= render "info", client: @client %>
  <%= render "contacts", client: @client %>
  <%= render "activity", client: @client %>
</div>

<%# Bad - everything in one file %>
<div class="grid grid-cols-3 gap-6">
  <div class="card">
    <%# 50 lines of info HTML %>
  </div>
  <div class="card">
    <%# 80 lines of contacts HTML %>
  </div>
</div>
```

### Pass Variables Explicitly

```erb
<%# Good - explicit %>
<%= render "members", client: @client %>

<%# Bad - implicit instance variable in partial %>
<%= render "members" %>
```

### I18n for All User-Facing Text

```erb
<%# Good %>
<%= t(".created") %>
<%= button_tag t("actions.save") %>

<%# Bad %>
<%= "Client created successfully" %>
```

---

## JavaScript/Stimulus Patterns

### Stimulus for Behavior, Not State

Keep Stimulus controllers small and focused.

```javascript
// Good - single responsibility
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
```

### Data Attributes for Configuration

```erb
<div data-controller="countdown"
     data-countdown-seconds-value="60">
</div>
```

### Let Turbo Handle Navigation

Don't write JavaScript for page transitions.

```erb
<%# Good - Turbo handles this automatically %>
<%= link_to "View", @client %>

<%# Bad - manual fetch and DOM manipulation %>
<a href="#" onclick="fetchAndRender('/clients/1')">View</a>
```

**Exception: Clickable Table Rows**

Since you can't wrap a `<tr>` in an `<a>` tag, use a small Stimulus controller:

```javascript
// app/javascript/controllers/row_link_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  visit() {
    Turbo.visit(this.urlValue)
  }
}
```

```erb
<tr data-controller="row-link"
    data-row-link-url-value="<%= client_path(client) %>"
    data-action="click->row-link#visit"
    class="cursor-pointer hover:bg-stone-50">
  <td><%= client.name %></td>
  <td><%= client.email %></td>
</tr>
```

---

## Testing Patterns

### Minitest, Not RSpec

Rails default is good enough.

```ruby
class ClientTest < ActiveSupport::TestCase
  test "client requires name" do
    client = Client.new(organization: organizations(:one))

    assert_not client.valid?
    assert_includes client.errors[:name], I18n.t("errors.messages.blank")
  end
end
```

### I18n in Error Assertions

```ruby
# Good - locale independent
assert_includes errors[:name], I18n.t("errors.messages.blank")

# Bad - hardcoded
assert_includes errors[:name], "can't be blank"
```

### Fixtures Over Factories

```yaml
# test/fixtures/clients.yml
one:
  organization: one
  name: Acme Corp
  slug: acme-corp
```

---

## Code Organization

### Logical Spacing

Group related code. Separate distinct operations.

```ruby
def update
  @client = Current.organization.clients.find_by!(slug: params[:id])
  previous_name = @client.name

  if @client.update(client_params)
    track_activity(:client_updated, @client)

    redirect_to @client, notice: t(".updated")
  else
    render :edit, status: :unprocessable_entity
  end
end
```

### Method Organization

```ruby
class Client < ApplicationRecord
  # associations
  belongs_to :organization

  # validations
  validates :name, presence: true

  # scopes
  scope :active, -> { where(active: true) }

  # class methods
  class << self
    def search(query)
      where("name ILIKE ?", "%#{query}%")
    end

    def status_options
      statuses.keys.map { |s| [I18n.t("clients.statuses.#{s}"), s] }
    end
  end

  # public instance methods
  def display_name
    name.titleize
  end

  private

  # private methods
  def generate_slug
    self.slug = name.parameterize
  end
end
```

---

## Practical Modern Tooling

While DHH advocates for import maps and no-build, this style embraces practical simplicity:

### When to Use Build Tools

- **Use esbuild** when you need NPM packages (Stimulus, Turbo, ActionText)
- **Use Tailwind CLI** for CSS - it's fast and simple
- Keep `package.json` minimal - only what you actually need

### When to Avoid Build Tools

- Don't add Webpack, Vite, or complex bundlers
- Don't use React/Vue/Svelte unless you truly need them
- Don't add TypeScript for Rails apps

### The Right Amount of JavaScript

```javascript
// All the JS you usually need:
import "@hotwired/turbo-rails"
import "controllers"
```

---

## Anti-Patterns to Avoid

### Service Objects for Everything

```ruby
# Bad - generic service objects
ClientCreationService.new(params).call
CreateClientService.call(params)

# Good - just use the model
Client.create!(client_params)

# Good - when model isn't enough, use a namespaced builder
Client::Builder.new(params).create
```

When creation logic is complex (multiple associated records, external API calls, etc.), use a builder class namespaced under the model:

```ruby
# app/models/client/builder.rb
class Client::Builder
  def initialize(params, organization:)
    @params = params
    @organization = organization
  end

  def create
    Client.transaction do
      client = @organization.clients.create!(@params.slice(:name, :email))
      client.contacts.create!(@params[:primary_contact]) if @params[:primary_contact]
      client
    end
  end
end
```

### Dependency Injection

```ruby
# Bad - Java patterns in Ruby
def initialize(repository: ClientRepository.new)
  @repository = repository
end

# Good - use Rails
def index
  @clients = Current.organization.clients
end
```

### Over-Engineered Patterns

```ruby
# Bad - design patterns gone wrong
module Clients
  class CreateCommand < BaseCommand
    include Validatable
    include Publishable
    # ...
  end
end

# Good - plain Ruby
class Client < ApplicationRecord
  # model code
end
```

---

## Summary: The Mihai Way

1. **Use Rails conventions** - they exist for good reasons
2. **Keep it simple** - if a junior can't understand it, simplify it
3. **Scope everything** - `Current.organization` is your friend
4. **Hotwire first** - Turbo Frames and Streams before custom JS
5. **Extract partials** - views should be flat and readable
6. **Test with Minitest** - fixtures, I18n assertions, simple tests
7. **Minimal dependencies** - Rails probably has what you need
8. **Practical tooling** - esbuild + Tailwind CLI is fine, just keep it simple
