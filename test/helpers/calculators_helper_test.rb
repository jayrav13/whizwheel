require "test_helper"

# Unit tests for CalculatorsHelper — the display-only formatting + per-mode copy
# for the Percentage page. Ruby helpers are coverage-counted (ARCHITECTURE.md §11),
# so every branch here is exercised.
class CalculatorsHelperTest < ActionView::TestCase
  # ── percentage_display ──────────────────────────────────────────────────

  test "trims trailing zeros after the decimal point" do
    assert_equal "10", percentage_display(BigDecimal("10.0"))
  end

  test "keeps a meaningful fractional part" do
    assert_equal "12.5", percentage_display(BigDecimal("12.5"))
  end

  test "rounds long decimals to six places for display" do
    assert_equal "33.333333", percentage_display(BigDecimal("33.3333333333"))
  end

  test "renders an integer-valued result without a decimal point" do
    assert_equal "1,000", percentage_display(BigDecimal("1000.0"))
  end

  test "delimits thousands" do
    assert_equal "1,234.5", percentage_display(BigDecimal("1234.5"))
  end

  test "handles a plain zero" do
    assert_equal "0", percentage_display(BigDecimal("0"))
  end

  # ── percentage_result_caption ───────────────────────────────────────────

  test "caption is per-mode" do
    assert_equal "Result", percentage_result_caption("percent_of")
    assert_equal "Percentage", percentage_result_caption("what_percent")
    assert_equal "The whole", percentage_result_caption("percent_of_what")
    assert_equal "Percentage difference", percentage_result_caption("difference")
    assert_equal "New value", percentage_result_caption("change")
  end

  test "caption falls back for an unknown mode" do
    assert_equal "Result", percentage_result_caption("nonsense")
  end

  # ── percentage_result_detail (one branch per mode) ──────────────────────

  def calc(attrs)
    Calculators::Percentage.new(attrs)
  end

  test "detail for percent_of" do
    assert_equal "20% of 50", percentage_result_detail(calc(mode: "percent_of", v1: "50", percent: "20"))
  end

  test "detail for what_percent" do
    assert_equal "10 is this percent of 50", percentage_result_detail(calc(mode: "what_percent", v1: "10", v2: "50"))
  end

  test "detail for percent_of_what" do
    assert_equal "10 is 20% of this amount", percentage_result_detail(calc(mode: "percent_of_what", v1: "10", percent: "20"))
  end

  test "detail for difference" do
    assert_equal "between 10 and 6", percentage_result_detail(calc(mode: "difference", v1: "10", v2: "6"))
  end

  test "detail for change increase" do
    assert_equal "500 increased by 10%", percentage_result_detail(calc(mode: "change", v1: "500", percent: "10", direction: "increase"))
  end

  test "detail for change decrease" do
    assert_equal "500 decreased by 10%", percentage_result_detail(calc(mode: "change", v1: "500", percent: "10", direction: "decrease"))
  end

  test "detail returns nil for an unknown mode" do
    # The case has no else — an unrecognized mode yields nil (never rendered, since the
    # detail only shows on a valid result whose mode is one of the five).
    assert_nil percentage_result_detail(calc(mode: "nonsense", v1: "1"))
  end

  test "detail tolerates absent inputs (the value guards fall through)" do
    # Exercises the `... if calc.vN` false branches — a calc with no numbers still
    # produces a (degenerate) sentence rather than raising on a nil format.
    assert_equal "% of ", percentage_result_detail(calc(mode: "percent_of"))
  end

  # ── calculator_error_messages (label-based phrasing, DESIGN.md §4) ───────

  test "phrases blank errors against the field's visible label, not the raw key" do
    c = calc(mode: "percent_of", v1: "", percent: "")
    c.valid?
    messages = calculator_error_messages(c)
    assert_includes messages, "Value (V1) can't be blank"
    assert_includes messages, "Percent (P) can't be blank"
    # Never the raw attribute key.
    assert_empty messages.grep(/\bV1 can't be blank\b/)
  end

  test "phrases the direction error against its visible label" do
    c = calc(mode: "change", v1: "5", percent: "10", direction: "")
    c.valid?
    assert_includes calculator_error_messages(c), "Direction can't be blank"
  end

  test "phrases a division-by-zero field error against its label" do
    c = calc(mode: "percent_of_what", v1: "10", percent: "0")
    c.valid?
    assert_includes calculator_error_messages(c), "Percent (P) must be other than 0"
  end

  test "shows a :base whole-record error as a full sentence, with no label prefix" do
    c = calc(mode: "difference", v1: "5", v2: "-5")
    c.valid?
    messages = calculator_error_messages(c)
    assert_includes messages, "must be other than 0"
    # No attribute label is prepended to a base error.
    assert_empty messages.grep(/\ABase /)
  end

  # A non-Percentage calculator with no bespoke label map — exercises the
  # humanized-attribute fallback so the shared error partial stays honest.
  class UnmappedCalc
    include ActiveModel::Model
    attr_accessor :widget_count
    validates :widget_count, presence: true
  end

  test "falls back to a humanized attribute for an unmapped calculator/field" do
    other = UnmappedCalc.new
    other.valid?
    assert_equal [ "Widget count can't be blank" ], calculator_error_messages(other)
    assert_empty field_labels_for(other)
  end

  # ── Ohm's Law (issue #55) ───────────────────────────────────────────────

  test "decimal_display is the shared formatter percentage_display aliases" do
    # Same formatting contract under the calculator-agnostic name (it formats the
    # Ohm's Law quantities just as percentage_display formats percentages).
    assert_equal "12",    decimal_display(BigDecimal("12.0"))
    assert_equal "0.5",   decimal_display(BigDecimal("0.5"))
    assert_equal "1,234", decimal_display(BigDecimal("1234"))
  end

  def ohms(attrs)
    Calculators::OhmsLaw.new(attrs)
  end

  test "ohms_law_given_keys is the pair the mode supplies" do
    assert_equal Set[:voltage, :current], ohms_law_given_keys(ohms(mode: "vi"))
    assert_equal Set[:resistance, :power], ohms_law_given_keys(ohms(mode: "rp"))
  end

  test "ohms_law_given_keys is empty for an unset/unknown mode" do
    assert_empty ohms_law_given_keys(ohms(mode: nil))
  end

  test "ohms_law_quantities lists V/I/R/P in order with units and symbols" do
    assert_equal %i[voltage current resistance power], ohms_law_quantities.map { |q| q[:key] }
    assert_equal %w[V A Ω W], ohms_law_quantities.map { |q| q[:unit] }
    assert_equal CalculatorsHelper::OHMS_LAW_QUANTITIES, ohms_law_quantities
  end

  test "field_labels_for maps the Ohm's Law inputs to their visible labels" do
    assert_equal CalculatorsHelper::OHMS_LAW_FIELD_LABELS, field_labels_for(ohms(mode: "vi"))
  end

  test "phrases Ohm's Law blank errors against the field's visible label" do
    c = ohms(mode: "vi", voltage: "", current: "")
    c.valid?
    messages = calculator_error_messages(c)
    assert_includes messages, "Voltage (V) can't be blank"
    assert_includes messages, "Current (I) can't be blank"
  end

  test "phrases an Ohm's Law division-by-zero error against its label" do
    c = ohms(mode: "vi", voltage: "12", current: "0")
    c.valid?
    assert_includes calculator_error_messages(c), "Current (I) must be other than 0"
  end

  # ── BMI helpers (issue #53) ─────────────────────────────────────────────

  def bmi(attrs)
    Calculators::Bmi.new(attrs)
  end

  # bmi_display — the calculator rounds to 1dp; the helper renders a fixed single decimal.
  test "bmi_display renders an integer-valued BMI with a trailing .0" do
    assert_equal "23.0", bmi_display(BigDecimal("23.0"))
  end

  test "bmi_display keeps the single decimal of a fractional BMI" do
    assert_equal "31.6", bmi_display(BigDecimal("31.6"))
  end

  # bmi_scale_bands — four broad WHO bins, each with its window-share width and whether
  # it contains the given BMI (exactly one active for an in-window BMI).
  test "bmi_scale_bands returns the four broad WHO bins with proportional widths" do
    bands = bmi_scale_bands(BigDecimal("23.0"))
    assert_equal %w[Underweight Normal Overweight Obese], bands.map { |b| b[:label] }
    # The 15–40 window is 25 wide; Normal (18.5–25) is 6.5 wide → 26%.
    assert_in_delta 26.0, bands[1][:width], 0.001
    # The widths cover the whole window.
    assert_in_delta 100.0, bands.sum { |b| b[:width] }, 0.001
  end

  test "bmi_scale_bands marks exactly the band containing the BMI active" do
    bands = bmi_scale_bands(BigDecimal("23.0")) # Normal
    assert_equal [ "Normal" ], bands.select { |b| b[:active] }.map { |b| b[:label] }
  end

  test "bmi_scale_bands respects the [lower, upper) boundary (25.0 is Overweight)" do
    bands = bmi_scale_bands(BigDecimal("25.0"))
    assert_equal [ "Overweight" ], bands.select { |b| b[:active] }.map { |b| b[:label] }
  end

  test "bmi_scale_bands marks none active for a nil BMI" do
    bands = bmi_scale_bands(nil)
    assert_empty bands.select { |b| b[:active] }
  end

  # bmi_marker_position — a left-offset percentage along the 15–40 window, clamped.
  test "bmi_marker_position places a mid-window BMI proportionally" do
    # 25 sits 10 into a 25-wide window → 40%.
    assert_in_delta 40.0, bmi_marker_position(BigDecimal("25.0")), 0.001
  end

  test "bmi_marker_position clamps a below-window BMI to 0%" do
    assert_in_delta 0.0, bmi_marker_position(BigDecimal("12.0")), 0.001
  end

  test "bmi_marker_position clamps an above-window BMI to 100%" do
    assert_in_delta 100.0, bmi_marker_position(BigDecimal("45.0")), 0.001
  end

  # field_labels_for / calculator_error_messages — BMI's bespoke label map.
  test "field_labels_for returns the BMI label map for a Bmi instance" do
    assert_equal "Weight", field_labels_for(bmi({}))["weight"]
    assert_equal "Height", field_labels_for(bmi({}))["height"]
    assert_equal "Unit system", field_labels_for(bmi({}))["unit_system"]
  end

  test "BMI errors are phrased against the visible labels, not the raw keys" do
    c = bmi(unit_system: "metric", weight: "", height: "")
    c.valid?
    messages = calculator_error_messages(c)
    assert_includes messages, "Weight can't be blank"
    assert_includes messages, "Height can't be blank"
  end

  # ── Mean / Median / Mode / Range (issue #80) ────────────────────────────

  def mmr(attrs)
    Calculators::MeanMedianModeRange.new(attrs)
  end

  # mmr_stat_display — Integer count delimits directly; BigDecimal figures route through
  # decimal_display (whole-number-aware, trailing-zero-trimmed, thousands-delimited).
  test "mmr_stat_display delimits an Integer count" do
    assert_equal "1,000", mmr_stat_display(1000)
  end

  test "mmr_stat_display renders a whole-valued BigDecimal without a decimal" do
    assert_equal "155", mmr_stat_display(BigDecimal("155"))
  end

  test "mmr_stat_display keeps a fractional BigDecimal mean" do
    assert_equal "22.143", mmr_stat_display(BigDecimal("22.143"))
  end

  # mmr_mode_display — the array-to-phrase render: empty / single / multimodal.
  test "mmr_mode_display reads 'No mode' for an empty array (all values unique)" do
    assert_equal "No mode", mmr_mode_display([])
  end

  test "mmr_mode_display reads the single value for a unimodal set" do
    assert_equal "4", mmr_mode_display([ BigDecimal("4") ])
  end

  test "mmr_mode_display joins a bimodal set with 'and'" do
    assert_equal "23 and 38", mmr_mode_display([ BigDecimal("23"), BigDecimal("38") ])
  end

  test "mmr_mode_display oxford-joins three or more modes" do
    assert_equal "2, 4 and 6", mmr_mode_display([ BigDecimal("2"), BigDecimal("4"), BigDecimal("6") ])
  end

  test "mmr_mode_display formats fractional modes via decimal_display" do
    assert_equal "2.5 and 7", mmr_mode_display([ BigDecimal("2.5"), BigDecimal("7.0") ])
  end

  # The stat-order constants the result grid renders from.
  test "mmr_primary_stats lists mean, median, range in order" do
    assert_equal %i[mean median range], mmr_primary_stats.map { |s| s[:key] }
  end

  test "mmr_supporting_stats lists sum, count, smallest, largest in order" do
    assert_equal %i[sum count smallest largest], mmr_supporting_stats.map { |s| s[:key] }
  end

  # field_labels_for / calculator_error_messages — the bespoke `numbers` label map.
  test "field_labels_for maps the numbers input to its visible label" do
    assert_equal "Numbers", field_labels_for(mmr({}))["numbers"]
  end

  test "a non-numeric token error is phrased against the Numbers label" do
    c = mmr(numbers: "1, 2, x")
    c.valid?
    messages = calculator_error_messages(c)
    assert_includes messages, "Numbers contains a value that is not a number: x"
  end

  test "a blank list error is phrased against the Numbers label" do
    c = mmr(numbers: "")
    c.valid?
    assert_includes calculator_error_messages(c), "Numbers can't be blank"
  end

  # ── Amortization helpers (issue #84) ────────────────────────────────────

  def amort(attrs)
    Calculators::Amortization.new(attrs)
  end

  # money_display — delimit thousands, keep the 2dp the envelope already rounded to.
  test "money_display delimits thousands and keeps two decimals" do
    assert_equal "215,838.45", money_display("215838.45")
  end

  test "money_display leaves a sub-thousand amount untouched" do
    assert_equal "599.55", money_display("599.55")
  end

  test "money_display keeps a zero amount as 0.00" do
    assert_equal "0.00", money_display("0.00")
  end

  # amortization_donut — two slices; the LARGER one is accent green (DESIGN.md §1).
  test "amortization_donut puts the larger slice (interest > principal) in accent green" do
    # 100000 @ 6%/30y: interest 115,838.45 > principal 100,000 → interest is green.
    chart = { principal: "100000.00", total_interest: "115838.45" }
    slices = amortization_donut(chart)
    assert_equal :principal, slices.first[:key]
    assert_equal "primary", slices.first[:color]      # smaller → coral
    assert_equal "accent",  slices.last[:color]        # larger → green
    assert_in_delta 46.33, slices.first[:pct], 0.01    # principal share
    assert_in_delta 100.0, slices.first[:pct] + slices.last[:pct], 0.0001
  end

  test "amortization_donut puts the larger slice (principal >= interest) in accent green" do
    # 10000 @ 4.5%/5y: principal 10,000 > interest 1,185.83 → principal is green.
    chart = { principal: "10000.00", total_interest: "1185.83" }
    slices = amortization_donut(chart)
    assert_equal "accent",  slices.first[:color]       # principal, larger → green
    assert_equal "primary", slices.last[:color]        # interest, smaller → coral
  end

  test "amortization_donut treats an equal split as principal-larger (>= boundary)" do
    chart = { principal: "100.00", total_interest: "100.00" }
    slices = amortization_donut(chart)
    assert_equal "accent", slices.first[:color] # principal, on the >= boundary, green
  end

  # amortization_donut_gradient — a conic-gradient from the two TOKEN colours (no hex).
  test "amortization_donut_gradient composes a conic-gradient from token custom properties" do
    chart = { principal: "100000.00", total_interest: "100000.00" } # 50/50
    g = amortization_donut_gradient(amortization_donut(chart))
    assert_match(/conic-gradient\(/, g)
    assert_includes g, "var(--color-accent)"
    assert_includes g, "var(--color-primary)"
    assert_includes g, "50.0%"
    refute_match(/#/, g) # never an inline hex (DESIGN.md §5 guardrail)
  end

  # amortization_donut_data — the flat object the JS chart controller reads. Carries each
  # slice's amount/label/colour; the colour decision is made upstream in amortization_donut.
  test "amortization_donut_data flattens the slices into the chart controller payload" do
    chart = { principal: "100000.00", total_interest: "115838.45" } # interest larger → green
    data = amortization_donut_data(amortization_donut(chart))
    assert_equal "100000.00", data[:principal]
    assert_equal "Principal", data[:principalLabel]
    assert_equal "primary", data[:principalColor]    # principal smaller → coral
    assert_equal "115838.45", data[:interest]
    assert_equal "Total interest", data[:interestLabel]
    assert_equal "accent", data[:interestColor]      # interest larger → green
  end

  # amortization_curve_points — map (month, balance) samples into a 0..100 unit box.
  test "amortization_curve_points maps the endpoints to the box corners" do
    curve = [
      { month: 0,   balance: "100000.00" },
      { month: 180, balance: "50000.00" },
      { month: 360, balance: "0.00" }
    ]
    pts = amortization_curve_points(curve).split(" ")
    # month 0, full balance → top-left (x=0, y=0); month 360, zero balance → bottom-right.
    assert_equal "0.0,0.0", pts.first
    assert_equal "100.0,100.0", pts.last
    # midpoint: half the months, half the balance → (50, 50).
    assert_equal "50.0,50.0", pts[1]
  end

  test "amortization_curve_points guards a degenerate all-zero curve without dividing by zero" do
    # A pathological single-point/zero curve (never produced in practice) must not raise.
    curve = [ { month: 0, balance: "0.00" } ]
    assert_equal "0.0,100.0", amortization_curve_points(curve)
  end

  # field_labels_for / calculator_error_messages — Amortization's bespoke label map.
  test "field_labels_for returns the Amortization label map for an Amortization instance" do
    labels = field_labels_for(amort({}))
    assert_equal "Loan amount", labels["principal"]
    assert_equal "Annual interest rate", labels["annual_rate"]
    assert_equal "Loan term", labels["years"]
  end

  test "Amortization errors are phrased against the visible labels, not the raw keys" do
    c = amort(principal: "", annual_rate: "", years: "")
    c.valid?
    messages = calculator_error_messages(c)
    assert_includes messages, "Loan amount can't be blank"
    assert_includes messages, "Annual interest rate can't be blank"
    assert_includes messages, "Loan term can't be blank"
  end

  # ── Age helpers (issue #82) ─────────────────────────────────────────────

  def age(attrs)
    Calculators::Age.new(attrs)
  end


  # integer_display — whole-integer counts with thousands delimiters.
  test "integer_display delimits a large whole count" do
    assert_equal "12,418", integer_display(12_418)
  end

  test "integer_display renders a plain zero" do
    assert_equal "0", integer_display(0)
  end

  # age_total_units — the four coarse-to-fine conversions, in order.
  test "age_total_units lists the four totals coarse-to-fine" do
    assert_equal %i[total_months total_weeks total_days total_hours], age_total_units.map { |u| u[:key] }
    assert_equal %w[Months Weeks Days Hours], age_total_units.map { |u| u[:label] }
  end

  # age_breakdown_phrase — drops zero units, pluralizes, never empty.
  test "age_breakdown_phrase joins the non-zero units" do
    phrase = age_breakdown_phrase(years: 33, months: 11, days: 30)
    assert_equal "33 years · 11 months · 30 days", phrase
  end

  test "age_breakdown_phrase drops zero-valued units" do
    # An exact-year anniversary (24y 0m 0d) reads as just the years.
    assert_equal "24 years", age_breakdown_phrase(years: 24, months: 0, days: 0)
  end

  test "age_breakdown_phrase singularizes a unit of one" do
    assert_equal "1 year · 1 month · 1 day", age_breakdown_phrase(years: 1, months: 1, days: 1)
  end

  test "age_breakdown_phrase falls back to '0 days' when every unit is zero" do
    # A same-day age — all zeros — still reads as a real span, never empty.
    assert_equal "0 days", age_breakdown_phrase(years: 0, months: 0, days: 0)
  end

  # field_labels_for / calculator_error_messages — Age's bespoke label map.
  test "field_labels_for returns the Age label map for an Age instance" do
    assert_equal "Date of birth", field_labels_for(age({}))["birth_date"]
    assert_equal "Age at the date of", field_labels_for(age({}))["end_date"]
  end

  test "Age errors are phrased against the visible labels, not the raw keys" do
    c = age(birth_date: "", end_date: "")
    c.valid?
    assert_includes calculator_error_messages(c), "Date of birth can't be blank"
  end

  test "an out-of-order Age error reads against the visible birth-date label" do
    c = age(birth_date: "2024-06-15", end_date: "2024-06-14")
    c.valid?
    assert_includes calculator_error_messages(c), "Date of birth must be on or before the end date"
  end

  # ── Simple Interest (issue #78) ─────────────────────────────────────────

  def simple_interest(attrs)
    Calculators::SimpleInterest.new(attrs)
  end

  # money_display — fixed 2dp, half-up, thousands-delimited (Simple Interest's outputs
  # are money, so they always read with cents).
  test "money_display renders an integer-valued amount with two decimals" do
    assert_equal "150.00", money_display(BigDecimal("150"))
  end

  test "money_display keeps two decimals and delimits thousands" do
    assert_equal "1,150.00", money_display(BigDecimal("1150.0"))
  end

  test "money_display rounds half-up to two decimals" do
    assert_equal "2.35", money_display(BigDecimal("2.345"))
  end

  test "money_display renders a plain zero with cents" do
    assert_equal "0.00", money_display(BigDecimal("0"))
  end

  test "field_labels_for returns the Simple Interest label map for a SimpleInterest instance" do
    labels = field_labels_for(simple_interest({}))
    assert_equal CalculatorsHelper::SIMPLE_INTEREST_FIELD_LABELS, labels
    assert_equal "Principal", labels["principal"]
    assert_equal "Annual rate", labels["rate"]
    assert_equal "Time", labels["time"]
    assert_equal "Time unit", labels["unit"]
  end

  test "Simple Interest errors are phrased against the visible labels, not the raw keys" do
    c = simple_interest(principal: "", rate: "", time: "", unit: "years")
    c.valid?
    messages = calculator_error_messages(c)
    assert_includes messages, "Principal can't be blank"
    assert_includes messages, "Annual rate can't be blank"
    assert_includes messages, "Time can't be blank"
  end

  # ── Tip helpers (issue #76) ─────────────────────────────────────────────

  def tip(attrs)
    Calculators::Tip.new(attrs)
  end

  # money_display — the calculator rounds money to the cent; the helper renders a fixed
  # two decimals + thousands delimiter so currency columns align (the numeric branch of
  # the shared money_display, which rounds half-up to 2dp).
  test "money_display renders a fixed two decimals" do
    assert_equal "57.50", money_display(BigDecimal("57.5"))
  end

  test "money_display keeps both cents digits and pads a whole amount" do
    assert_equal "120.00", money_display(BigDecimal("120"))
  end

  test "money_display delimits thousands for a numeric amount" do
    assert_equal "1,234.00", money_display(BigDecimal("1234"))
  end

  test "tip_percent_presets are the common restaurant rates" do
    assert_equal [ 15, 18, 20, 25 ], tip_percent_presets
  end

  test "field_labels_for returns the Tip label map for a Tip instance" do
    assert_equal "Bill amount", field_labels_for(tip({}))["bill"]
    assert_equal "Tip", field_labels_for(tip({}))["tip_percent"]
    assert_equal "People", field_labels_for(tip({}))["people"]
  end

  test "Tip errors are phrased against the visible labels, not the raw keys" do
    c = tip(bill: "", tip_percent: "", people: "1")
    c.valid?
    messages = calculator_error_messages(c)
    assert_includes messages, "Bill amount can't be blank"
    assert_includes messages, "Tip can't be blank"
    # Never the raw attribute key.
    assert_empty messages.grep(/\btip_percent\b/)
  end

  test "a sub-1 people count is phrased against its visible label" do
    c = tip(bill: "50", tip_percent: "15", people: "0")
    c.valid?
    assert_includes calculator_error_messages(c), "People must be greater than or equal to 1"
  end
end
