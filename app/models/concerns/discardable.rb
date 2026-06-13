module Discardable
  extend ActiveSupport::Concern

  included do
    scope :kept,      -> { where(deleted_at: nil) }
    scope :discarded, -> { where.not(deleted_at: nil) }
  end

  def discard    = update!(deleted_at: Time.current)
  def undiscard  = update!(deleted_at: nil)
  def discarded? = deleted_at.present?
end
