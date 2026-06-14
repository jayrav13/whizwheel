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
