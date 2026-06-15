require "bigdecimal/math"

module Calculators
  # calculator.net's Compound Interest page (spec issue #188) — a multi-mode
  # (compounding-frequency picker) financial calculator with a growth-series chart.
  #
  # Given a starting `principal` (P), an `annual_rate` (percent), a term in `years`
  # (t, fractional terms allowed) and a `compounding` mode, this computes the future
  # value under compound interest, the total interest earned, and a year-by-year
  # balance series for the FE to draw a growth curve.
  #
  #   A = P × (1 + r/m)^(m·t)        r = annual_rate / 100,  m = periods/year
  #   total_interest = A − P
  #
  # The `compounding` mode selects m (periods per year): annually=1, semiannually=2,
  # quarterly=4, monthly=12, daily=365.
  #
  # Precision/rounding (ARCHITECTURE.md §10): everything is computed at full
  # BigDecimal precision; money is rounded to the cent half-up only for display. The
  # power (1 + r/m)^(m·t) is taken exactly: when the exponent m·t is a whole number
  # (every reference case, and every whole-year growth point) it uses
  # BigDecimal#power, which is exact for integer exponents; only a genuinely
  # fractional exponent (a fractional term, on a whole-year-free point) falls back to
  # exp(exponent · ln(base)) at high precision.
  class CompoundInterest < Base
    HUNDRED = BigDecimal(100)
    CENT = 2
    # Significant digits for the high-precision power / exp / log work. Generous so
    # the raw figures are exact far past the cent.
    PRECISION = 60

    # The compounding-frequency modes → periods per year (m). The keys are the
    # `compounding` input's inclusion set; the values pick m.
    PERIODS_PER_YEAR = {
      "annually" => 1,
      "semiannually" => 2,
      "quarterly" => 4,
      "monthly" => 12,
      "daily" => 365
    }.freeze

    attribute :principal, :decimal
    attribute :annual_rate, :decimal
    attribute :years, :decimal
    attribute :compounding, :string

    validates :principal, presence: true, numericality: { greater_than: 0 }
    validates :annual_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :years, presence: true, numericality: { greater_than: 0 }
    validates :compounding, presence: true, inclusion: { in: PERIODS_PER_YEAR.keys }

    private

    def compute
      future = future_value(years)
      interest = future - principal

      {
        future_value: fmt(future),
        total_interest: fmt(interest),
        principal: fmt(principal),
        periods_per_year: periods_per_year,
        compounding: compounding,
        growth_series: growth_series
      }
    end

    # m, periods per year for the chosen mode. `compounding` is validated into
    # PERIODS_PER_YEAR's keys before #compute runs (it only runs when valid?), so the
    # fetch always hits.
    def periods_per_year = PERIODS_PER_YEAR.fetch(compounding)

    # The periodic rate (r/m) as an exact BigDecimal.
    def rate_per_period = (annual_rate / HUNDRED) / periods_per_year

    # The balance at the end of `t` years: P × (1 + r/m)^(m·t), at full precision
    # (unrounded). Callers round to the cent for display.
    def future_value(t)
      base = 1 + rate_per_period
      principal * power(base, periods_per_year * t)
    end

    # base ** exponent at full precision. For a whole-number exponent (every
    # reference case and whole-year growth point) BigDecimal#power is exact; a
    # genuinely fractional exponent uses exp(exponent · ln(base)). base is always
    # ≥ 1 here (rate ≥ 0), so ln(base) is defined; the zero-rate edge (base == 1)
    # short-circuits to 1 so it never calls log(1)/exp(0) unnecessarily.
    def power(base, exponent)
      return BigDecimal(1) if base == 1

      if exponent.frac.zero?
        base.power(exponent.to_i, PRECISION)
      else
        BigMath.exp(exponent * BigMath.log(base, PRECISION), PRECISION)
      end
    end

    # A year-by-year balance series for the chart: the end-of-year balance at every
    # whole year 0..ceil(t), plus the term endpoint t itself when t is fractional (so
    # the curve ends exactly on the term). Each balance is rounded to the cent.
    def growth_series
      whole_years = (0..years.ceil).map { |y| BigDecimal(y) }
      points = years.frac.zero? ? whole_years : whole_years + [ years ]
      points.map { |y| { year: year_label(y), balance: fmt(future_value(y)) } }
    end

    # A whole-year point is labelled with its Integer year; a fractional term
    # endpoint keeps its decimal value so the FE can place it on the time axis.
    def year_label(y) = y.frac.zero? ? y.to_i : y

    # Money string, always exactly two decimal places (half-up to the cent).
    def fmt(value)
      whole, frac = value.round(CENT, BigDecimal::ROUND_HALF_UP).to_s("F").split(".")
      "#{whole}.#{(frac.to_s + '00')[0, 2]}"
    end
  end
end
