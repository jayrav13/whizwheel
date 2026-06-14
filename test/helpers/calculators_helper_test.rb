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
end
