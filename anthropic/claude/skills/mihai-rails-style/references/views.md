# Views - Mihai Rails Style

<hotwire_first>
## Hotwire First

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

Turbo handles:
- Page navigation (Turbo Drive)
- Partial page updates (Turbo Frames)
- Real-time DOM updates (Turbo Streams)
</hotwire_first>

<turbo_frames>
## Turbo Frames

Use frames for isolated, replaceable sections.

```erb
<%# Index page with inline new form %>
<%= turbo_frame_tag "new_client" do %>
  <%= link_to "Add Client", new_client_path %>
<% end %>

<div id="clients">
  <%= render @clients %>
</div>
```

```erb
<%# new.html.erb %>
<%= turbo_frame_tag "new_client" do %>
  <h2>New Client</h2>
  <%= render "form", client: @client %>
<% end %>
```

Key patterns:
- `dom_id(@record)` for unique IDs
- `turbo_frame_tag` wraps replaceable content
- Forms target `_top` to break out of frame
</turbo_frames>

<turbo_streams>
## Turbo Streams

Use streams for multiple DOM updates.

```erb
<%# create.turbo_stream.erb %>
<%= turbo_stream.prepend "clients" do %>
  <%= render @client %>
<% end %>

<%= turbo_stream.update "new_client" do %>
  <%= link_to "Add Client", new_client_path %>
<% end %>

<%# Remove empty state if present %>
<%= turbo_stream.remove "clients-empty-state" %>
```

Common actions:
- `prepend` / `append` - add to list
- `replace` - replace entire element
- `update` - replace inner HTML
- `remove` - delete element
</turbo_streams>

<partials>
## Partials for Everything

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

Benefits:
- Easier to read
- Reusable components
- Smaller diffs in version control
</partials>

<explicit_variables>
## Pass Variables Explicitly

Always pass variables to partials explicitly.

```erb
<%# Good - explicit %>
<%= render "members", client: @client %>
<%= render partial: "client", collection: @clients, as: :client %>

<%# Bad - relies on instance variable %>
<%= render "members" %>
```

This makes:
- Dependencies clear
- Partials reusable
- Testing easier
</explicit_variables>

<i18n>
## I18n for All User-Facing Text

Never hardcode strings in views.

```erb
<%# Good %>
<h1><%= t(".title") %></h1>
<%= button_tag t("actions.save") %>
<%= link_to t("actions.cancel"), clients_path %>

<%# Bad %>
<h1>Clients</h1>
<%= button_tag "Save" %>
<%= link_to "Cancel", clients_path %>
```

Rails convention:
- `.key` looks up `controller.action.key`
- Full paths like `actions.save` for shared strings
</i18n>

<empty_states>
## Empty State Pattern

Handle empty collections with identifiable empty states for Turbo Stream removal.

```erb
<div id="clients">
  <%= render @clients %>
</div>

<% if @clients.empty? %>
  <div id="clients-empty-state" class="p-12 text-center">
    <p class="text-stone-500"><%= t(".no_clients") %></p>
    <%= link_to t(".add_first"), new_client_path %>
  </div>
<% end %>
```

In turbo stream response:
```erb
<%= turbo_stream.prepend "clients" do %>
  <%= render @client %>
<% end %>

<%= turbo_stream.remove "clients-empty-state" %>
```

Naming: `{plural-resource}-empty-state`
</empty_states>

<form_patterns>
## Form Patterns

Required fields with visual indicators:

```erb
<%= form.label :name, class: "block text-sm font-medium text-stone-700 mb-1" do %>
  <%= t(".name") %> <span class="text-red-500">*</span>
<% end %>
<%= form.text_field :name, required: true, class: "..." %>
```

Collection selects with organization scoping:

```erb
<%= form.collection_select :client_id,
    Current.organization.clients.alphabetically,
    :id, :name,
    { prompt: t(".select_client") },
    { class: "...", required: true } %>
```
</form_patterns>
