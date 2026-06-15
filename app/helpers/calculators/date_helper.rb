# Per-calculator helper for the Date calculator (spec issue #195; the per-calculator
# helper pattern from issue #107). Holds the field-label map (single source of truth for
# the error-phrasing resolver, DESIGN.md §4), the two mode descriptors that drive the
# .mode-option picker, and the display helpers the result partial reaches for. Auto-included
# into views; slug `date` → Calculators::DateHelper::FIELD_LABELS.
module Calculators
  module DateHelper
    # The visible label for each Date input — the single source of truth the shared
    # error-phrasing resolver maps an error key back to (DESIGN.md §4: phrase errors
    # against the field's visible label, never the raw attribute key).
    FIELD_LABELS = {
      "mode"       => "Calculation",
      "start_date" => "Start date",
      "end_date"   => "End date",
      "operation"  => "Operation",
      "years"      => "Years",
      "months"     => "Months",
      "weeks"      => "Weeks",
      "days"       => "Days"
    }.freeze

    # The two modes, in spec order — each a multi-word label, so per DESIGN.md §4's picker
    # rule the FE renders the `.mode-option` selectable option list (not a segmented
    # control). Each carries a one-line helper naming what that mode solves.
    MODES = [
      { value: "difference",   label: "Difference between dates",
        helper: "How long between two dates" },
      { value: "add_subtract", label: "Add to or subtract from a date",
        helper: "Shift a date by years, months, weeks and days" }
    ].freeze

    # The four offset fields (used only by add_subtract), coarse-to-fine, for the form row.
    OFFSET_FIELDS = [
      { key: :years,  label: "Years" },
      { key: :months, label: "Months" },
      { key: :weeks,  label: "Weeks" },
      { key: :days,   label: "Days" }
    ].freeze

    # Reach the constants from a template (templates see the module's methods, not its
    # constants).
    def date_modes = MODES
    def date_offset_fields = OFFSET_FIELDS

    # The Y/M/D breakdown phrase for a `difference` result, dropping any leading-zero unit
    # so "2 years 2 months 5 days" reads naturally and a "0 years 0 months 2 days" diff
    # reads "2 days" — but never empty: a same-date diff (all zeros) still reads "0 days".
    # Each unit is singular/plural correct ("1 day", "2 days").
    def date_breakdown_phrase(result)
      parts = [ [ :years, result[:years] ], [ :months, result[:months] ], [ :days, result[:days] ] ]
        .reject { |_unit, count| count.zero? }
        .map { |unit, count| "#{number_with_delimiter(count)} #{count == 1 ? unit.to_s.singularize : unit}" }
      parts.empty? ? "0 days" : parts.join(" · ")
    end

    # The weeks-and-days phrase for a `difference` result: "113 weeks and 4 days", with
    # singular/plural correctness ("1 week and 1 day") and thousands delimiters so a large
    # span reads "14,192 weeks", matching the stat cards. Always names both units so the
    # weeks view reads as a complete sentence even when one part is zero.
    def date_weeks_phrase(result)
      weeks = result[:total_weeks]
      days  = result[:remainder_days]
      "#{number_with_delimiter(weeks)} #{'week'.pluralize(weeks)} and " \
        "#{number_with_delimiter(days)} #{'day'.pluralize(days)}"
    end

    # Format an ISO "YYYY-MM-DD" date string from the envelope as a long, human date
    # ("Saturday, March 1, 2025") for the add_subtract result headline. The backend emits
    # the result/echo dates as ISO strings (§4); the FE only presents them.
    def date_long_format(iso_string)
      ::Date.iso8601(iso_string).strftime("%A, %B %-d, %Y")
    end
  end
end
