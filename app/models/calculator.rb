# The calculator catalog as a *derived* DB registry (CLAUDE.md → "The calculator
# registry", ARCHITECTURE.md §0). Rows are projected from docs/INVENTORY.md by the
# idempotent ingest (Registry::Ingest) — never hand-maintained. Code is authoritative
# for what's real: a row is only ingested when its slug resolves to a Calculators::X
# class (Base.lookup).
#
# Deprecate, never delete (CLAUDE.md rule #4 spirit / §12): a calculator dropped from
# the catalog is marked via #deprecate, never destroyed, so historical comparability and
# any references survive.
class Calculator < ApplicationRecord
  scope :active,     -> { where(deprecated_at: nil) }
  scope :deprecated, -> { where.not(deprecated_at: nil) }

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true

  def deprecate
    update!(deprecated_at: Time.current) unless deprecated?
  end

  def reinstate
    update!(deprecated_at: nil) if deprecated?
  end

  def deprecated?
    deprecated_at.present?
  end
end
