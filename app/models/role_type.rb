class RoleType < ApplicationRecord
  include Discardable
  has_many :roles, dependent: :restrict_with_exception
  validates :display_name, :permalink, presence: true
  validates :permalink, uniqueness: true
end
