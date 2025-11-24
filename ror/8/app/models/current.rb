class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :organization
  attribute :user_organization

  delegate :user, to: :session, allow_nil: true
end
