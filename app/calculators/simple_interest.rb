module Calculators
  # calculator.net's Simple Interest page (spec issue #77). Interest charged only
  # on the original principal — never compounded:
  #
  #   interest = principal × (rate / 100) × time_in_years
  #   total    = principal + interest
  #
  # `time` is entered with a `unit` (`years` or `months`); months are converted to
  # years (time / 12) BEFORE the formula is applied. `unit` defaults to "years".
  #
  # Money is computed at full BigDecimal precision and rounded to 2 dp half-up for
  # display (§10) — the spec's reference values are the 2 dp displayed figures.
  class SimpleInterest < Base
    UNITS = %w[years months].freeze

    HUNDRED = BigDecimal(100)
    MONTHS_PER_YEAR = BigDecimal(12)

    attribute :principal, :decimal
    attribute :rate, :decimal
    attribute :time, :decimal
    attribute :unit, :string, default: "years"

    validates :principal, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :time, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :unit, presence: true, inclusion: { in: UNITS }

    private

    def compute
      interest = principal * (rate / HUNDRED) * time_in_years
      total = principal + interest
      { interest: round_money(interest), total: round_money(total) }
    end

    # `unit` is validated into UNITS before #compute runs (it only runs when
    # valid?), so this branch has no unreachable fallback.
    def time_in_years
      unit == "months" ? time / MONTHS_PER_YEAR : time
    end

    def round_money(value)
      value.round(2, BigDecimal::ROUND_HALF_UP)
    end
  end
end
