class Role < ApplicationRecord
  include Discardable
  belongs_to :user
  belongs_to :role_type
end
