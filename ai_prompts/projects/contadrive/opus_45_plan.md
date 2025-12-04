# ContaDrive.ro - Implementation Plan for Claude Code

## Project Overview

**Product**: ContaDrive.ro - Document management portal for accounting firms and their clients
**Timeline**: 2 weeks
**Language**: Romanian only
**Stack**: Rails 8.1, Hotwire (Turbo + Stimulus), TailwindCSS, PostgreSQL, ActiveStorage, Mailgun

---

## Data Model

### Entity Relationship

```
User (global, unique by email)
  └── has_many :memberships
  └── has_many :organizations, through: :memberships

Organization (STI base)
  ├── AccountingFirm < Organization
  │     └── has_many :clients
  └── Client < Organization
        └── belongs_to :accounting_firm
        └── has_many :documents
        └── has_many :threads

Membership
  └── belongs_to :user
  └── belongs_to :organization
  └── role: "admin" | "staff"

Invitation
  └── belongs_to :organization
  └── belongs_to :invited_by (User)

Document
  └── belongs_to :client (Organization)
  └── belongs_to :uploaded_by (User)
  └── has_one_attached :file

Thread
  └── belongs_to :client (Organization)
  └── belongs_to :closed_by (User), optional
  └── has_many :messages

Message
  └── belongs_to :thread
  └── belongs_to :user
```

---

## Database Migrations

### Migration 1: Users

```ruby
# db/migrate/001_create_users.rb
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :google_uid
      t.datetime :email_confirmed_at
      t.string :email_confirmation_token
      t.datetime :email_confirmation_sent_at
      t.string :password_reset_token
      t.datetime :password_reset_sent_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :google_uid, unique: true, where: "google_uid IS NOT NULL"
    add_index :users, :email_confirmation_token, unique: true, where: "email_confirmation_token IS NOT NULL"
    add_index :users, :password_reset_token, unique: true, where: "password_reset_token IS NOT NULL"
  end
end
```

### Migration 2: Organizations (STI)

```ruby
# db/migrate/002_create_organizations.rb
class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :type, null: false
      t.string :name, null: false
      t.references :parent_organization, foreign_key: { to_table: :organizations }

      t.timestamps
    end

    add_index :organizations, :type
  end
end
```

### Migration 3: Memberships

```ruby
# db/migrate/003_create_memberships.rb
class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :role, null: false, default: "staff"

      t.timestamps
    end

    add_index :memberships, [:user_id, :organization_id], unique: true
  end
end
```

### Migration 4: Invitations

```ruby
# db/migrate/004_create_invitations.rb
class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.string :email, null: false
      t.references :organization, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :role, null: false, default: "staff"
      t.string :token, null: false
      t.datetime :accepted_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, [:email, :organization_id]
  end
end
```

### Migration 5: Documents

```ruby
# db/migrate/005_create_documents.rb
class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "uploaded"
      t.string :category
      t.datetime :accountant_viewed_at

      t.timestamps
    end

    add_index :documents, :status
    add_index :documents, :category
  end
end
```

### Migration 6: Threads

```ruby
# db/migrate/006_create_threads.rb
class CreateThreads < ActiveRecord::Migration[8.1]
  def change
    create_table :threads do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :title, null: false
      t.string :status, null: false, default: "open"
      t.references :closed_by, foreign_key: { to_table: :users }
      t.datetime :closed_at
      t.datetime :last_message_at

      t.timestamps
    end

    add_index :threads, :status
  end
end
```

### Migration 7: Messages

```ruby
# db/migrate/007_create_messages.rb
class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :thread, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end
  end
end
```

---

## Models

### User Model

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships
  has_many :documents, foreign_key: :uploaded_by_id
  has_many :messages

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true
  validates :google_uid, uniqueness: true, allow_nil: true

  scope :confirmed, -> { where.not(email_confirmed_at: nil) }
  scope :unconfirmed, -> { where(email_confirmed_at: nil) }

  def name
    "#{first_name} #{last_name}".strip
  end

  def confirmed?
    email_confirmed_at.present?
  end

  def confirm!
    update!(email_confirmed_at: Time.current, email_confirmation_token: nil)
  end

  def generate_email_confirmation_token!
    update!(
      email_confirmation_token: SecureRandom.urlsafe_base64(32),
      email_confirmation_sent_at: Time.current
    )
  end

  def generate_password_reset_token!
    update!(
      password_reset_token: SecureRandom.urlsafe_base64(32),
      password_reset_sent_at: Time.current
    )
  end

  def email_confirmation_token_valid?
    email_confirmation_sent_at.present? && email_confirmation_sent_at > 24.hours.ago
  end

  def password_reset_token_valid?
    password_reset_sent_at.present? && password_reset_sent_at > 24.hours.ago
  end

  def accounting_firms
    organizations.where(type: "AccountingFirm")
  end

  def clients
    organizations.where(type: "Client")
  end

  def admin_of?(organization)
    memberships.exists?(organization: organization, role: "admin")
  end

  def member_of?(organization)
    memberships.exists?(organization: organization)
  end
end
```

### Organization Models (STI)

```ruby
# app/models/organization.rb
class Organization < ApplicationRecord
  belongs_to :parent_organization, class_name: "Organization", optional: true
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :threads, class_name: "ConversationThread", dependent: :destroy

  validates :name, presence: true

  def admins
    users.joins(:memberships).where(memberships: { role: "admin" })
  end

  def staff
    users.joins(:memberships).where(memberships: { role: "staff" })
  end
end

# app/models/accounting_firm.rb
class AccountingFirm < Organization
  has_many :clients, class_name: "Client", foreign_key: :parent_organization_id, dependent: :destroy

  validates :parent_organization_id, absence: true
end

# app/models/client.rb
class Client < Organization
  belongs_to :accounting_firm, class_name: "AccountingFirm", foreign_key: :parent_organization_id

  validates :parent_organization_id, presence: true
end
```

### Membership Model

```ruby
# app/models/membership.rb
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  validates :role, presence: true, inclusion: { in: %w[admin staff] }
  validates :user_id, uniqueness: { scope: :organization_id }

  scope :admins, -> { where(role: "admin") }
  scope :staff, -> { where(role: "staff") }

  def admin?
    role == "admin"
  end

  def staff?
    role == "staff"
  end
end
```

### Invitation Model

```ruby
# app/models/invitation.rb
class Invitation < ApplicationRecord
  belongs_to :organization
  belongs_to :invited_by, class_name: "User"

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: %w[admin staff] }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def accepted?
    accepted_at.present?
  end

  def accept!(user)
    transaction do
      update!(accepted_at: Time.current)
      Membership.create!(user: user, organization: organization, role: role)
    end
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end
end
```

### Document Model

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  belongs_to :organization
  belongs_to :uploaded_by, class_name: "User"

  has_one_attached :file

  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    text/csv
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    image/jpeg
    image/png
    image/webp
    image/gif
  ].freeze

  BLOCKED_CONTENT_TYPES = %w[
    application/zip
    application/x-rar-compressed
    application/x-7z-compressed
    application/gzip
    application/x-tar
  ].freeze

  STATUSES = %w[uploaded viewed].freeze
  CATEGORIES = %w[invoice receipt contract other].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validate :acceptable_file

  scope :pending, -> { where(status: "uploaded") }
  scope :viewed, -> { where(status: "viewed") }
  scope :categorized, -> { where.not(category: nil) }
  scope :uncategorized, -> { where(category: nil) }

  def mark_as_viewed!(user)
    update!(status: "viewed", accountant_viewed_at: Time.current) if status == "uploaded"
  end

  def categorize!(category)
    update!(category: category)
  end

  def viewed?
    status == "viewed"
  end

  def categorized?
    category.present?
  end

  private

  def acceptable_file
    return unless file.attached?

    unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
      errors.add(:file, :invalid_type)
    end

    if BLOCKED_CONTENT_TYPES.include?(file.content_type)
      errors.add(:file, :archive_not_allowed)
    end
  end
end
```

### Thread and Message Models

```ruby
# app/models/conversation_thread.rb
# Note: Using ConversationThread to avoid conflict with Ruby's Thread class
class ConversationThread < ApplicationRecord
  self.table_name = "threads"

  belongs_to :organization
  belongs_to :closed_by, class_name: "User", optional: true

  has_many :messages, foreign_key: :thread_id, dependent: :destroy

  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: %w[open resolved] }

  scope :open_threads, -> { where(status: "open") }
  scope :resolved, -> { where(status: "resolved") }

  def resolve!(user)
    update!(
      status: "resolved",
      closed_by: user,
      closed_at: Time.current
    )
  end

  def reopen!
    update!(
      status: "open",
      closed_by: nil,
      closed_at: nil
    )
  end

  def resolved?
    status == "resolved"
  end

  def open?
    status == "open"
  end
end

# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :thread, class_name: "ConversationThread"
  belongs_to :user

  validates :body, presence: true

  after_create :update_thread_timestamp
  after_create :reopen_thread_if_resolved

  private

  def update_thread_timestamp
    thread.update!(last_message_at: created_at)
  end

  def reopen_thread_if_resolved
    thread.reopen! if thread.resolved?
  end
end
```

---

## Controllers Structure

```
app/controllers/
├── application_controller.rb
├── sessions_controller.rb           # Login/logout
├── registrations_controller.rb      # Sign up
├── email_confirmations_controller.rb
├── password_resets_controller.rb
├── omniauth_controller.rb           # Google OAuth
├── organizations_controller.rb      # Org picker
├── invitations_controller.rb
├── accounting_firm/
│   ├── base_controller.rb
│   ├── dashboard_controller.rb
│   ├── clients_controller.rb
│   ├── documents_controller.rb      # View client docs
│   ├── threads_controller.rb
│   └── messages_controller.rb
└── client/
    ├── base_controller.rb
    ├── dashboard_controller.rb
    ├── documents_controller.rb      # Upload docs
    ├── threads_controller.rb
    └── messages_controller.rb
```

---

## Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Auth
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  get "register", to: "registrations#new"
  post "register", to: "registrations#create"

  # Email confirmation
  resources :email_confirmations, only: [:show, :create], param: :token

  # Password reset
  resources :password_resets, only: [:new, :create, :edit, :update], param: :token

  # Google OAuth
  get "auth/google/callback", to: "omniauth#google"
  get "auth/failure", to: "omniauth#failure"

  # Organization picker (post-login)
  get "organizations", to: "organizations#index"
  post "organizations/:id/enter", to: "organizations#enter", as: :enter_organization

  # Invitations
  resources :invitations, only: [:show], param: :token do
    member do
      post :accept
    end
  end

  # Accounting Firm namespace
  namespace :accounting_firm do
    resource :dashboard, only: [:show]

    resources :clients do
      resources :documents, only: [:index, :show, :update]
      resources :threads, only: [:index, :show, :new, :create] do
        member do
          post :resolve
        end
        resources :messages, only: [:create]
      end
    end

    resources :invitations, only: [:new, :create, :destroy]
    resources :members, only: [:index, :destroy]
  end

  # Client namespace
  namespace :client do
    resource :dashboard, only: [:show]

    resources :documents, only: [:index, :new, :create, :show]
    resources :threads, only: [:index, :show, :new, :create] do
      member do
        post :resolve
      end
      resources :messages, only: [:create]
    end
  end

  root "sessions#new"
end
```

---

## Romanian Locale File

```yaml
# config/locales/ro.yml
ro:
  app_name: "ContaDrive"

  # Common
  common:
    save: "Salvează"
    cancel: "Anulează"
    delete: "Șterge"
    edit: "Editează"
    back: "Înapoi"
    confirm: "Confirmă"
    loading: "Se încarcă..."
    no_results: "Nu există rezultate"
    actions: "Acțiuni"

  # Auth
  auth:
    login: "Autentificare"
    logout: "Deconectare"
    register: "Înregistrare"
    email: "Email"
    password: "Parolă"
    password_confirmation: "Confirmă parola"
    first_name: "Prenume"
    last_name: "Nume"
    forgot_password: "Ai uitat parola?"
    reset_password: "Resetează parola"
    new_password: "Parolă nouă"
    login_with_google: "Autentificare cu Google"
    or: "sau"
    already_have_account: "Ai deja cont?"
    dont_have_account: "Nu ai cont?"
    confirm_email: "Confirmă adresa de email"
    confirmation_sent: "Un email de confirmare a fost trimis la adresa ta."
    resend_confirmation: "Retrimite emailul de confirmare"
    email_confirmed: "Adresa de email a fost confirmată cu succes!"
    confirmation_expired: "Link-ul de confirmare a expirat. Te rugăm să soliciți unul nou."
    password_reset_sent: "Instrucțiunile pentru resetarea parolei au fost trimise pe email."
    password_reset_success: "Parola a fost resetată cu succes!"
    password_reset_expired: "Link-ul de resetare a expirat. Te rugăm să soliciți unul nou."

  # Flash messages
  flash:
    login_success: "Bine ai venit!"
    login_failed: "Email sau parolă incorectă."
    logout_success: "Te-ai deconectat cu succes."
    registration_success: "Cont creat cu succes! Verifică-ți emailul pentru confirmare."
    unauthorized: "Trebuie să fii autentificat pentru a accesa această pagină."
    forbidden: "Nu ai permisiunea să accesezi această pagină."
    email_not_confirmed: "Te rugăm să confirmi adresa de email."

  # Organizations
  organizations:
    select: "Selectează organizația"
    accounting_firm: "Firmă de contabilitate"
    client: "Client"
    enter: "Intră"
    no_organizations: "Nu ești membru al niciunei organizații."
    create_firm: "Creează o firmă de contabilitate"
    name: "Nume organizație"

  # Memberships & Roles
  memberships:
    role: "Rol"
    admin: "Administrator"
    staff: "Personal"
    member: "Membru"
    remove: "Elimină"
    remove_confirm: "Ești sigur că vrei să elimini acest membru?"

  # Invitations
  invitations:
    new: "Invită un utilizator"
    send: "Trimite invitația"
    email: "Adresa de email"
    role: "Rol"
    pending: "Invitații în așteptare"
    accepted: "Acceptată"
    expired: "Expirată"
    accept: "Acceptă invitația"
    accept_success: "Invitație acceptată cu succes!"
    accept_failed: "Invitația nu a putut fi acceptată."
    already_member: "Ești deja membru al acestei organizații."
    sent_success: "Invitația a fost trimisă."
    cancel: "Anulează invitația"

  # Clients
  clients:
    title: "Clienți"
    new: "Client nou"
    create: "Adaugă client"
    created: "Client creat cu succes!"
    updated: "Client actualizat cu succes!"
    deleted: "Client șters cu succes!"
    no_clients: "Nu există clienți încă."
    documents_count: "Documente"
    pending_documents: "Documente noi"

  # Documents
  documents:
    title: "Documente"
    upload: "Încarcă document"
    upload_new: "Încarcă document nou"
    uploaded: "Document încărcat cu succes!"
    no_documents: "Nu există documente încă."
    file: "Fișier"
    uploaded_at: "Încărcat la"
    uploaded_by: "Încărcat de"
    status: "Status"
    category: "Categorie"
    categorize: "Categorisează"
    mark_viewed: "Marchează ca vizualizat"
    statuses:
      uploaded: "Nou"
      viewed: "Vizualizat"
    categories:
      invoice: "Factură"
      receipt: "Chitanță"
      contract: "Contract"
      other: "Altele"
    invalid_type: "Tip de fișier invalid. Sunt permise: PDF, Excel, CSV, Word, imagini."
    archive_not_allowed: "Arhivele nu sunt permise."

  # Threads
  threads:
    title: "Conversații"
    new: "Conversație nouă"
    create: "Creează conversație"
    created: "Conversație creată cu succes!"
    no_threads: "Nu există conversații încă."
    thread_title: "Titlu"
    status: "Status"
    resolve: "Marchează ca rezolvată"
    resolved: "Conversație marcată ca rezolvată."
    reopened: "Conversația a fost redeschisă."
    statuses:
      open: "Deschisă"
      resolved: "Rezolvată"
    resolved_by: "Rezolvată de"
    resolved_at: "Rezolvată la"
    last_message: "Ultimul mesaj"

  # Messages
  messages:
    new: "Mesaj nou"
    send: "Trimite"
    sent: "Mesaj trimis!"
    body: "Mesaj"
    no_messages: "Nu există mesaje în această conversație."
    sent_by: "Trimis de"
    sent_at: "Trimis la"

  # Navigation
  nav:
    dashboard: "Panou de control"
    clients: "Clienți"
    documents: "Documente"
    conversations: "Conversații"
    team: "Echipă"
    settings: "Setări"
    switch_organization: "Schimbă organizația"

  # Errors
  errors:
    messages:
      invalid_type: "tip de fișier invalid"
      archive_not_allowed: "arhivele nu sunt permise"

  # Time/Date
  date:
    formats:
      default: "%d.%m.%Y"
      short: "%d %b"
      long: "%d %B %Y"
  time:
    formats:
      default: "%d.%m.%Y %H:%M"
      short: "%d %b %H:%M"
      long: "%d %B %Y, %H:%M"

  # ActiveRecord
  activerecord:
    models:
      user: "Utilizator"
      organization: "Organizație"
      accounting_firm: "Firmă de contabilitate"
      client: "Client"
      membership: "Membru"
      invitation: "Invitație"
      document: "Document"
      conversation_thread: "Conversație"
      message: "Mesaj"
    attributes:
      user:
        email: "Email"
        password: "Parolă"
        first_name: "Prenume"
        last_name: "Nume"
      organization:
        name: "Nume"
      document:
        file: "Fișier"
        status: "Status"
        category: "Categorie"
      conversation_thread:
        title: "Titlu"
        status: "Status"
      message:
        body: "Mesaj"
```

---

## Day-by-Day Implementation Tasks

### Week 1: Foundation

#### Day 1: Project Setup
```
TASK 1.1: Configure Rails application
- [ ] Set default locale to :ro in config/application.rb
- [ ] Add ro.yml locale file
- [ ] Configure ActiveStorage for local development
- [ ] Configure Mailgun for development/production
- [ ] Set up TailwindCSS (if not already in template)
- [ ] Create .env.example with required variables

TASK 1.2: Create database migrations
- [ ] Generate all 7 migrations as specified above
- [ ] Run migrations
- [ ] Verify schema

TASK 1.3: Create models
- [ ] User model with validations
- [ ] Organization STI models (Organization, AccountingFirm, Client)
- [ ] Membership model
- [ ] Invitation model
- [ ] Document model with ActiveStorage
- [ ] ConversationThread model
- [ ] Message model

TASK 1.4: Add model tests/specs (optional but recommended)
- [ ] User validations and methods
- [ ] Organization associations
- [ ] Document file validation
```

#### Day 2: Authentication (Email/Password)
```
TASK 2.1: Sessions controller
- [ ] new action (login form)
- [ ] create action (authenticate)
- [ ] destroy action (logout)
- [ ] Login view with TailwindCSS form

TASK 2.2: Registrations controller
- [ ] new action (registration form)
- [ ] create action (create user, send confirmation)
- [ ] Registration view

TASK 2.3: Email confirmation
- [ ] EmailConfirmationsController (show, create for resend)
- [ ] UserMailer#email_confirmation
- [ ] Email confirmation views
- [ ] "Please confirm email" page for unconfirmed users

TASK 2.4: Authentication concern
- [ ] Current.user setup
- [ ] require_authentication before_action
- [ ] require_confirmed_email before_action
- [ ] Helper methods (current_user, logged_in?, etc.)
```

#### Day 3: Password Reset
```
TASK 3.1: Password resets controller
- [ ] new action (request form)
- [ ] create action (send reset email)
- [ ] edit action (reset form)
- [ ] update action (change password)

TASK 3.2: Mailer
- [ ] UserMailer#password_reset

TASK 3.3: Views
- [ ] Request reset form
- [ ] Reset form
- [ ] Email templates
```

#### Day 4: Google OAuth
```
TASK 4.1: Configure OmniAuth
- [ ] Add omniauth-google-oauth2 gem
- [ ] Configure in initializer
- [ ] Add Google OAuth credentials to env

TASK 4.2: OmniAuth controller
- [ ] google callback action
- [ ] failure action
- [ ] Find or create user by email
- [ ] Link google_uid to existing user if email matches
- [ ] Auto-confirm Google users

TASK 4.3: UI updates
- [ ] Add "Login with Google" button to login page
- [ ] Add "Sign up with Google" button to registration page
```

#### Day 5: Organizations & Org Picker
```
TASK 5.1: Organizations controller
- [ ] index action (list user's orgs)
- [ ] enter action (set current org in session)

TASK 5.2: Current organization concern
- [ ] Store current_organization_id in session
- [ ] current_organization helper
- [ ] require_organization before_action

TASK 5.3: Org picker view
- [ ] List all user's organizations grouped by type
- [ ] "Enter" button for each org
- [ ] Show role badge (admin/staff)

TASK 5.4: Create first accounting firm flow
- [ ] If user has no orgs, show "Create firm" form
- [ ] Create firm + admin membership
```

#### Day 6: Invitations (Send)
```
TASK 6.1: Invitations controller (accounting_firm namespace)
- [ ] new action
- [ ] create action
- [ ] destroy action (cancel pending)
- [ ] Admin-only authorization

TASK 6.2: Invitation mailer
- [ ] InvitationMailer#invite
- [ ] Email template with accept link

TASK 6.3: Views
- [ ] Invitation form (email, role select)
- [ ] Pending invitations list
```

#### Day 7: Invitations (Accept)
```
TASK 7.1: Public invitations controller
- [ ] show action (display invitation details)
- [ ] accept action (create membership)

TASK 7.2: Accept flow
- [ ] If logged in: accept directly
- [ ] If not logged in: redirect to login/register, then accept
- [ ] If email matches: link to existing account
- [ ] Handle expired invitations

TASK 7.3: Views
- [ ] Invitation accept page
- [ ] Expired invitation page
- [ ] Already accepted page
```

---

### Week 2: Features

#### Day 8: Client Management
```
TASK 8.1: Clients controller (accounting_firm namespace)
- [ ] index action
- [ ] new action
- [ ] create action
- [ ] show action (client detail)
- [ ] destroy action

TASK 8.2: Views
- [ ] Client list with document counts
- [ ] New client form
- [ ] Client detail page (documents + threads preview)

TASK 8.3: Invite client users
- [ ] Reuse invitation system for client org
- [ ] Client invitation form
```

#### Day 9: Document Upload (Client Side)
```
TASK 9.1: Documents controller (client namespace)
- [ ] index action
- [ ] new action
- [ ] create action with file validation
- [ ] show action

TASK 9.2: File validation
- [ ] Validate content type on upload
- [ ] Reject archives
- [ ] Display friendly error messages

TASK 9.3: Views
- [ ] Document list (client's own docs)
- [ ] Upload form with drag & drop (Stimulus)
- [ ] Document detail view

TASK 9.4: Stimulus controller for file upload
- [ ] Drag and drop zone
- [ ] File type preview validation
- [ ] Upload progress indicator
```

#### Day 10: Document Inbox (Accountant Side)
```
TASK 10.1: Documents controller (accounting_firm namespace)
- [ ] index action (filter by client, status)
- [ ] show action (view + mark as viewed)
- [ ] update action (set category)

TASK 10.2: Views
- [ ] Document inbox (all clients or filtered)
- [ ] Status badges (new/viewed)
- [ ] Category dropdown
- [ ] Document viewer/preview

TASK 10.3: Turbo integration
- [ ] Turbo Frame for document list
- [ ] Turbo Stream for status updates
```

#### Day 11: Threads & Messages
```
TASK 11.1: Threads controller (both namespaces)
- [ ] index action
- [ ] show action
- [ ] new action
- [ ] create action

TASK 11.2: Messages controller
- [ ] create action
- [ ] Turbo Stream broadcast

TASK 11.3: Views
- [ ] Thread list
- [ ] New thread form
- [ ] Thread detail with messages
- [ ] Message form (inline)

TASK 11.4: Turbo Streams for real-time
- [ ] Broadcast new messages
- [ ] Auto-scroll to new messages (Stimulus)
```

#### Day 12: Thread Resolve/Reopen
```
TASK 12.1: Resolve action
- [ ] Add resolve action to threads controller
- [ ] Record closed_by and closed_at
- [ ] Update UI to show resolved status

TASK 12.2: Auto-reopen
- [ ] Message after_create callback
- [ ] Reopen if thread was resolved
- [ ] Turbo Stream for status change

TASK 12.3: Views
- [ ] Resolve button
- [ ] "Resolved by X at Y" display
- [ ] Visual distinction for resolved threads
```

#### Day 13: Navigation & Polish
```
TASK 13.1: Layout components
- [ ] Sidebar navigation
- [ ] Organization switcher in header
- [ ] Mobile responsive menu (Stimulus)
- [ ] User dropdown menu

TASK 13.2: Empty states
- [ ] No clients
- [ ] No documents
- [ ] No threads
- [ ] No messages

TASK 13.3: Flash messages
- [ ] Toast notifications (Stimulus)
- [ ] Auto-dismiss

TASK 13.4: UI polish
- [ ] Loading states
- [ ] Form error styling
- [ ] Responsive tables
- [ ] Status colors/badges consistency
```

#### Day 14: Testing & Launch
```
TASK 14.1: Manual QA checklist
- [ ] Registration flow (email + Google)
- [ ] Email confirmation (including expiry)
- [ ] Password reset
- [ ] Organization creation
- [ ] Organization switching
- [ ] Invitation send + accept (new user)
- [ ] Invitation accept (existing user)
- [ ] Client creation
- [ ] Document upload (valid types)
- [ ] Document upload (invalid types - reject)
- [ ] Document viewing + categorization
- [ ] Thread creation
- [ ] Message posting
- [ ] Thread resolve/reopen
- [ ] Permissions (admin vs staff)

TASK 14.2: Bug fixes
- [ ] Address any issues found

TASK 14.3: Production prep
- [ ] Verify environment variables
- [ ] ActiveStorage S3 config
- [ ] Mailgun production domain
- [ ] SSL verification
- [ ] Error tracking (optional: Sentry/Honeybadger)

TASK 14.4: Deploy
- [ ] Deploy to VPS
- [ ] Run migrations
- [ ] Smoke test production
```

---

## Key File Checklist

```
app/
├── controllers/
│   ├── application_controller.rb
│   ├── concerns/
│   │   ├── authentication.rb
│   │   └── organization_context.rb
│   ├── sessions_controller.rb
│   ├── registrations_controller.rb
│   ├── email_confirmations_controller.rb
│   ├── password_resets_controller.rb
│   ├── omniauth_controller.rb
│   ├── organizations_controller.rb
│   ├── invitations_controller.rb
│   ├── accounting_firm/
│   │   ├── base_controller.rb
│   │   ├── dashboard_controller.rb
│   │   ├── clients_controller.rb
│   │   ├── documents_controller.rb
│   │   ├── threads_controller.rb
│   │   ├── messages_controller.rb
│   │   └── invitations_controller.rb
│   └── client/
│       ├── base_controller.rb
│       ├── dashboard_controller.rb
│       ├── documents_controller.rb
│       ├── threads_controller.rb
│       └── messages_controller.rb
├── models/
│   ├── user.rb
│   ├── organization.rb
│   ├── accounting_firm.rb
│   ├── client.rb
│   ├── membership.rb
│   ├── invitation.rb
│   ├── document.rb
│   ├── conversation_thread.rb
│   ├── message.rb
│   └── current.rb
├── mailers/
│   ├── application_mailer.rb
│   ├── user_mailer.rb
│   └── invitation_mailer.rb
├── views/
│   ├── layouts/
│   │   ├── application.html.erb
│   │   ├── auth.html.erb
│   │   └── _navigation.html.erb
│   ├── sessions/
│   ├── registrations/
│   ├── email_confirmations/
│   ├── password_resets/
│   ├── organizations/
│   ├── invitations/
│   ├── accounting_firm/
│   │   ├── dashboard/
│   │   ├── clients/
│   │   ├── documents/
│   │   ├── threads/
│   │   └── messages/
│   ├── client/
│   │   ├── dashboard/
│   │   ├── documents/
│   │   ├── threads/
│   │   └── messages/
│   └── shared/
│       ├── _flash.html.erb
│       ├── _empty_state.html.erb
│       └── _pagination.html.erb
└── javascript/
    └── controllers/
        ├── file_upload_controller.js
        ├── flash_controller.js
        ├── auto_scroll_controller.js
        └── mobile_menu_controller.js

config/
├── routes.rb
├── locales/
│   └── ro.yml
├── initializers/
│   └── omniauth.rb
└── storage.yml

db/
└── migrate/
    ├── 001_create_users.rb
    ├── 002_create_organizations.rb
    ├── 003_create_memberships.rb
    ├── 004_create_invitations.rb
    ├── 005_create_documents.rb
    ├── 006_create_threads.rb
    └── 007_create_messages.rb
```

---

## Environment Variables

```bash
# .env.example

# Database
DATABASE_URL=postgres://user:pass@localhost:5432/contadrive_development

# Rails
SECRET_KEY_BASE=generate_with_rails_secret
RAILS_ENV=development

# Google OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Mailgun
MAILGUN_API_KEY=your_mailgun_api_key
MAILGUN_DOMAIN=your_mailgun_domain

# ActiveStorage (production)
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_REGION=eu-central-1
AWS_BUCKET=contadrive-production

# App
APP_HOST=contadrive.ro
```

---

## Claude Code Usage Tips

When working with this plan in Claude Code:

1. **Reference this file**: Start each session by pointing Claude Code to this plan
2. **Work task by task**: Ask Claude Code to implement one TASK at a time
3. **Provide context**: Tell Claude Code which day/task you're on
4. **Review generated code**: Always review before committing
5. **Test incrementally**: Test each feature before moving to the next

Example prompts:
- "Implement TASK 2.1: Sessions controller with login form"
- "Create the User model as specified in the implementation plan"
- "Add the Romanian locale file from the plan"
- "Implement the document upload with file validation from Day 9"