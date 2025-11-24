# Project Context

## Overview
This is a Ruby on Rails application. It serves as a platform for ....

## Tech Stack
- **Framework:** Ruby on Rails 8.2.0.alpha
- **Language:** Ruby
- **Database:** SQLite3
- **Frontend:**
  - **CSS:** Tailwind CSS (v4)
  - **JS:** Hotwire (Turbo & Stimulus)
  - **Bundler:** esbuild (JS), tailwindcss-cli (CSS)
- **Authentication:** Custom implementation (`Authentication` concern), `has_secure_password`
- **Icons:** Lucide Rails

## Development
- **Server**: `bin/dev` starts the Rails server and CSS/JS watchers.
- **Styles**: `app/assets/stylesheets/application.tailwind.css`.
- **Views**: Standard ERB templates.
- **Stimulus Controllers**: When adding new controllers, run `./bin/rails stimulus:manifest:update` to register them in `controllers/index.js`.
- **Migrations**: When making changes to recent migrations, prefer rolling back and editing the existing migration file rather than creating a new migration. Use `./bin/rails db:rollback STEP=N` to rollback N migrations, edit the migration file, then run `./bin/rails db:migrate` again.
- **Scoped Record Access**: NEVER use `.find(id)` directly on a model (e.g., `Podcast.find(id)` or `PodcastEpisode.find(id)`). Always scope queries through the current user's context to ensure proper authorization. Use ActiveRecord queries that execute in the database, NOT methods like `flat_map` that load records into memory. Correct patterns: `Current.organization.podcasts.find(id)`, `PodcastEpisode.joins(:podcast).where(podcasts: { organization_id: Current.organization.id }).find(id)`. Direct model `.find()` is only acceptable for top-level records that don't require scoping.
