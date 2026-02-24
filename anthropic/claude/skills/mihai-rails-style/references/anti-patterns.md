# Anti-Patterns - Mihai Rails Style

<service_objects>
## Service Objects for Everything

Don't create service objects for basic CRUD operations.

```ruby
# Bad - generic service objects
ClientCreationService.new(params).call
CreateClientService.call(params)
Services::Clients::Creator.new(params).execute

# Good - just use the model
Client.create!(client_params)
@client.update!(client_params)
```

When model isn't enough, use a namespaced builder:

```ruby
# Good - namespaced under the model it creates
Client::Builder.new(params, organization: Current.organization).create
Invoice::Generator.new(client, line_items).generate
Report::Exporter.new(report, format: :pdf).export
```

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

Use builders when:
- Creating multiple associated records
- Complex validation across objects
- External API calls during creation
- Logic too complex for model callbacks
</service_objects>

<dependency_injection>
## Dependency Injection

Don't bring Java patterns to Ruby.

```ruby
# Bad - Java-style DI
class ClientsController
  def initialize(repository: ClientRepository.new,
                 notifier: ClientNotifier.new)
    @repository = repository
    @notifier = notifier
  end

  def index
    @clients = @repository.find_all
  end
end

# Good - use Rails
class ClientsController < ApplicationController
  def index
    @clients = Current.organization.clients
  end
end
```

Rails gives you:
- ActiveRecord for data access
- `Current` for request context
- Concerns for shared behavior
</dependency_injection>

<over_engineering>
## Over-Engineered Patterns

Avoid design patterns that add complexity without value.

```ruby
# Bad - command pattern overkill
module Clients
  class CreateCommand < BaseCommand
    include Validatable
    include Publishable
    include Loggable

    def initialize(params)
      @params = params
    end

    def call
      validate!
      client = build_client
      persist!(client)
      publish_event(client)
      log_creation(client)
      Result.success(client)
    rescue ValidationError => e
      Result.failure(e.errors)
    end
  end
end

# Good - plain Rails
class ClientsController < ApplicationController
  def create
    @client = Current.organization.clients.new(client_params)

    if @client.save
      track_activity(:client_created, @client)
      redirect_to @client, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```
</over_engineering>

<repository_pattern>
## Repository Pattern

Don't create repository classes. ActiveRecord IS the repository.

```ruby
# Bad - unnecessary abstraction
class ClientRepository
  def find(id)
    Client.find(id)
  end

  def find_all_active
    Client.where(active: true)
  end

  def save(client)
    client.save
  end
end

# Good - use ActiveRecord directly
Current.organization.clients.find(params[:id])
Current.organization.clients.active
@client.save
```
</repository_pattern>

<presenter_decorators>
## Presenters and Decorators

Don't create presenter/decorator layers for simple formatting.

```ruby
# Bad - presenter class
class ClientPresenter
  def initialize(client)
    @client = client
  end

  def formatted_name
    @client.name.titleize
  end

  def status_badge_class
    case @client.status
    when "active" then "badge-green"
    when "inactive" then "badge-gray"
    end
  end
end

# Good - helper methods in model
class Client < ApplicationRecord
  def display_name
    name.titleize
  end
end

# Good - view helper for presentation
module ClientsHelper
  def status_badge_class(client)
    case client.status
    when "active" then "badge-green"
    when "inactive" then "badge-gray"
    end
  end
end
```
</presenter_decorators>

<form_objects>
## Form Objects for Simple Forms

Don't create form objects when a model works fine.

```ruby
# Bad - unnecessary form object
class ClientForm
  include ActiveModel::Model

  attr_accessor :name, :email, :phone

  validates :name, presence: true

  def save
    Client.create!(name: name, email: email, phone: phone)
  end
end

# Good - use the model directly
<%= form_with model: @client do |form| %>
  <%= form.text_field :name %>
  <%= form.email_field :email %>
<% end %>
```

Form objects are only justified for:
- Forms spanning multiple models
- Complex conditional validation
- Signup/onboarding flows with extra fields
</form_objects>

<callbacks_everywhere>
## Callbacks for Business Logic

Don't put complex business logic in callbacks.

```ruby
# Bad - hidden side effects
class Client < ApplicationRecord
  after_create :send_welcome_email
  after_create :create_default_settings
  after_create :notify_admin
  after_create :sync_to_crm
  after_create :update_statistics
end

# Good - explicit in controller or builder
def create
  @client = Current.organization.clients.new(client_params)

  if @client.save
    track_activity(:client_created, @client)
    ClientMailer.welcome(@client).deliver_later
    redirect_to @client, notice: t(".created")
  else
    render :new, status: :unprocessable_entity
  end
end

# Or use a builder for complex creation
Client::Builder.new(params, organization: Current.organization).create
```

Callbacks are fine for:
- Setting default values (`before_validation`)
- Updating derived attributes (`before_save`)
- Cache invalidation (`after_commit`)
</callbacks_everywhere>

<typescript>
## TypeScript in Rails

Don't add TypeScript to Rails apps.

```javascript
// Bad - unnecessary complexity
interface Client {
  id: number;
  name: string;
  email: string | null;
}

const fetchClients = async (): Promise<Client[]> => {
  const response = await fetch('/clients.json');
  return response.json();
}

// Good - let Turbo handle it
// No JavaScript needed for fetching data
// Turbo Frames and Streams handle all updates
```

Stimulus controllers are simple enough that TypeScript adds more friction than value.
</typescript>

<sti_subclasses_create>
## STI Subclasses for Creation
Don't create STI classes via the has_many association.

```ruby
# Bad - STI subclasses for creation
organization.clients.create!(type: "PremiumClient", name: "Acme Corp")

# Good - use the subclass directly
PremiumClient.create!(organization: organization, name: "Acme Corp")
```

</sti_subclasses_create>

<class_names_as_strings>

## Class Names as Strings
Avoid doing this but if needed use the class name property instead of a string.

```ruby
# Bad - string class names
Client.create(type: "PremiumClient", name: "Acme Corp")

# Good - use the class directly
Client.create(type: PremiumClient.name, name: "Acme Corp")
```

</class_names_as_strings>
