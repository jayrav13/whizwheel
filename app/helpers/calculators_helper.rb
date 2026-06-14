# View helpers for the calculator pages. Display-only formatting + per-mode copy
# for the Percentage page (issue #31): the math lives in Calculators::Percentage;
# here we only render its computed result and label it for the chosen mode.
module CalculatorsHelper
  # Human label above the hero number, by mode (DESIGN.md eyebrow / §4 Hero-result).
  PERCENTAGE_CAPTIONS = {
    "percent_of"      => "Result",
    "what_percent"    => "Percentage",
    "percent_of_what" => "The whole",
    "difference"      => "Percentage difference",
    "change"          => "New value"
  }.freeze

  def percentage_result_caption(mode)
    PERCENTAGE_CAPTIONS.fetch(mode, "Result")
  end

  # Format a computed BigDecimal/number for display: trim trailing zeros so exact
  # results read cleanly (10.0 → "10", 12.5 → "12.5"), but keep full precision for
  # non-terminating values. Compute stays at full precision (ARCHITECTURE.md §10);
  # this is display-only.
  def percentage_display(value)
    # BigDecimal#to_s("F") always emits a decimal point (e.g. "10.0", "0.0"), so the
    # trailing-zero trim is unconditional — no integer-without-point case to guard.
    formatted = BigDecimal(value.to_s).round(6).to_s("F").sub(/\.?0+\z/, "")
    number_with_delimiter(formatted)
  end

  # Visible-label map for the Percentage page's fields — the exact labels the form
  # renders (DESIGN.md §4: phrase validation errors against the field's visible
  # label, never the raw attribute key). Keyed by the attribute symbol the envelope
  # returns; presentation-only (no math), so it lives in the FE layer.
  PERCENTAGE_FIELD_LABELS = {
    mode:      "Mode",
    v1:        "Value (V1)",
    v2:        "Value (V2)",
    percent:   "Percent (P)",
    direction: "Direction"
  }.freeze

  # Render the envelope's validation errors phrased against each field's *visible
  # label* — "Value (V1) can't be blank", not "V1 can't be blank" (DESIGN.md §4).
  # We rebuild each message from the raw error (attribute + message) rather than
  # ActiveModel's full_messages so the human label leads. Falls back to the
  # humanized attribute for any field without a mapped label, keeping the shared
  # error partial honest for other calculators.
  def calculator_error_messages(calc)
    labels = field_labels_for(calc)
    calc.errors.map do |error|
      label = labels.fetch(error.attribute) { error.attribute.to_s.humanize }
      base_error?(error) ? error.message : "#{label} #{error.message}"
    end
  end

  # The error :base attribute carries a whole-record message (e.g. a guard like a
  # division-by-zero check) that already reads as a full sentence — show it as-is,
  # with no label prefix.
  def base_error?(error)
    error.attribute == :base
  end

  # The label map for a given calculator. Percentage has a bespoke map; anything
  # else falls back to humanized attribute names (handled in the caller).
  def field_labels_for(calc)
    calc.is_a?(Calculators::Percentage) ? PERCENTAGE_FIELD_LABELS : {}
  end

  # A plain-language restatement of the answer, by mode, echoing the inputs so the
  # result is self-explanatory (never relying on the form alone).
  def percentage_result_detail(calc)
    case calc.mode
    when "percent_of"
      "#{percentage_display(calc.percent)}% of #{percentage_display(calc.v1)}"
    when "what_percent"
      "#{percentage_display(calc.v1)} is this percent of #{percentage_display(calc.v2)}"
    when "percent_of_what"
      "#{percentage_display(calc.v1)} is #{percentage_display(calc.percent)}% of this amount"
    when "difference"
      "between #{percentage_display(calc.v1)} and #{percentage_display(calc.v2)}"
    else # "change"
      "#{percentage_display(calc.v1)} #{calc.direction == 'increase' ? 'increased' : 'decreased'} by #{percentage_display(calc.percent)}%"
    end
  end
end
