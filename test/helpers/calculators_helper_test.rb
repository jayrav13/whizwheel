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
end
