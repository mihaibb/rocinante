# Controllers - Mihai Rails Style

<thin_controllers>
## Thin Controllers, Fat Models

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

Controllers should:
- Build/find records
- Call save/update/destroy
- Track activity
- Redirect or render
</thin_controllers>

<organization_scoping>
## Always Scope Through Current.organization

Multi-tenant isolation is non-negotiable. Every query must go through the organization.

```ruby
# Good - scoped through organization
Current.organization.clients.find(params[:id])
Current.organization.contacts.alphabetically
Current.organization.todo_lists.pending.ordered

# Bad - manual scoping
Client.where(organization_id: Current.organization.id).find(params[:id])
Client.find_by(id: params[:id], organization_id: Current.organization.id)
```

This pattern:
- Ensures tenant isolation
- Makes security audits easier
- Prevents accidental cross-tenant data access
</organization_scoping>

<before_action>
## Use before_action for Setup

Extract common record loading into before_action callbacks.

```ruby
class ClientsController < ApplicationController
  before_action :set_client, only: [:show, :edit, :update, :destroy]

  def show
  end

  def edit
  end

  def update
    if @client.update(client_params)
      track_activity(:client_updated, @client)
      redirect_to @client, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client.destroy
    track_activity(:client_deleted, @client, params: { name: @client.name })
    redirect_to clients_path, notice: t(".deleted")
  end

  private

  def set_client
    @client = Current.organization.clients.find_by!(slug: params[:id])
  end

  def client_params
    params.require(:client).permit(:name, :email, :phone)
  end
end
```
</before_action>

<activity_tracking>
## Activity Tracking

Track all CRUD actions for audit trails.

```ruby
def create
  @client = Current.organization.clients.new(client_params)

  if @client.save
    track_activity(:client_created, @client)
    redirect_to @client, notice: t(".created")
  else
    render :new, status: :unprocessable_entity
  end
end

def update
  if @client.update(client_params)
    track_activity(:client_updated, @client, params: {
      changes: @client.previous_changes.except("updated_at")
    })
    redirect_to @client, notice: t(".updated")
  else
    render :edit, status: :unprocessable_entity
  end
end

def destroy
  @client.destroy
  track_activity(:client_deleted, @client, params: { name: @client.name })
  redirect_to clients_path, notice: t(".deleted")
end
```

Key points:
- Track after successful operations
- Include relevant params for context
- After destroy, model attributes are still accessible
</activity_tracking>

<logical_spacing>
## Logical Spacing

Group related code. Separate distinct operations with blank lines.

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

- Group assignments together
- Blank line before conditionals
- Blank line before redirects/renders
</logical_spacing>

<i18n_flash>
## I18n for Flash Messages

Always use I18n for user-facing messages.

```ruby
# Good
redirect_to @client, notice: t(".created")
redirect_to clients_path, alert: t(".deleted")

# Bad
redirect_to @client, notice: "Client created successfully"
```

Rails looks up keys like `clients.create.created` automatically with the `.` shorthand.
</i18n_flash>
