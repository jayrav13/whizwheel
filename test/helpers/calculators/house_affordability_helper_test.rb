require "test_helper"

# Unit tests for Calculators::HouseAffordabilityHelper (issue #259) — the per-calculator
# housing-budget donut helpers (the four-component series + conic gradient + the flat data
# payload). Ruby helpers are coverage-counted (ARCHITECTURE.md §11), so every branch is
# exercised here.
#
# The integration test (house_affordability_page_test) renders the result partial and so
# exercises the happy paths through these helpers; this unit test pins the exact output
# shapes AND the zero-component drop branch (an omitted tax/insurance/HOA), and feeds the
# helpers a real Calculators::HouseAffordability so the `money_2dp` input-formatting path is
# covered. It lives in its own file rather than in the shared calculators_helper_test (a
# single source the fan-out frontend builds must not collide on).
class Calculators::HouseAffordabilityHelperTest < ActionView::TestCase
  helper Calculators::HouseAffordabilityHelper

  # Spec row 1: income 120000, debts 500, down 60000, 6%/30y, 28/36 DTI, tax 250, ins 100,
  # hoa 0 → max_pi 2450.00, max_monthly_housing 2800.00.
  def build_calc(overrides = {})
    Calculators::HouseAffordability.new({
      annual_income: "120000", monthly_debts: "500", down_payment: "60000",
      annual_rate: "6", loan_term_years: "30", front_dti: "28", back_dti: "36",
      monthly_property_tax: "250", monthly_home_insurance: "100", monthly_hoa: "0"
    }.merge(overrides))
  end

  # ── house_affordability_budget_components ─────────────────────────────────

  test "budget components are P&I-first then the entered ownership costs, all money strings" do
    components = house_affordability_budget_components(build_calc)
    assert_equal [ "Principal & interest", "Property tax", "Home insurance", "HOA" ],
      components.map { |c| c[:label] }
    # P&I is the envelope's max_pi; tax/insurance/HOA are the entered inputs formatted to 2dp.
    assert_equal [ "2450.00", "250.00", "100.00", "0.00" ], components.map { |c| c[:amount] }
    # The four components sum to the binding monthly housing cap.
    total = components.sum { |c| BigDecimal(c[:amount]) }
    assert_equal BigDecimal("2800.00"), total
  end

  # ── house_affordability_donut ─────────────────────────────────────────────

  test "donut paints the present components in token order, P&I leading green" do
    slices = house_affordability_donut(build_calc)
    # HOA is 0.00 in row 1 → dropped; three slices remain in token order.
    assert_equal [ "Principal & interest", "Property tax", "Home insurance" ], slices.map { |s| s[:label] }
    assert_equal %w[accent primary amber], slices.map { |s| s[:color] }
  end

  test "donut shares add up to ~100 percent" do
    slices = house_affordability_donut(build_calc)
    assert_in_delta 100.0, slices.sum { |s| s[:pct] }, 0.0001
  end

  test "donut drops every zero-amount ownership cost" do
    # tax/insurance/HOA all omitted (default 0) → only the P&I slice draws, leading accent at 100%.
    slices = house_affordability_donut(build_calc(
      monthly_property_tax: "0", monthly_home_insurance: "0", monthly_hoa: "0"
    ))
    assert_equal 1, slices.length
    assert_equal "Principal & interest", slices.first[:label]
    assert_equal "accent", slices.first[:color]
    assert_in_delta 100.0, slices.first[:pct], 0.0001
  end

  test "donut paints all four components when every ownership cost is present" do
    slices = house_affordability_donut(build_calc(monthly_hoa: "75"))
    assert_equal %w[accent primary amber faint], slices.map { |s| s[:color] }
    assert_equal "75.00", slices.last[:amount]
  end

  # ── house_affordability_donut_gradient ────────────────────────────────────

  test "donut gradient composes a conic-gradient from token custom properties" do
    g = house_affordability_donut_gradient(house_affordability_donut(build_calc))
    assert_match(/\Aconic-gradient\(/, g)
    # No raw hex — only token CSS custom properties (DESIGN.md §5 guardrail).
    assert_no_match(/#[0-9a-fA-F]{3,6}/, g)
    assert_includes g, "var(--color-accent)"
    assert_includes g, "var(--color-primary)"
    assert_includes g, "var(--color-amber)"
    # The first slice starts at 0%.
    assert_includes g, "var(--color-accent) 0.0%"
  end

  # ── house_affordability_donut_data ────────────────────────────────────────

  test "donut data flattens the slices into the chart controller payload" do
    data = house_affordability_donut_data(house_affordability_donut(build_calc))
    assert_equal 3, data.length
    assert_equal({ amount: "2450.00", label: "Principal & interest", color: "accent" }, data.first)
    assert_equal({ amount: "100.00", label: "Home insurance", color: "amber" }, data.last)
  end
end
