# Per-calculator helper for Percentage (issue #107 — convention-based discovery so
# adding a calculator drops in its own helper file and edits no shared file). Holds the
# Percentage field-label map (its single source of truth — the page renders these AND
# field_labels_for maps an error key back to them, DESIGN.md §4) plus the Percentage
# result copy. Rails auto-includes this into views (include_all_helpers), and the slug
# `percentage` resolves to `Calculators::PercentageHelper::FIELD_LABELS` in field_labels_for.
module Calculators
  module PercentageHelper
    # The visible label for each Percentage input.
    FIELD_LABELS = {
      "v1"        => "Value (V1)",
      "v2"        => "Value (V2)",
      "percent"   => "Percent (P)",
      "direction" => "Direction"
    }.freeze

    # Per-mode caption above the hero result number.
    RESULT_CAPTIONS = {
      "percent_of"      => "Result",
      "what_percent"    => "Percentage",
      "percent_of_what" => "The whole",
      "difference"      => "Percentage difference",
      "change"          => "New value"
    }.freeze

    # The caption above the hero number, by mode (with a safe fallback).
    def percentage_result_caption(mode)
      RESULT_CAPTIONS.fetch(mode, "Result")
    end

    # A short human sentence describing what was computed, by mode — shown under the
    # hero number so the answer reads in context ("20% of 50").
    def percentage_result_detail(calc)
      v1 = percentage_display(calc.v1) if calc.v1
      v2 = percentage_display(calc.v2) if calc.v2
      p  = percentage_display(calc.percent) if calc.percent

      case calc.mode
      when "percent_of"      then "#{p}% of #{v1}"
      when "what_percent"    then "#{v1} is this percent of #{v2}"
      when "percent_of_what" then "#{v1} is #{p}% of this amount"
      when "difference"      then "between #{v1} and #{v2}"
      when "change"          then "#{v1} #{calc.direction == 'increase' ? 'increased' : 'decreased'} by #{p}%"
      end
    end
  end
end
