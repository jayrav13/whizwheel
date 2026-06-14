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

  # The visible label for each Ohm's Law input (issue #55) — like the Percentage map,
  # the single source the page renders AND the source the error phrasing maps an
  # attribute key back to (DESIGN.md §4: phrase against the visible label).
  OHMS_LAW_FIELD_LABELS = {
    "voltage"    => "Voltage (V)",
    "current"    => "Current (I)",
    "resistance" => "Resistance (R)",
    "power"      => "Power (P)"
  }.freeze

  # The four Ohm's Law quantities in V/I/R/P order, each with its label, SI unit, and
  # which result key it reads — drives the result render (§4). The order is fixed so the
  # solved-quantity grid always reads V, I, R, P regardless of which pair was supplied.
  OHMS_LAW_QUANTITIES = [
    { key: :voltage,    label: "Voltage",    unit: "V", symbol: "V" },
    { key: :current,    label: "Current",    unit: "A", symbol: "I" },
    { key: :resistance, label: "Resistance", unit: "Ω", symbol: "R" },
    { key: :power,      label: "Power",      unit: "W", symbol: "P" }
  ].freeze

  # Format a BigDecimal for display (ARCHITECTURE.md §10 — round only for display):
  # round to 6dp, trim trailing zeros, and delimit thousands. Keeps the figure exact
  # for the reference values (all terminate well within 6dp) while staying readable.
  def decimal_display(value)
    rounded = value.round(6)
    whole = rounded.frac.zero?
    number = whole ? rounded.to_i.to_s : rounded.to_s("F").sub(/0+\z/, "")
    number_with_delimiter(number)
  end
  alias_method :percentage_display, :decimal_display

  # The four Ohm's Law quantities, V/I/R/P order, for the result render — a helper so
  # the view reaches the constant without qualifying it (templates don't include the
  # helper module's constants, only its methods).
  def ohms_law_quantities = OHMS_LAW_QUANTITIES

  # The given pair (a Set of result keys) for an Ohm's Law calc — the two quantities
  # the user supplied for the selected mode. Those echo back; the other two are solved
  # and get highlighted in the render (spec issue #55: "highlight the two it solved").
  def ohms_law_given_keys(calc)
    Calculators::OhmsLaw::REQUIRED_INPUTS.fetch(calc.mode, []).to_set
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

  # The visible label for each BMI input (issue #53) — same single-source-of-truth role
  # as the Percentage map: the page renders these AND the error phrasing maps a key back
  # to them (DESIGN.md §4 — phrase against the visible label, never the raw key).
  BMI_FIELD_LABELS = {
    "unit_system" => "Unit system",
    "weight"      => "Weight",
    "height"      => "Height"
  }.freeze

  # The WHO adult classification scale (issue #53): the band segments the page draws as a
  # thin stacked bar (DESIGN.md §4 "Charts — thin stacked bar"). The backend owns the
  # math (Calculators::Bmi::BANDS); this is display-only metadata — a visible BMI range, a
  # human label, and the band's [lower, upper) bounds within the plotted 15–40 window so
  # the segments size proportionally without a runaway open-ended slice.
  #
  # The finer WHO bands (Severe/Moderate/Mild Thinness, Obese Class I–III) collapse into
  # these four broad bins for the bar; the precise band text comes from `category`.
  BMI_SCALE_MIN = 15.0
  BMI_SCALE_MAX = 40.0
  BMI_BANDS = [
    { label: "Underweight", range: "< 18.5", lower: 15.0, upper: 18.5 },
    { label: "Normal",      range: "18.5–25", lower: 18.5, upper: 25.0 },
    { label: "Overweight",  range: "25–30",   lower: 25.0, upper: 30.0 },
    { label: "Obese",       range: "≥ 30",    lower: 30.0, upper: 40.0 }
  ].freeze

  # The four broad scale bands, each with its percentage width of the 15–40 window and
  # whether the given BMI falls in it (so the view highlights the active segment). A nil
  # BMI (pristine state never renders the scale, but keep it total) marks none active.
  def bmi_scale_bands(bmi)
    span = BMI_SCALE_MAX - BMI_SCALE_MIN
    value = bmi&.to_f
    BMI_BANDS.map do |band|
      width = (band[:upper] - band[:lower]) / span * 100
      active = !value.nil? && value >= band[:lower] && value < band[:upper]
      band.merge(width: width, active: active)
    end
  end

  # Where the marker sits along the 15–40 bar, as a left-offset percentage clamped to the
  # window so an off-the-chart BMI still lands on the bar (a BMI of 12 pins to 0%, 45 to 100%).
  def bmi_marker_position(bmi)
    clamped = bmi.to_f.clamp(BMI_SCALE_MIN, BMI_SCALE_MAX)
    (clamped - BMI_SCALE_MIN) / (BMI_SCALE_MAX - BMI_SCALE_MIN) * 100
  end

  # BMI for display (ARCHITECTURE.md §10 — the calculator already rounds `bmi` to 1dp;
  # render it with a fixed single decimal so 23 reads "23.0", keeping the figure aligned).
  def bmi_display(value)
    format("%.1f", value)
  end

  # The visible label for each Age input (issue #82) — same single-source-of-truth role
  # as the other maps: the page renders these AND the error phrasing maps an attribute
  # key back to them (DESIGN.md §4 — phrase against the visible label, never the raw key).
  AGE_FIELD_LABELS = {
    "birth_date" => "Date of birth",
    "end_date"   => "Age at the date of"
  }.freeze

  # The four total-unit conversions the Age result reports beneath the Y/M/D breakdown,
  # in coarse-to-fine order, each with its result key and a human label. Drives the
  # Age result stat grid (DESIGN.md §4 "Stat grid") so the same interval reads four ways.
  AGE_TOTAL_UNITS = [
    { key: :total_months, label: "Months" },
    { key: :total_weeks,  label: "Weeks" },
    { key: :total_days,   label: "Days" },
    { key: :total_hours,  label: "Hours" }
  ].freeze

  # The four Age total-unit conversions, coarse-to-fine, for the result render — a helper
  # so the view reaches the constant without qualifying it (templates see the module's
  # methods, not its constants).
  def age_total_units = AGE_TOTAL_UNITS

  # A whole-integer count for display (the Age outputs are all integers — ARCHITECTURE.md
  # §10, no rounding) with thousands delimiters so large spans (12,418 days) stay readable
  # and align under tabular-nums.
  def integer_display(value)
    number_with_delimiter(value.to_i)
  end

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

  # The visible label for each Simple Interest input (issue #78) — same single-source-of-
  # truth role as the other maps: the page renders these AND the error phrasing maps a key
  # back to them (DESIGN.md §4 — phrase against the visible label, never the raw key).
  SIMPLE_INTEREST_FIELD_LABELS = {
    "principal" => "Principal",
    "rate"      => "Annual rate",
    "time"      => "Time",
    "unit"      => "Time unit"
  }.freeze

  # Money for display (ARCHITECTURE.md §10 — round only for display): a fixed two
  # decimal places, half-up, thousands-delimited. Simple Interest's outputs are money
  # (interest, total), so they always read with cents — "150.00", "1,150.00".
  def money_display(value)
    rounded = value.round(2, BigDecimal::ROUND_HALF_UP)
    number_with_delimiter(format("%.2f", rounded))
  end

  # The label map for a calculator instance — Percentage, Ohm's Law, BMI, Age and Simple
  # Interest have bespoke maps; anything else gets none (error phrasing then falls back to
  # a humanized attribute).
  def field_labels_for(calc)
    case calc
    when Calculators::Percentage     then PERCENTAGE_FIELD_LABELS
    when Calculators::OhmsLaw        then OHMS_LAW_FIELD_LABELS
    when Calculators::Bmi            then BMI_FIELD_LABELS
    when Calculators::Age            then AGE_FIELD_LABELS
    when Calculators::SimpleInterest then SIMPLE_INTEREST_FIELD_LABELS
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
