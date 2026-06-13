class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :roles, dependent: :destroy

  normalizes :username, with: ->(u) { u.strip.downcase }
  validates :username, presence: true, uniqueness: true

  def admin?
    roles.kept.joins(:role_type).where(role_types: { permalink: "ADMIN", deleted_at: nil }).exists?
  end
end
