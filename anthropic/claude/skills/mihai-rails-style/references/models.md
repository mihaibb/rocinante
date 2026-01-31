# Models - Mihai Rails Style

<method_organization>
## Method Organization

Follow this order in model files:

```ruby
class Client < ApplicationRecord
  # 1. associations
  belongs_to :organization
  has_many :contacts
  has_many :affiliations

  # 2. validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :organization_id }

  # 3. normalizes
  normalizes :name, with: -> { _1.strip }
  normalizes :email, with: -> { _1&.strip&.downcase }

  # 4. scopes
  scope :active, -> { where(active: true) }
  scope :alphabetically, -> { order(:name) }
  scope :recent, -> { order(created_at: :desc) }

  # 5. class methods (using class << self)
  class << self
    def search(query)
      where("name ILIKE ?", "%#{query}%")
    end

    def status_options
      statuses.keys.map { |s| [I18n.t("clients.statuses.#{s}"), s] }
    end
  end

  # 6. public instance methods
  def display_name
    name.titleize
  end

  def active?
    active_at.present?
  end

  private

  # 7. private methods
  def generate_slug
    self.slug = name.parameterize
  end
end
```
</method_organization>

<validations>
## Validations

Keep validations at the model level.

```ruby
class Client < ApplicationRecord
  belongs_to :organization

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :slug, presence: true, uniqueness: { scope: :organization_id }
end
```

Use database constraints for data integrity:
```ruby
# migration
add_index :clients, [:organization_id, :slug], unique: true
add_foreign_key :clients, :organizations
```
</validations>

<normalizes>
## Normalizes

Use `normalizes` for data cleaning before validation.

```ruby
class User < ApplicationRecord
  normalizes :email, with: -> { _1.strip.downcase }
  normalizes :phone, with: -> { _1&.gsub(/\D/, "") }
  normalizes :name, with: -> { _1.strip }
end
```

Benefits:
- Runs before validation
- Consistent data format
- No callbacks needed
</normalizes>

<scopes>
## Scopes

Standard scope naming conventions:

```ruby
class Client < ApplicationRecord
  # Boolean state
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Ordering
  scope :alphabetically, -> { order(:name) }
  scope :recent, -> { order(created_at: :desc) }
  scope :chronologically, -> { order(created_at: :asc) }

  # Eager loading
  scope :preloaded, -> { includes(:contacts, :affiliations) }

  # Parameterized
  scope :created_after, ->(date) { where(created_at: date..) }
  scope :status, ->(status) { where(status: status) }
end
```
</scopes>

<date_queries>
## Range Syntax for Date Queries

Use Ruby range syntax instead of SQL strings.

```ruby
# Good - Ruby range syntax
where(created_at: Time.current.beginning_of_day..)
where(created_at: 1.week.ago..)
where(created_at: start_date..end_date)
where(created_at: ..Time.current)  # before now

# Bad - string SQL
where("created_at >= ?", Time.current.beginning_of_day)
where("created_at >= ? AND created_at <= ?", start_date, end_date)
```

Range types:
- `value..` - greater than or equal
- `..value` - less than or equal
- `start..end` - between (inclusive)
</date_queries>

<enums>
## Enums with Explicit Values and Prefix

Always use explicit string values and `prefix: true`.

```ruby
class Document < ApplicationRecord
  enum :status, {
    draft: "draft",
    published: "published",
    archived: "archived"
  }, prefix: true
end
```

This gives you:
```ruby
# Scopes (prefixed)
Document.status_draft
Document.status_published

# Predicates (prefixed)
document.status_draft?
document.status_published?

# Setters (prefixed)
document.status_published!
```

**Always use `prefix: true`** to:
- Avoid method name conflicts
- Make code more readable
- Clarify which attribute is being queried

For form selects, create a class method:
```ruby
class << self
  def status_options
    statuses.keys.map { |s| [I18n.t("documents.statuses.#{s}"), s] }
  end
end
```
</enums>

<class_methods>
## Class Methods with class << self

Group class methods using `class << self` block.

```ruby
class Client < ApplicationRecord
  # ... associations, validations, scopes ...

  class << self
    def search(query)
      return all if query.blank?
      where("name ILIKE ?", "%#{query}%")
    end

    def status_options
      statuses.keys.map { |s| [I18n.t("clients.statuses.#{s}"), s] }
    end

    def import_from_csv(file)
      # ...
    end
  end
end
```

Benefits:
- Clear visual grouping
- Easier to scan
- Consistent style
</class_methods>

<namespaced_builders>
## Namespaced Builders

When model creation is complex, use a builder class namespaced under the model.

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

# Usage in controller
Client::Builder.new(client_params, organization: Current.organization).create
```

Use builders when:
- Creating multiple associated records
- Complex validation logic
- External API calls during creation
</namespaced_builders>


<concernable>
## Concernable Models

For records that can be associated with multiple models, use a `Concernable` pattern.

```ruby
# app/models/label.rb
class Label < ApplicationRecord
  COLORS = %w[stone sky blue purple green orange yellow red pink].freeze

  has_many :labelings, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :color, presence: true, inclusion: { in: COLORS }
end

# app/models/labeling.rb
class Labeling < ApplicationRecord
  belongs_to :label
  belongs_to :labelable, polymorphic: true

  validates :label_id, uniqueness: { scope: [ :labelable_type, :labelable_id ] }
end

# app/models/concerns/labelable.rb
module Labelable
  extend ActiveSupport::Concern

  included do
    has_many :labelings, as: :labelable, dependent: :destroy
    has_many :labels, through: :labelings
  end

  def labeled_with?(label)
    labels.include?(label)
  end

  def add_label(label)
    labels << label unless labeled_with?(label)
  end

  def remove_label(label)
    labels.delete(label)
  end

  def label_names
    labels.pluck(:name).join(" ")
  end
end
```

# Usage in a model:
```ruby
class Task < ApplicationRecord
  include Labelable
end
```

Another example Metadata concern:
```ruby
# app/models/metadata.rb
class Metadata < ApplicationRecord
  belongs_to :metadatable, polymorphic: true

  json_store :data, default: {}
end

# app/models/concerns/metadatable.rb
module Metadatable
  extend ActiveSupport::Concern

  included do
    has_one :metadata, as: :metadatable, dependent: :destroy, class_name: "::Metadata"  
  end

  def metadata_data
    metadata&.data || {}
  end

  def metadata_data=(value)
    (metadata || build_metadata).update!(data: value)
  end
end
```

# Usage in a model:
```ruby
class Article < ApplicationRecord
  include Metadatable

  after_create do
    self.metadata_data = { views: 0, shares: 0 }
  end
end
```
</concernable>