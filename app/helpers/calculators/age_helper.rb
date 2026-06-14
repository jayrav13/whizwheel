# Per-calculator helper for Age (issue #82; split per issue #107). Holds the field-label
# map (single source of truth, DESIGN.md §4), the total-unit conversion table, and the
# Y/M/D breakdown phrase. Auto-included into views; slug `age` →
# Calculators::AgeHelper::FIELD_LABELS.
module Calculators
  module AgeHelper
    # The visible label for each Age input.
    FIELD_LABELS = {
      "birth_date" => "Date of birth",
      "end_date"   => "Age at the date of"
    }.freeze

    # The four total-unit conversions the Age result reports beneath the Y/M/D breakdown,
    # in coarse-to-fine order, each with its result key and a human label. Drives the
    # Age result stat grid (DESIGN.md §4 "Stat grid") so the same interval reads four ways.
    TOTAL_UNITS = [
      { key: :total_months, label: "Months" },
      { key: :total_weeks,  label: "Weeks" },
      { key: :total_days,   label: "Days" },
      { key: :total_hours,  label: "Hours" }
    ].freeze

    # The four Age total-unit conversions, coarse-to-fine, for the result render — a helper
    # so the view reaches the constant without qualifying it (templates see the module's
    # methods, not its constants).
    def age_total_units = TOTAL_UNITS

    # The "33 years · 11 months · 30 days" breakdown phrase from an Age result, dropping any
    # leading zero units so a 24y-0m-0d age reads "24 years", not "24 years 0 months 0 days"
    # — but never empty: a same-day age (all zeros) still reads "0 days". Each unit is
    # singular/plural correct ("1 year", "2 years").
    def age_breakdown_phrase(result)
      parts = [ [ :years, result[:years] ], [ :months, result[:months] ], [ :days, result[:days] ] ]
        .reject { |_unit, count| count.zero? }
        .map { |unit, count| "#{count} #{count == 1 ? unit.to_s.singularize : unit}" }
      parts.empty? ? "0 days" : parts.join(" · ")
    end
  end
end
