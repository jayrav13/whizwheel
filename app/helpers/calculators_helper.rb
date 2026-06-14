# Display-only formatting + per-mode copy for calculator pages, and the label-based
# validation-error phrasing required by DESIGN.md §4. Ruby helpers are coverage-counted
# (ARCHITECTURE.md §11), so every branch here is exercised by a test.
module CalculatorsHelper
  # The visible label for each Percentage input — the single source the page renders
  # AND the source the error phrasing maps an attribute key back to (DESIGN.md §4:
  # "phrase each message against the field's visible label, never the raw key").
  PERCENTAGE_FIELD_LABELS = {
    "v1"        => "Value (V1)",
    "v2"        => "Value (V2)",
    "percent"   => "Percent (P)",
    "direction" => "Direction"
  }.freeze

  # Per-mode caption above the hero result number.
  PERCENTAGE_RESULT_CAPTIONS = {
    "percent_of"      => "Result",
    "what_percent"    => "Percentage",
    "percent_of_what" => "The whole",
    "difference"      => "Percentage difference",
    "change"          => "New value"
  }.freeze

  # Format a BigDecimal for display (ARCHITECTURE.md §10 — round only for display):
  # round to 6dp, trim trailing zeros, and delimit thousands. Keeps the figure exact
  # for the reference values (all terminate well within 6dp) while staying readable.
  def percentage_display(value)
    rounded = value.round(6)
    whole = rounded.frac.zero?
    number = whole ? rounded.to_i.to_s : rounded.to_s("F").sub(/0+\z/, "")
    number_with_delimiter(number)
  end

  # The caption above the hero number, by mode (with a safe fallback).
  def percentage_result_caption(mode)
    PERCENTAGE_RESULT_CAPTIONS.fetch(mode, "Result")
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

  # The label map for a calculator instance — Percentage has a bespoke map; anything
  # else gets none (the error phrasing then falls back to a humanized attribute).
  def field_labels_for(calc)
    case calc
    when Calculators::Percentage then PERCENTAGE_FIELD_LABELS
    else {}
    end
  end

  # Turn an ActiveModel errors object into label-led sentences (DESIGN.md §4). A
  # field error reads "<visible label> <message>"; a whole-record (:base) error is a
  # full sentence with no label prefix. The label comes from what the page rendered.
  def calculator_error_messages(calc)
    labels = field_labels_for(calc)
    calc.errors.map do |error|
      attribute = error.attribute.to_s
      if attribute == "base"
        error.message
      else
        label = labels[attribute] || attribute.humanize
        "#{label} #{error.message}"
      end
    end
  end
end
