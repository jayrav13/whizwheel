require "bigdecimal/math"

module Calculators
  # calculator.net's ROI (return on investment) page (spec issue #248) — a single-
  # formula, multi-input financial calculator (Percentage-shaped) with an optional
  # time dimension.
  #
  # Given the `amount_invested` and the `amount_returned`, it computes the total gain
  # and the ROI percentage; when an optional `investment_years` is supplied (> 0), it
  # also computes the annualized ROI (the compound annual growth rate / CAGR) over
  # that period:
  #
  #   total_gain  = amount_returned − amount_invested
  #   roi_percent = (total_gain / amount_invested) × 100
  #   annualized_roi_percent = ((amount_returned / amount_invested) ^ (1/years) − 1) × 100
  #
  # The annualized ROI is the constant yearly rate that compounds amount_invested
  # into amount_returned over investment_years; it is null when no period is given.
  #
  # amount_returned may be less than amount_invested (a loss → negative total_gain
  # and roi_percent). investment_years is decimal (fractional years allowed).
  #
  # Precision/rounding (ARCHITECTURE.md §10): everything is computed at full
  # BigDecimal precision; money is rounded to the cent (2 dp, half-up) and
  # percentages to 4 dp (half-up) only for display. The CAGR root is taken at high
  # precision via exp((1/years)·ln(ratio)) — never float; the ratio is always > 0
  # (amount_invested > 0, amount_returned ≥ 0) except when amount_returned is exactly
  # 0 (a total loss), which short-circuits to a −100% annualized return rather than
  # calling ln(0).
  class Roi < Base
    HUNDRED = BigDecimal(100)
    MONEY_DP = 2
    PERCENT_DP = 4
    # Significant digits for the high-precision CAGR root work — generous so the raw
    # figures are exact far past the fourth decimal place.
    PRECISION = 60

    attribute :amount_invested, :decimal
    attribute :amount_returned, :decimal
    attribute :investment_years, :decimal

    validates :amount_invested, presence: true, numericality: { greater_than: 0 }
    validates :amount_returned, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :investment_years, numericality: { greater_than: 0 }, allow_nil: true

    private

    def compute
      gain = amount_returned - amount_invested

      {
        amount_invested: money(amount_invested),
        amount_returned: money(amount_returned),
        total_gain: money(gain),
        roi_percent: percent(gain / amount_invested * HUNDRED),
        annualized_roi_percent: annualized_roi_percent
      }
    end

    # The CAGR over investment_years, as a 4-dp percentage string — or nil when no
    # period was supplied (the only branch in this calculator). investment_years is
    # validated > 0 when present, so the division/root are always defined.
    def annualized_roi_percent
      return nil if investment_years.nil?

      percent((annual_growth_factor - 1) * HUNDRED)
    end

    # (amount_returned / amount_invested) ^ (1 / investment_years), at full precision.
    # A total loss (amount_returned == 0) compounds to 0 over any period — the rate
    # that takes a positive principal to nothing is −100% — so the factor is 0; this
    # also avoids ln(0). Otherwise the ratio is > 0 and the root is exact via
    # exp((1/years)·ln(ratio)).
    def annual_growth_factor
      return BigDecimal(0) if amount_returned.zero?

      ratio = amount_returned / amount_invested
      BigMath.exp(BigMath.log(ratio, PRECISION) / investment_years, PRECISION)
    end

    # Money string: exactly two decimal places, half-up to the cent. Preserves a
    # leading minus sign for a loss (negative total_gain).
    def money(value) = fmt(value, MONEY_DP)

    # Percentage string: exactly four decimal places, half-up. May be negative.
    def percent(value) = fmt(value, PERCENT_DP)

    # +value+ rounded half-up to +places+ decimal places, rendered as a fixed-point
    # string with exactly that many places (so 40 → "40.0000", −2000 → "-2000.00").
    def fmt(value, places)
      rounded = value.round(places, BigDecimal::ROUND_HALF_UP)
      sign = rounded.negative? ? "-" : ""
      whole, frac = rounded.abs.to_s("F").split(".")
      "#{sign}#{whole}.#{(frac.to_s + ('0' * places))[0, places]}"
    end
  end
end
