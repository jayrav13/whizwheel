class Calculation < ApplicationRecord
  include Discardable
  belongs_to :user, optional: true
end
