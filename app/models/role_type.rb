class RoleType < ApplicationRecord
  include Discardable
  has_many :roles, dependent: :destroy
  validates :display_name, :permalink, presence: true
  validates :permalink, uniqueness: true
end
