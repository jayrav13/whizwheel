module Calculators
  # calculator.net's Standard Deviation page (spec issue #190). A variable-length
  # LIST input (the Mean·Median·Mode·Range pattern — the calculator owns the parse,
  # ARCHITECTURE.md §3.2) paired with a POPULATION/SAMPLE mode picker that selects
  # the variance denominator.
  #
  # The list is split on commas and/or any whitespace (collapsing consecutive
  # separators, ignoring leading/trailing ones), each token coerced to BigDecimal.
  # Any non-numeric token makes the whole input invalid with a label-based error
  # ("Values must be a list of numbers") — bad tokens are never silently dropped.
  #
  # Statistics (mean, variance, standard_deviation):
  #   mean = (Σ xᵢ) / n
  #   SS   = Σ (xᵢ − mean)²            (sum of squared deviations from the mean)
  #   population:  variance = SS / n         SD = √(SS / n)        (n ≥ 1)
  #   sample:      variance = SS / (n − 1)   SD = √(SS / (n − 1))  (n ≥ 2)
  #
  # All math is BigDecimal (§10): mean / variance / standard_deviation are computed
  # at full precision (the √ via BigDecimal#sqrt at a high working precision) and
  # then DISPLAYED to 6 decimal places (half-up). `count` is an integer; `sum` is
  # exact (no forced decimals). `mode` is echoed back.
  class StandardDeviation < Base
    # Commas and any run of whitespace are all separators; with String#split this
    # also collapses consecutive separators and ignores leading/trailing ones.
    SEPARATORS = /[,\s]+/

    # A signed decimal token (optional sign, digits with an optional fractional
    # part, or a bare fractional like ".5"). Anchored — the whole token must match.
    NUMERIC_TOKEN = /\A[-+]?(\d+(\.\d+)?|\.\d+)\z/

    MODES = %w[population sample].freeze

    DISPLAY_SCALE = 6 # decimal places for displayed statistics (half-up)
    # Working precision for BigDecimal#sqrt — far beyond the 6 dp we display, so the
    # rounded result is correct. (sqrt's argument is significant digits.)
    SQRT_PRECISION = 50

    attribute :values, :string
    attribute :mode, :string

    validates :values, presence: true
    validates :mode, presence: true, inclusion: { in: MODES }
    validate :all_tokens_numeric
    validate :at_least_one_number
    validate :sample_needs_two_values

    private

    def compute
      data  = parsed_values
      n     = data.size
      total = data.sum
      mean  = total / n
      ss    = data.sum(BigDecimal(0)) { |x| (x - mean)**2 }
      variance = ss / divisor(n)

      {
        mode:               mode,
        count:              n,
        sum:                total,
        mean:               display(mean),
        variance:           display(variance),
        standard_deviation: display(variance.sqrt(SQRT_PRECISION))
      }
    end

    # The variance denominator: n for population, n − 1 for sample. Reached only
    # from #compute (valid? is true), so sample is guaranteed n ≥ 2 here — n − 1 is
    # never zero.
    def divisor(n)
      sample? ? n - 1 : n
    end

    def sample? = mode == "sample"

    # --- display rounding (§10) -----------------------------------------------

    # Round to DISPLAY_SCALE dp, half-up — statistical outputs are always shown to a
    # fixed 6 places (text-output stat grid, not money), so 0 renders "0.000000" and
    # an integer mean renders "18.000000".
    def display(value)
      value.round(DISPLAY_SCALE, BigDecimal::ROUND_HALF_UP)
    end

    # --- parsing --------------------------------------------------------------

    # Tokens split out of the raw string, separators collapsed, leading/trailing
    # separators ignored. Empty when `values` is blank.
    def tokens
      values.to_s.split(SEPARATORS).reject(&:empty?)
    end

    # The parsed numeric list every statistic is computed from. Only called from
    # #compute, which runs only when valid? — so every token is known numeric here.
    def parsed_values
      tokens.map { |token| BigDecimal(token) }
    end

    # --- validations ----------------------------------------------------------

    # Every token must be a valid decimal; a non-numeric token invalidates the whole
    # input (label-based error, never a silent drop or a raised exception).
    def all_tokens_numeric
      return if values.blank?
      return if tokens.all? { |token| token.match?(NUMERIC_TOKEN) }

      errors.add(:values, :invalid_list, message: "must be a list of numbers")
    end

    # After parsing there must be at least one number. Skipped when blank (presence
    # owns that) — this catches a separators-only string (e.g. ", ,").
    def at_least_one_number
      return if values.blank?

      errors.add(:values, :blank) if tokens.empty?
    end

    # Sample variance divides by (n − 1), so it is undefined for a single value.
    # Only checked once we have a clean numeric list in sample mode.
    def sample_needs_two_values
      return unless sample?
      return if values.blank?
      return unless tokens.all? { |token| token.match?(NUMERIC_TOKEN) }

      errors.add(:values, :too_few, message: "need at least 2 values for sample mode") if tokens.size < 2
    end
  end
end
