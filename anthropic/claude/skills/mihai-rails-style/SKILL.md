---
name: mihai-rails-style
description: This skill should be used when writing Ruby and Rails code in Mihai's distinctive style, which emphasizes the principles of simplicity and Rails conventions while embracing a practical, no-nonsense approach to modern tooling.
---

<objective>
Apply Mihai's Rails conventions to Ruby and Rails code. This skill provides practical patterns that prioritize simplicity, Rails conventions, and multi-tenant isolation through Current.organization scoping.
</objective>

<essential_principles>
## Core Philosophy

"Write code that a junior developer can understand. Every line should be obvious."

**Practical Rails:**
- Rich domain models over service objects
- CRUD controllers with standard actions
- Multi-tenant scoping via `Current.organization`
- Hotwire (Turbo + Stimulus) for interactivity
- esbuild + Tailwind CLI for assets
- Minitest with fixtures

**What to avoid:**
- Service objects for everything (use namespaced builders when needed)
- Dependency injection patterns
- Over-engineered abstractions
- Complex JS frameworks (React/Vue/Svelte)
- TypeScript in Rails apps
</essential_principles>

<intake>
What are you working on?

1. **Controllers** - Thin controllers, scoping, before_action setup
2. **Models** - Validations, scopes, enums, method organization
3. **Views** - Hotwire, partials, I18n, explicit variables
4. **Stimulus** - Small controllers, data attributes, clickable rows
5. **Testing** - Minitest, fixtures, I18n assertions
6. **Anti-Patterns** - What to avoid and better alternatives
7. **Code Review** - Review code against Mihai style
8. **General Guidance** - Philosophy and conventions

**Specify a number or describe your task.**
</intake>

<routing>
| Response | Reference to Read |
|----------|-------------------|
| 1, "controller" | [controllers.md](./references/controllers.md) |
| 2, "model" | [models.md](./references/models.md) |
| 3, "view", "partial", "hotwire", "turbo" | [views.md](./references/views.md) |
| 4, "stimulus", "javascript", "js" | [stimulus.md](./references/stimulus.md) |
| 5, "test", "testing" | [testing.md](./references/testing.md) |
| 6, "anti-pattern", "avoid" | [anti-patterns.md](./references/anti-patterns.md) |
| 7, "review" | Read all references, then review code |
| 8, general task | Read relevant references based on context |

**After reading relevant references, apply patterns to the user's code.**
</routing>

<quick_reference>
## Key Conventions

**Multi-tenant scoping:**
```ruby
Current.organization.clients.find(params[:id])
Current.organization.contacts.alphabetically
```

**Model organization order:**
1. associations
2. validations
3. scopes
4. class methods (`class << self`)
5. public instance methods
6. private methods

**Enums:**
```ruby
enum :status, { draft: "draft", published: "published" }, prefix: true
```

**Scopes:**
```ruby
scope :active, -> { where(active: true) }
scope :alphabetically, -> { order(:name) }
scope :recent, -> { order(created_at: :desc) }
```

**Date queries - use ranges:**
```ruby
where(created_at: Time.current.beginning_of_day..)
where(created_at: 1.week.ago..)
```
</quick_reference>

<reference_index>
## Domain Knowledge

All detailed patterns in `references/`:

| File | Topics |
|------|--------|
| [controllers.md](./references/controllers.md) | Thin controllers, scoping, before_action, activity tracking |
| [models.md](./references/models.md) | Validations, scopes, enums, normalizes, method organization |
| [views.md](./references/views.md) | Hotwire, Turbo Frames/Streams, partials, I18n |
| [stimulus.md](./references/stimulus.md) | Small controllers, data attributes, clickable table rows |
| [testing.md](./references/testing.md) | Minitest, fixtures, I18n assertions |
| [anti-patterns.md](./references/anti-patterns.md) | Service objects, dependency injection, over-engineering |
</reference_index>

<success_criteria>
Code follows Mihai style when:
- Controllers are thin, models are fat
- All queries scoped through `Current.organization`
- Models use `class << self` for class methods
- Enums have explicit values and `prefix: true`
- Views use partials with explicit variable passing
- I18n for all user-facing text
- Stimulus controllers are small and focused
- Tests use Minitest with fixtures and I18n assertions
- No unnecessary service objects or abstractions
</success_criteria>
