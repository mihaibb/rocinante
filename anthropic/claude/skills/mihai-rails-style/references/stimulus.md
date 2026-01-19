# Stimulus - Mihai Rails Style

<small_controllers>
## Stimulus for Behavior, Not State

Keep Stimulus controllers small and focused. One responsibility per controller.

```javascript
// Good - single responsibility
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
```

```javascript
// Good - focused on one thing
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
  }
}
```

Stimulus is for:
- DOM manipulation
- Event handling
- Simple UI interactions

NOT for:
- Application state
- Data fetching (let Turbo handle it)
- Complex business logic
</small_controllers>

<data_attributes>
## Data Attributes for Configuration

Use Stimulus values for controller configuration.

```erb
<div data-controller="countdown"
     data-countdown-seconds-value="60"
     data-countdown-auto-start-value="true">
  <span data-countdown-target="display">60</span>
</div>
```

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    seconds: Number,
    autoStart: { type: Boolean, default: false }
  }
  static targets = ["display"]

  connect() {
    if (this.autoStartValue) {
      this.start()
    }
  }

  start() {
    this.remaining = this.secondsValue
    this.timer = setInterval(() => this.tick(), 1000)
  }

  tick() {
    this.remaining--
    this.displayTarget.textContent = this.remaining
    if (this.remaining <= 0) {
      clearInterval(this.timer)
    }
  }
}
```
</data_attributes>

<let_turbo_navigate>
## Let Turbo Handle Navigation

Don't write JavaScript for page transitions. Turbo handles this automatically.

```erb
<%# Good - Turbo handles this %>
<%= link_to "View", @client %>
<%= link_to "Edit", edit_client_path(@client) %>

<%# Bad - manual navigation %>
<a href="#" onclick="fetchAndRender('/clients/1')">View</a>
<button onclick="window.location = '/clients/1'">View</button>
```

Turbo Drive intercepts link clicks and form submissions automatically.
</let_turbo_navigate>

<clickable_rows>
## Exception: Clickable Table Rows

Since you can't wrap a `<tr>` in an `<a>` tag, use a Stimulus controller.

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
<table>
  <tbody>
    <% @clients.each do |client| %>
      <tr data-controller="row-link"
          data-row-link-url-value="<%= client_path(client) %>"
          data-action="click->row-link#visit"
          class="cursor-pointer hover:bg-stone-50">
        <td><%= client.name %></td>
        <td><%= client.email %></td>
        <td><%= client.phone %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

Key points:
- Uses `Turbo.visit()` to maintain Turbo Drive behavior
- `cursor-pointer` for visual affordance
- Hover state for feedback
</clickable_rows>

<common_controllers>
## Common Controller Patterns

**Dismissable** - remove element from DOM:
```javascript
export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
```

**Toggle** - show/hide content:
```javascript
export default class extends Controller {
  static targets = ["content"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
  }
}
```

**Clipboard** - copy to clipboard:
```javascript
export default class extends Controller {
  static targets = ["source"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.value)
  }
}
```

**Auto-submit** - submit form on change:
```javascript
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
```
</common_controllers>

<registering_controllers>
## Registering Controllers

After creating a new controller, register it:

```bash
bin/rails stimulus:manifest:update
```

This updates `app/javascript/controllers/index.js` automatically.
</registering_controllers>
