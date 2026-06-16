require "bigdecimal/math"

module Calculators
  # calculator.net's Average Return page (spec issue #247). A VARIABLE-LENGTH LIST
  # input — a series of periodic returns, each a percent — reported as BOTH the
  # simple arithmetic average and the compounded geometric average (the financially
  # meaningful "true" average, which accounts for compounding).
  #
  # Unlike the Mean·Median·Mode·Range string-list, this calculator's list arrives as
  # an ARRAY (`inputs[returns][]`, ARCHITECTURE.md §3.2 spec) — the controller permits
  # it as an array attribute (Base.array_attribute_names). The calculator owns the
  # parse: blank entries are dropped, each remaining entry must be numeric and
  # ≥ −100 (a growth factor cannot be negative), and at least one value must remain.
  #
  # Formula (each rᵢ a percent, e.g. 10 ⇒ +10%):
  #   arithmetic_average = (Σ rᵢ) / n
  #   growth_factor      = Π (1 + rᵢ/100)
  #   geometric_average  = (growth_factor^(1/n) − 1) × 100
  #
  # A −100 return (total loss → growth factor 0) is the degenerate case: the product
  # is 0, so the geometric average is −100% regardless of the other periods. The n-th
  # root is computed at full BigDecimal precision (BigMath exp/log, NOT float, §10);
  # the gf = 0 case is handled directly (log(0) is undefined). Percentages display to
  # 4 decimal places (half-up); averages may be negative — the sign is preserved.
  class AverageReturn < Base
    # A signed decimal token (optional sign, digits with an optional fractional part,
    # or a bare fractional like ".5"). Anchored — the whole entry must match.
    NUMERIC_TOKEN = /\A[-+]?(\d+(\.\d+)?|\.\d+)\z/

    DISPLAY_SCALE = 4         # decimal places for displayed percentages (half-up)
    ROOT_PRECISION = 50       # BigMath working precision for the n-th root, far beyond 4 dp
    HUNDRED = BigDecimal(100)
    ONE = BigDecimal(1)
    MIN_RETURN = BigDecimal(-100) # a return below −100% implies a negative growth factor

    # `returns` is a variable-length LIST posted as `inputs[returns][]`; declared as an
    # array attribute so the controller permits the array (Base.array_attribute_names).
    attribute :returns
    array_attribute :returns

    validate :at_least_one_return
    validate :all_entries_numeric
    validate :returns_not_below_minimum

    private

    def compute
      values = parsed_returns
      n = values.size

      {
        count:              n,
        arithmetic_average: display(values.sum / n),
        geometric_average:  display(geometric_average(values, n))
      }
    end

    # --- statistics -----------------------------------------------------------

    # (growth_factor^(1/n) − 1) × 100, with growth_factor = Π (1 + rᵢ/100).
    # When any period is a total loss (rᵢ = −100), a factor is 0 → the product is 0 →
    # the n-th root is 0 → the geometric average is exactly −100% (log(0) is undefined,
    # so this case is short-circuited rather than fed to BigMath).
    def geometric_average(values, n)
      growth = values.reduce(ONE) { |acc, r| acc * (ONE + r / HUNDRED) }
      (nth_root(growth, n) - ONE) * HUNDRED
    end

    # The real n-th root of a non-negative BigDecimal, at full precision via
    # exp(log(x)/n). x is a product of growth factors, each ≥ 0 (returns ≥ −100), so x
    # is never negative; x = 0 (a total-loss period) returns 0 directly since log(0) is
    # undefined. x = 1 short-circuits to 1 (avoids a needless transcendental round-trip).
    def nth_root(x, n)
      return BigDecimal(0) if x.zero?
      return ONE if x == ONE

      BigMath.exp(BigMath.log(x, ROOT_PRECISION) / n, ROOT_PRECISION)
    end

    # --- display rounding (§10) -----------------------------------------------

    # Round to DISPLAY_SCALE dp, half-up — percentages are always shown to a fixed 4
    # places (text-output stat grid), so 0 renders "0.0000" and an integer average
    # renders "10.0000". The sign is preserved for negative averages.
    def display(value)
      value.round(DISPLAY_SCALE, BigDecimal::ROUND_HALF_UP)
    end

    # --- parsing --------------------------------------------------------------

    # The submitted entries as a flat Array of strings, with blank/whitespace-only
    # entries dropped. A lone scalar (not posted as an array) is wrapped, and nil
    # degrades to an empty list — so the validations own "no values".
    def entries
      Array(returns).reject { |entry| entry.to_s.strip.empty? }
    end

    # The parsed numeric list both averages are computed from. Only called from
    # #compute, which runs only when valid? — so every entry is known numeric here.
    def parsed_returns
      entries.map { |entry| BigDecimal(entry.to_s.strip) }
    end

    # --- validations ----------------------------------------------------------

    # After dropping blanks there must be at least one return.
    def at_least_one_return
      errors.add(:returns, :blank) if entries.empty?
    end

    # Every remaining entry must be a valid decimal; a non-numeric entry invalidates
    # the whole input (label-based error, never a silent drop or a raised exception).
    def all_entries_numeric
      return if entries.empty?
      return if entries.all? { |entry| entry.to_s.strip.match?(NUMERIC_TOKEN) }

      errors.add(:returns, :invalid_list, message: "must be a list of numbers")
    end

    # A return below −100% is impossible (it implies a negative growth factor). Checked
    # only once every entry is a clean number, so the numeric error owns bad tokens.
    def returns_not_below_minimum
      return if entries.empty?
      return unless entries.all? { |entry| entry.to_s.strip.match?(NUMERIC_TOKEN) }
      return if parsed_returns.all? { |value| value >= MIN_RETURN }

      errors.add(:returns, :too_low, message: "each return must be at least −100%")
    end
  end
end
