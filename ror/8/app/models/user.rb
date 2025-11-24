class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :user_organizations, dependent: :destroy
  has_many :organizations, through: :user_organizations

  has_person_name

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true
  validates :first_name, presence: true
end
