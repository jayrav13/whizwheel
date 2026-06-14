# Per-calculator helper for Mean / Median / Mode / Range (issue #80; split per issue
# #107). Holds the field-label map (single source of truth, DESIGN.md §4), the stat-order
# tables the result grids render from, and the mode-array → phrase render. Auto-included
# into views; slug `mean_median_mode_range` → Calculators::MeanMedianModeRangeHelper::FIELD_LABELS.
module Calculators
  module MeanMedianModeRangeHelper
    # The visible label for the single input (so a bad list reads "Numbers contains a value
    # that is not a number", not "numbers …" — DESIGN.md §4, phrase against the visible label).
    FIELD_LABELS = {
      "numbers" => "Numbers"
    }.freeze

    # The three "central + spread" headline statistics, in display order, each with its
    # result key and a one-line caption — drives the primary stat grid on the result
    # (DESIGN.md §4 Stat grid). `mode` is rendered on its own hero row (its value is an
    # array — the deliberate non-scalar output, spec issue #80), so it is not listed here.
    PRIMARY_STATS = [
      { key: :mean,   label: "Mean",   caption: "Average of all values" },
      { key: :median, label: "Median", caption: "Middle value" },
      { key: :range,  label: "Range",  caption: "Largest − smallest" }
    ].freeze

    # The four supporting figures, in display order — the secondary stat row beneath the
    # headline statistics (sum / count / smallest / largest).
    SUPPORTING_STATS = [
      { key: :sum,      label: "Sum" },
      { key: :count,    label: "Count" },
      { key: :smallest, label: "Smallest" },
      { key: :largest,  label: "Largest" }
    ].freeze

    def mmr_primary_stats    = PRIMARY_STATS
    def mmr_supporting_stats = SUPPORTING_STATS

    # Format one statistic for display. `count` is a plain Integer; every other figure is a
    # BigDecimal the backend already display-rounded (§10). Integers delimit thousands
    # directly; decimals route through decimal_display (whole-number-aware + delimited).
    def mmr_stat_display(value)
      value.is_a?(Integer) ? number_with_delimiter(value) : decimal_display(value)
    end

    # The mode array rendered as a human phrase (DESIGN.md §4 — the interesting render
    # question on this calculator). Empty → "No mode"; one value → that value; several →
    # "a, b and c" so a multimodal set reads naturally ("23 and 38").
    def mmr_mode_display(modes)
      return "No mode" if modes.empty?

      formatted = modes.map { |m| decimal_display(m) }
      return formatted.first if formatted.one?

      "#{formatted[0..-2].join(', ')} and #{formatted.last}"
    end
  end
end
