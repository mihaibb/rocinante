class Organization < ApplicationRecord
  has_many :user_organizations, dependent: :destroy
  has_many :users, through: :user_organizations

  belongs_to :owner, class_name: "User", foreign_key: "owner_id"

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :set_slug, on: :create

  private

  def set_slug
    self.slug = SecureRandom.uuid_v7 if slug.blank?
  end
end
