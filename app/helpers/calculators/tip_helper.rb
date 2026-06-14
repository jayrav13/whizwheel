# Per-calculator helper for Tip (issue #76; split per issue #107). Holds the field-label
# map (single source of truth, DESIGN.md §4) and the quick-pick tip-rate presets.
# Auto-included into views; slug `tip` → Calculators::TipHelper::FIELD_LABELS.
module Calculators
  module TipHelper
    # The visible label for each Tip input.
    FIELD_LABELS = {
      "bill"        => "Bill amount",
      "tip_percent" => "Tip",
      "people"      => "People"
    }.freeze

    # Common restaurant tip rates offered as quick-pick chips on the Tip page (the field
    # stays directly editable, so these are pure progressive-enhancement convenience).
    PERCENT_PRESETS = [ 15, 18, 20, 25 ].freeze
    def tip_percent_presets = PERCENT_PRESETS
  end
end
