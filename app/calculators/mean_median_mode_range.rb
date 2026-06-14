module Calculators
  # calculator.net's Mean, Median, Mode, Range page (spec issue #79). The project's
  # first VARIABLE-LENGTH LIST input: `numbers` arrives as a single string and the
  # calculator owns the parse (ARCHITECTURE.md §3.2 — do not require the controller
  # to pre-parse).
  #
  # The list is split on commas and/or any whitespace (collapsing consecutive
  # separators, ignoring leading/trailing ones), each token coerced to BigDecimal.
  # Any non-numeric token makes the whole input invalid (a label-based validation
  # error, not a 500) — bad tokens are never silently dropped. After parsing there
  # must be at least one number (presence).
  #
  # Outputs the eight descriptive statistics. `mode` is an ARRAY (sorted ascending):
  # empty for "no mode" (all values unique), one element for unimodal, several when
  # the set is multimodal. `mean` and a fractional `median` are rounded to 3 dp for
  # display; everything is computed at full BigDecimal precision first (§10).
  class MeanMedianModeRange < Base
    # Commas and any run of whitespace are all separators; this also collapses
    # consecutive separators when used with String#split.
    SEPARATORS = /[,\s]+/

    # A signed decimal token (optional sign, digits with an optional fractional
    # part, or a bare fractional like ".5"). Anchored so the whole token must match.
    NUMERIC_TOKEN = /\A[-+]?(\d+(\.\d+)?|\.\d+)\z/

    DISPLAY_SCALE = 3 # decimal places for display-rounded mean / fractional median
    TWO = BigDecimal(2)

    attribute :numbers, :string

    validates :numbers, presence: true
    validate :all_tokens_numeric
    validate :at_least_one_number

    private

    def compute
      values = parsed_numbers
      sorted = values.sort
      total  = values.sum

      {
        mean:     display(total / values.size),
        median:   display(median_of(sorted)),
        mode:     modes_of(values),
        range:    sorted.last - sorted.first,
        sum:      total,
        count:    values.size,
        smallest: sorted.first,
        largest:  sorted.last
      }
    end

    # --- statistics -----------------------------------------------------------

    # Middle value for an odd count; the average of the two middle values for an
    # even count. Operates on the already-sorted list.
    def median_of(sorted)
      mid = sorted.size / 2
      if sorted.size.odd?
        sorted[mid]
      else
        (sorted[mid - 1] + sorted[mid]) / TWO
      end
    end

    # All value(s) tied for the highest frequency, sorted ascending. Empty when the
    # maximum frequency is 1 (every value unique) — "no mode", never an arbitrary pick.
    def modes_of(values)
      counts = values.tally
      top = counts.values.max
      return [] if top == 1

      counts.select { |_value, freq| freq == top }.keys.sort
    end

    # --- display rounding (§10) -----------------------------------------------

    # Round to DISPLAY_SCALE dp, half-up. Exact integers are returned whole (no
    # trailing .000) so the frontend renders "3" not "3.000"; values with a
    # fractional part are rounded to 3 dp for display.
    def display(value)
      return value if value.frac.zero?

      value.round(DISPLAY_SCALE, BigDecimal::ROUND_HALF_UP)
    end

    # --- parsing --------------------------------------------------------------

    # Tokens split out of the raw string, separators collapsed, leading/trailing
    # separators ignored. Empty when `numbers` is blank.
    def tokens
      numbers.to_s.split(SEPARATORS).reject(&:empty?)
    end

    # The parsed numeric list every statistic is computed from. Only called from
    # #compute, which runs only when valid? — so every token is known numeric here.
    def parsed_numbers
      tokens.map { |token| BigDecimal(token) }
    end

    # --- validations ----------------------------------------------------------

    # Every token must be a valid decimal; a non-numeric token invalidates the whole
    # input (label-based error, never a silent drop or a raised exception).
    def all_tokens_numeric
      bad = tokens.reject { |token| token.match?(NUMERIC_TOKEN) }
      return if bad.empty?

      errors.add(:numbers, :invalid_number, bad: bad.join(", "),
        message: "contains a value that is not a number: #{bad.join(', ')}")
    end

    # After parsing there must be at least one number. Skipped when the string is
    # blank (the presence validation already reports that) — this catches the case
    # of a string that is all separators (e.g. ", ,") and so parses to nothing.
    def at_least_one_number
      return if numbers.blank?

      errors.add(:numbers, :blank) if tokens.empty?
    end
  end
end
