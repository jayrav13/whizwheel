# Per-calculator helper for the Standard Deviation calculator (frontend issue #191; spec
# #190). Holds the field-label map (single source of truth for error phrasing — DESIGN.md
# §4, phrase against the visible label) and the stat-order table the result grid renders
# from. Auto-included into views; slug `standard_deviation` →
# Calculators::StandardDeviationHelper::FIELD_LABELS.
#
# Ruby helpers are coverage-counted (ARCHITECTURE.md §11), so every method here is exercised
# by a test.
module Calculators
  module StandardDeviationHelper
    # The visible labels for the two inputs, so a validation error reads against what the
    # page rendered — "Values must be a list of numbers", not "values …" (DESIGN.md §4).
    FIELD_LABELS = {
      "values" => "Values",
      "mode"   => "Mode"
    }.freeze

    # The headline statistic — standard deviation is the calculator's namesake answer, shown
    # large on the hero row (the result key + the caption named under it).
    HEADLINE_STAT = { key: :standard_deviation, label: "Standard deviation" }.freeze

    # The four supporting figures, in display order, each with its result key, label and a
    # one-line caption — drives the result stat grid (DESIGN.md §4 "Stat grid"). `mode` is
    # echoed in the eyebrow, not as a card, so it is not listed here.
    SUPPORTING_STATS = [
      { key: :variance, label: "Variance", caption: "Mean of squared deviations" },
      { key: :mean,     label: "Mean",     caption: "Average of all values" },
      { key: :count,    label: "Count",    caption: "Number of values" },
      { key: :sum,      label: "Sum",      caption: "Total of all values" }
    ].freeze

    def std_dev_headline_stat    = HEADLINE_STAT
    def std_dev_supporting_stats = SUPPORTING_STATS

    # Format one statistic for display. `count` is a plain Integer; `sum` is an exact
    # BigDecimal; mean / variance / standard_deviation are BigDecimals the backend already
    # display-rounded to 6dp (§10). All route through the shared formatters — integers
    # delimited directly, decimals trimmed + delimited.
    def std_dev_stat_display(value)
      value.is_a?(Integer) ? number_with_delimiter(value) : decimal_display(value)
    end

    # The human label for a chosen mode — "Population" / "Sample" — used in the result
    # eyebrow so the answer states which denominator produced it (DESIGN.md §6: convey
    # meaning by text, not the segmented control's position alone).
    def std_dev_mode_label(mode)
      mode == "sample" ? "Sample" : "Population"
    end
  end
end
