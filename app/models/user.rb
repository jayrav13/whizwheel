class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :username, with: ->(u) { u.strip.downcase }
  validates :username, presence: true, uniqueness: true
end
