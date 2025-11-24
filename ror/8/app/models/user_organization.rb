class UserOrganization < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  enum :role, { owner: "owner", editor: "editor", viewer: "viewer" }, default: :editor, prefix: true
end
