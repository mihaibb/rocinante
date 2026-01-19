# Coding Style Guide for LLMs

This guide provides detailed conventions and patterns for AI coding assistants working on this Ruby on Rails codebase. Follow these patterns to produce idiomatic, consistent code.

---

## Table of Contents

1. [Ruby Conventions](#ruby-conventions)
2. [Rails Model Patterns](#rails-model-patterns)
3. [Controller Patterns](#controller-patterns)
4. [View Patterns](#view-patterns)
5. [JavaScript/Stimulus Patterns](#javascriptstimulus-patterns)
6. [Testing Patterns](#testing-patterns)
7. [Background Jobs](#background-jobs)
8. [Database Conventions](#database-conventions)

---

## Ruby Conventions

### Conditional Returns

Prefer expanded conditionals over guard clauses in most cases:

```ruby
# ✗ Avoid guard clauses
def todos_for_new_group
  ids = params.require(:todolist)[:todo_ids]
  return [] unless ids
  @bucket.recordings.todos.find(ids.split(","))
end

# ✓ Prefer expanded conditionals
def todos_for_new_group
  if ids = params.require(:todolist)[:todo_ids]
    @bucket.recordings.todos.find(ids.split(","))
  else
    []
  end
end
```

**Exception**: Guard clauses are acceptable when:
- The return is at the very beginning of the method
- The main method body is non-trivial (several lines)

```ruby
# ✓ Acceptable guard clause
def after_recorded_as_commit(recording)
  return if recording.parent.was_created?

  if recording.was_created?
    broadcast_new_column(recording)
  else
    broadcast_column_change(recording)
  end
end
```

### Method Ordering

Order methods in classes as follows:

1. Class methods (`class << self` or `self.method_name`)
2. Public instance methods (with `initialize` at the top)
3. Private methods

```ruby
class Account < ApplicationRecord
  class << self
    def create_with_owner(account:, owner:)
      # ...
    end
  end

  def slug
    "/#{AccountSlug.encode(external_account_id)}"
  end

  def system_user
    users.find_by!(role: :system)
  end

  private
    def assign_external_account_id
      self.external_account_id ||= ExternalIdSequence.next
    end
end
```

### Invocation Order

Order private methods vertically based on their invocation order:

```ruby
class SomeClass
  def some_method
    method_1
    method_2
  end

  private
    def method_1
      method_1_1
      method_1_2
    end

    def method_1_1
      # ...
    end

    def method_1_2
      # ...
    end

    def method_2
      method_2_1
      method_2_2
    end

    def method_2_1
      # ...
    end

    def method_2_2
      # ...
    end
end
```

### Visibility Modifiers

- No newline under `private`/`protected` keywords
- Indent content under visibility modifiers by 2 additional spaces

```ruby
class SomeClass
  def public_method
    # ...
  end

  private
    def some_private_method_1
      # ...
    end

    def some_private_method_2
      # ...
    end
end
```

For modules with only private methods, mark `private` at top with a blank line after, no extra indent:

```ruby
module SomeModule
  private

  def some_private_method
    # ...
  end
end
```

### Bang Methods (`!`)

Only use `!` for methods that have a corresponding non-bang counterpart. Do NOT use `!` to flag destructive actions:

```ruby
# ✗ Don't use ! just because it's destructive
def delete_all!
  # ...
end

# ✓ Use ! only when there's a non-bang alternative
def save   # returns false on failure
def save!  # raises on failure
```

---

## Rails Model Patterns

### Concerns Organization

Use model-specific concerns in subdirectories matching the model name:

```
app/models/
├── card.rb
├── card/
│   ├── assignable.rb
│   ├── broadcastable.rb
│   ├── closeable.rb
│   ├── eventable.rb
│   └── ...
├── concerns/           # Shared concerns across models
│   ├── eventable.rb
│   ├── mentions.rb
│   └── searchable.rb
```

### Concern Structure

```ruby
module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy

    scope :closed, -> { joins(:closure) }
    scope :open, -> { where.missing(:closure) }
  end

  def closed?
    closure.present?
  end

  def close(user: Current.user)
    unless closed?
      transaction do
        create_closure! user: user
        track_event :closed, creator: user
      end
    end
  end

  def reopen(user: Current.user)
    if closed?
      transaction do
        closure&.destroy
        track_event :reopened, creator: user
      end
    end
  end
end
```

### Include Many Concerns on One Line

When a model includes many concerns, list them on a single `include` line with line continuation:

```ruby
class Card < ApplicationRecord
  include Assignable, Attachments, Broadcastable, Closeable, Colored, Entropic, Eventable,
    Exportable, Golden, Mentions, Multistep, Pinnable, Postponable, Promptable,
    Readable, Searchable, Stallable, Statuses, Taggable, Triageable, Watchable
```

### Belongs_to with Defaults

Use lambdas for dynamic defaults:

```ruby
belongs_to :account, default: -> { board.account }
belongs_to :creator, class_name: "User", default: -> { Current.user }
```

### Scope Naming Conventions

Use descriptive, query-like scope names:

```ruby
scope :reverse_chronologically, -> { order created_at: :desc, id: :desc }
scope :chronologically,         -> { order created_at: :asc,  id: :asc  }
scope :latest,                  -> { order last_active_at: :desc, id: :desc }
scope :with_users,              -> { preload(creator: [...]) }
scope :preloaded,               -> { with_users.preload(...) }

# Boolean state scopes
scope :closed, -> { joins(:closure) }
scope :open,   -> { where.missing(:closure) }

# Parameterized scopes
scope :indexed_by, ->(index) do
  case index
  when "stalled" then stalled
  when "closed" then closed
  else all
  end
end
```

### Delegation

Use delegation for clean API design:

```ruby
delegate :accessible_to?, to: :board
delegate :identity, to: :session, allow_nil: true
```

### Event Tracking Pattern

Track significant actions with the `track_event` method:

```ruby
def close(user: Current.user)
  unless closed?
    transaction do
      create_closure! user: user
      track_event :closed, creator: user
    end
  end
end

def track_event(action, creator: Current.user, board: self.board, **particulars)
  if should_track_event?
    board.events.create!(
      action: "#{eventable_prefix}_#{action}",
      creator:,
      board:,
      eventable: self,
      particulars:
    )
  end
end
```

### Model Callbacks

Use lambdas for simple callbacks, named methods for complex ones:

```ruby
# Simple callbacks with lambdas
after_save   -> { board.touch }, if: :published?
after_touch  -> { board.touch }, if: :published?
after_create -> { eventable.event_was_created(self) }

# Complex callbacks with named methods
after_update :handle_board_change, if: :saved_change_to_board_id?

private
  def handle_board_change
    old_board = account.boards.find_by(id: board_id_before_last_save)

    transaction do
      update! column: nil
      track_board_change_event(old_board.name)
      grant_access_to_assignees unless board.all_access?
    end

    remove_inaccessible_notifications_later
  end
```

---

## Controller Patterns

### CRUD Controllers with Resources

Model web endpoints as CRUD operations on resources (REST). When an action doesn't map cleanly to a standard CRUD verb, introduce a new resource:

```ruby
# ✗ Avoid custom actions
resources :cards do
  post :close
  post :reopen
end

# ✓ Introduce sub-resources
resources :cards do
  resource :closure
end
```

### Controller Structure

```ruby
class Cards::ClosuresController < ApplicationController
  include CardScoped

  def create
    @card.close
    render_card_replacement
  end

  def destroy
    @card.reopen
    render_card_replacement
  end
end
```

### Controller Concerns for Scoping

Use concerns to set up common before_actions:

```ruby
# app/controllers/concerns/card_scoped.rb
module CardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_card, :set_board
  end

  private
    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    end

    def set_board
      @board = @card.board
    end

    def render_card_replacement
      render turbo_stream: turbo_stream.replace(
        [@card, :card_container],
        partial: "cards/container",
        method: :morph,
        locals: { card: @card.reload }
      )
    end
end
```

### Strong Parameters

Use `params.expect` for required nested params:

```ruby
def card_params
  params.expect(card: [:status, :title, :description, :image, tag_ids: []])
end

def comment_params
  params.expect(comment: :body)
end
```

### Authorization Patterns

Use before_action filters for authorization:

```ruby
before_action :set_card, only: %i[show edit update destroy]
before_action :ensure_permission_to_administer_card, only: %i[destroy]

private
  def ensure_permission_to_administer_card
    head :forbidden unless Current.user.can_administer_card?(@card)
  end
```

### Thin Controllers

Keep controllers thin; delegate complex logic to models:

```ruby
# ✓ Clean controller calling model methods
class Cards::GoldnessesController < ApplicationController
  include CardScoped

  def create
    @card.gild
    render_card_replacement
  end

  def destroy
    @card.ungild
    render_card_replacement
  end
end
```

---

## View Patterns

### Partial Organization

Organize partials in subdirectories matching the view structure:

```
app/views/cards/
├── show.html.erb
├── edit.html.erb
├── index.html.erb
├── update.turbo_stream.erb
├── _container.html.erb
├── _broadcasts.html.erb
├── container/
│   ├── _content.html.erb
│   ├── _footer/
│   │   ├── _draft.html.erb
│   │   └── _published.html.erb
│   └── _gild.html.erb
├── display/
│   ├── perma/
│   │   ├── _board.html.erb
│   │   └── _tags.html.erb
│   └── preview/
│       └── _bubble.html.erb
```

### Fragment Caching

Use `cache` blocks with models:

```erb
<% cache card do %>
  <section id="<%= dom_id(card, :card_container) %>">
    <!-- content -->
  </section>
<% end %>
```

### Turbo Stream Responses

Use `.turbo_stream.erb` files for Turbo Stream responses:

```erb
<%# update.turbo_stream.erb %>
<%= turbo_stream.replace dom_id(@card, :card_container),
      partial: "cards/container",
      method: :morph,
      locals: { card: @card.reload } %>

<%= turbo_stream.update dom_id(@card, :edit) do %>
  <%= render "cards/container/content_display", card: @card %>
<% end %>
```

### Turbo Streams for Broadcasting

Subscribe to model broadcasts in views:

```erb
<%= turbo_stream_from @card %>
<%= turbo_stream_from @card, :activity %>
```

### DOM ID Conventions

Use `dom_id` helper with prefixes for unique element IDs:

```erb
id="<%= dom_id(card, :card_container) %>"
id="<%= dom_id(card, :article) %>"
id="<%= dom_id(card, :edit) %>"
```

### Helper Methods

Keep helpers focused and named by domain:

```ruby
# app/helpers/cards_helper.rb
module CardsHelper
  def card_article_tag(card, id: dom_id(card, :article), data: {}, **options, &block)
    classes = [
      options.delete(:class),
      ("golden-effect" if card.golden?),
      ("card--postponed" if card.postponed?)
    ].compact.join(" ")

    tag.article id: id, class: classes, data: data, **options, &block
  end
end
```

### Content For Pattern

Use `content_for` for injecting content into layouts:

```erb
<% content_for :header do %>
  <div class="header__actions">
    <%= link_back_to_board(@card.board) %>
  </div>
<% end %>
```

---

## JavaScript/Stimulus Patterns

### Controller Structure

```javascript
import { Controller } from "@hotwired/stimulus"
import { submitForm } from "helpers/form_helpers"

const AUTOSAVE_INTERVAL = 3000

export default class extends Controller {
  #timer  // Private fields with #

  // Lifecycle methods first
  disconnect() {
    this.submit()
  }

  // Actions (public methods for data-action)
  async submit() {
    if (this.#dirty) {
      await this.#save()
    }
  }

  change(event) {
    if (event.target.form === this.element && !this.#dirty) {
      this.#scheduleSave()
    }
  }

  // Private methods at end
  #scheduleSave() {
    this.#timer = setTimeout(() => this.#save(), AUTOSAVE_INTERVAL)
  }

  async #save() {
    this.#resetTimer()
    await submitForm(this.element)
  }

  #resetTimer() {
    clearTimeout(this.#timer)
    this.#timer = null
  }

  get #dirty() {
    return !!this.#timer
  }
}
```

### Controller File Naming

Use `snake_case_controller.js` naming:

```
controllers/
├── auto_save_controller.js
├── drag_and_drop_controller.js
├── multi_selection_combobox_controller.js
```

### HTML Data Attributes

```erb
<div data-controller="beacon lightbox"
     data-beacon-url-value="<%= card_reading_path(@card) %>">
```

---

## Testing Patterns

### Test File Organization

Mirror app structure in test directories:

```
test/
├── models/
│   ├── card_test.rb
│   ├── card/
│   │   ├── closeable_test.rb
│   │   └── ...
├── controllers/
│   ├── cards_controller_test.rb
│   ├── cards/
│   │   ├── closures_controller_test.rb
│   │   └── ...
├── test_helpers/
│   ├── session_test_helper.rb
│   └── ...
```

### Test Setup Pattern

```ruby
require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "create assigns a number to the card" do
    user = users(:david)
    board = boards(:writebook)
    account = board.account
    card = nil

    assert_difference -> { account.reload.cards_count }, +1 do
      card = Card.create!(title: "Test", board: board, creator: user)
    end

    assert_equal account.reload.cards_count, card.number
  end
end
```

### Assertion Patterns

Use named assertions with blocks:

```ruby
# Multiple difference assertions
assert_difference({ -> { cards(:logo).assignees.count } => -1, -> { Event.count } => +1 }) do
  cards(:logo).toggle_assignment users(:kevin)
end

# Change assertions
assert_changes -> { cards(:logo).reload.triaged? }, from: true, to: false do
  cards(:logo).update! board: boards(:private)
end
```

### Controller Test Pattern

```ruby
require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get cards_path
    assert_response :success
  end

  test "update" do
    patch card_path(cards(:logo)), as: :turbo_stream, params: {
      card: {
        title: "Logo needs to change",
        image: fixture_file_upload("moon.jpg", "image/jpeg")
      }
    }
    assert_response :success

    assert_equal "Logo needs to change", cards(:logo).reload.title
  end
end
```

### Fixture Conventions

Use ERB for dynamic values in fixtures:

```yaml
# test/fixtures/cards.yml
logo:
  id: <%= ActiveRecord::FixtureSet.identify("logo", :uuid) %>
  number: 1
  board: writebook_uuid
  creator: david_uuid
  title: The logo isn't big enough
  created_at: <%= 1.week.ago %>
  status: published
  last_active_at: <%= 1.week.ago %>
  account: 37s_uuid
```

Reference fixtures with `_uuid` suffix for UUID foreign keys:

```yaml
board: writebook_uuid
creator: david_uuid
account: 37s_uuid
```

### Session Test Helper

```ruby
def sign_in_as(identity)
  cookies.delete :session_token

  if identity.is_a?(User)
    user = identity
    identity = user.identity
  elsif !identity.is_a?(Identity)
    identity = identities(identity)
  end

  identity.send_magic_link
  magic_link = identity.magic_links.order(id: :desc).first

  untenanted do
    post session_magic_link_url, params: { code: magic_link.code }
  end

  assert_response :redirect
end
```

---

## Background Jobs

### Job Structure

Keep jobs thin; delegate logic to models:

```ruby
class Event::WebhookDispatchJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :webhooks

  def perform(event)
    step :dispatch do |step|
      Webhook.active.triggered_by(event).find_each(start: step.cursor) do |webhook|
        webhook.trigger(event)
        step.advance! from: webhook.id
      end
    end
  end
end
```

### Async Method Naming Pattern

Use `_later` suffix for methods that enqueue jobs, `_now` for synchronous versions:

```ruby
module Event::Relaying
  extend ActiveSupport::Concern

  included do
    after_create_commit :relay_later
  end

  def relay_later
    Event::RelayJob.perform_later(self)
  end

  def relay_now
    # actual logic
  end
end

class Event::RelayJob < ApplicationJob
  def perform(event)
    event.relay_now
  end
end
```

### Job Organization

Organize jobs in subdirectories matching their domain:

```
app/jobs/
├── application_job.rb
├── event/
│   └── webhook_dispatch_job.rb
├── card/
│   └── remove_inaccessible_notifications_job.rb
├── notification/
│   └── ...
```

### Recurring Jobs Configuration

Use `config/recurring.yml` for scheduled tasks:

```yaml
production: &production
  deliver_bundled_notifications:
    command: "Notification::Bundle.deliver_all_later"
    schedule: every 30 minutes

  auto_postpone_all_due:
    command: "Card.auto_postpone_all_due"
    schedule: every hour at minute 50

  delete_unused_tags:
    class: DeleteUnusedTagsJob
    schedule: every day at 04:02
```

---

## Database Conventions

### UUID Primary Keys

All tables use UUIDs as primary keys (base36-encoded 25-character strings):

```ruby
# Migrations
create_table "cards", id: :uuid do |t|
  t.uuid "account_id", null: false
  t.uuid "board_id", null: false
  # ...
end
```

### Multi-Tenancy Column

Every table includes an `account_id` column for multi-tenancy:

```ruby
belongs_to :account, default: -> { board.account }
```

### Index Naming

Use descriptive composite index names:

```ruby
t.index ["account_id", "last_active_at", "status"],
  name: "index_cards_on_account_id_and_last_active_at_and_status"
```

### SQLite vs PostgreSQL

For new projects, prefer SQLite or PostgreSQL:

```yaml
# config/database.yml (SQLite)
default: &default
  adapter: sqlite3
  pool: 5
  timeout: 5000

development:
  primary:
    <<: *default
    database: storage/development.sqlite3
  cable:
    <<: *default
    database: storage/development_cable.sqlite3
  queue:
    <<: *default
    database: storage/development_queue.sqlite3
```

### Multiple Databases

Use separate SQLite databases for different purposes:

- `primary` - Main application data
- `cable` - Action Cable subscriptions
- `cache` - Solid Cache storage
- `queue` - Solid Queue jobs

---

## Current Attributes

Use `Current` for request-scoped attributes:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :account
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer

  delegate :identity, to: :session, allow_nil: true

  def with_account(value, &)
    with(account: value, &)
  end

  def without_account(&)
    with(account: nil, &)
  end
end
```

Access in models and controllers:

```ruby
belongs_to :creator, class_name: "User", default: -> { Current.user }

def close(user: Current.user)
  # ...
end
```

---

## Summary Checklist

When writing code for this project:

- [ ] Use expanded conditionals over guard clauses
- [ ] Order methods: class methods → public → private
- [ ] Indent private methods 2 extra spaces under `private` keyword
- [ ] Use concerns for shared behavior, organized in model subdirectories
- [ ] Model actions as CRUD on resources
- [ ] Keep controllers thin, delegate to models
- [ ] Use `params.expect` for strong parameters
- [ ] Organize partials in view subdirectories
- [ ] Use Turbo Streams for dynamic updates
- [ ] Structure Stimulus controllers: lifecycle → actions → private
- [ ] Mirror app structure in tests
- [ ] Use `_later`/`_now` naming for async operations
- [ ] Include `account_id` on all tables for multi-tenancy
- [ ] Use UUIDs for primary keys
- [ ] Access request scope via `Current` attributes
