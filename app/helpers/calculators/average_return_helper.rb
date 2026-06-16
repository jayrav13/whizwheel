# Per-calculator helper for Average Return (issue #257; split per issue #107). Holds the
# field-label map (single source of truth, DESIGN.md §4), the output-stat order table the
# result grid renders from, and the fixed-4dp percentage formatter the spec requires.
# Auto-included into views; slug `average_return` → Calculators::AverageReturnHelper::FIELD_LABELS.
module Calculators
  module AverageReturnHelper
    # The visible label for the single list input (so a bad list reads "Returns …", not
    # "returns …" — DESIGN.md §4, phrase errors against the visible label).
    FIELD_LABELS = {
      "returns" => "Returns"
    }.freeze

    # How many starter rows the form server-renders. ≥ 1 so the no-JS baseline has a field
    # to fill; a few so the common multi-period case needs no "Add" tap. The Stimulus
    # controller grows/shrinks the list from here.
    STARTER_ROW_COUNT = 3

    # The two headline averages, in display order, each with its result key, a one-line
    # caption naming what it means, and whether it is the "true"/emphasised figure. The
    # geometric average is the financially meaningful one (it accounts for compounding), so
    # it leads and is lifted to accent green (DESIGN.md §1 — a derived/positive headline
    # figure). Drives the result stat grid (DESIGN.md §4 "Stat grid").
    AVERAGE_STATS = [
      { key: :geometric_average,  label: "Geometric average",  caption: "The true compounded return", emphasis: true },
      { key: :arithmetic_average, label: "Arithmetic average", caption: "The simple mean of the returns", emphasis: false }
    ].freeze

    def average_return_stats = AVERAGE_STATS

    # The starter rows the GET page renders. After a submit we re-render the SUBMITTED list
    # (so a 422 keeps what the user typed) — blanks dropped, but never below one row, so the
    # error page always shows at least one editable field. `calc` is nil on the pristine GET.
    def average_return_rows(calc)
      submitted = Array(calc&.returns).map { |entry| entry.to_s.strip }.reject(&:empty?)
      return submitted unless submitted.empty?

      Array.new(STARTER_ROW_COUNT, "")
    end

    # The submitted returns echoed back as a raw, comma-joined string — the values quoted
    # verbatim into the result's monospace `<code>` (DESIGN.md §2 "Raw / echoed data"). Reads
    # the calculator's submitted `returns`, drops blanks (the same entries the backend
    # computed over), and trims each — never re-formats them (raw echo, not a presented
    # figure). e.g. ["10", " 20 ", "", "-5"] → "10, 20, -5".
    def average_return_input_echo(calc)
      Array(calc.returns).map { |entry| entry.to_s.strip }.reject(&:empty?).join(", ")
    end

    # Format an average for display: a FIXED 4 decimal places (half-up — the backend already
    # rounded to 4dp, this pads/formats), thousands-delimited, with the sign preserved for a
    # negative average (DESIGN.md §2 tabular-nums). So 10 → "10.0000", 0 → "0.0000",
    # −0.5013 → "-0.5013", −100 → "-100.0000". A percent suffix is added in the view.
    def average_return_display(value)
      rounded = value.round(4, BigDecimal::ROUND_HALF_UP)
      whole, frac = format("%.4f", rounded).split(".")
      negative = whole.start_with?("-")
      delimited = number_with_delimiter(whole.delete("-"))
      "#{'-' if negative}#{delimited}.#{frac}"
    end
  end
end
