# Per-calculator helper for Simple Interest (issue #78; split per issue #107). Holds the
# field-label map (single source of truth, DESIGN.md §4); its result render uses the shared
# decimal_display / money_display formatters in CalculatorsHelper. Auto-included into
# views; slug `simple_interest` → Calculators::SimpleInterestHelper::FIELD_LABELS.
module Calculators
  module SimpleInterestHelper
    # The visible label for each Simple Interest input.
    FIELD_LABELS = {
      "principal" => "Principal",
      "rate"      => "Annual rate",
      "time"      => "Time",
      "unit"      => "Time unit"
    }.freeze
  end
end
