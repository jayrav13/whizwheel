require "test_helper"

# Unit tests for Calculators::MortgageHelper (issue #187) — the per-calculator chart-
# derivation helpers (the payment-component donut series + conic gradient + the flat data
# payload, and the balance-curve SVG points). Ruby helpers are coverage-counted
# (ARCHITECTURE.md §11), so every branch is exercised here.
#
# The integration test (mortgage_page_test) renders the result partial and so exercises the
# happy paths through these helpers; this unit test pins the exact output shapes AND the
# defensive degenerate-curve guards (the single-point / all-zero branches never produced in
# practice but present so the helper can't divide by zero), which a view render can't reach.
# It lives in its own file rather than in the shared calculators_helper_test (a single source
# the fan-out frontend builds must not collide on).
class Calculators::MortgageHelperTest < ActionView::TestCase
  helper Calculators::MortgageHelper

  # The spec's row-1 chart payload (four payment components + a balance curve).
  CHART = {
    payment_components: [
      { label: "Principal & interest", amount: "1995.91" },
      { label: "Property tax",         amount: "291.67" },
      { label: "Home insurance",       amount: "100.00" },
      { label: "HOA",                  amount: "50.00" }
    ],
    balance_curve: [
      { month: 0,   balance: "300000.00" },
      { month: 180, balance: "234000.00" },
      { month: 360, balance: "0.00" }
    ]
  }.freeze

  # ── mortgage_donut ────────────────────────────────────────────────────────

  test "mortgage_donut paints the four components in the token order, P&I leading green" do
    slices = mortgage_donut(CHART)
    assert_equal [ "Principal & interest", "Property tax", "Home insurance", "HOA" ], slices.map { |s| s[:label] }
    assert_equal %w[accent primary amber faint], slices.map { |s| s[:color] }
  end

  test "mortgage_donut shares add up to ~100 percent" do
    slices = mortgage_donut(CHART)
    assert_in_delta 100.0, slices.sum { |s| s[:pct] }, 0.0001
  end

  test "mortgage_donut drops zero-amount components" do
    # tax/insurance/HOA omitted (all 0.00) → only the P&I slice draws, and it's the leading
    # accent-green slice at 100%.
    chart = {
      payment_components: [
        { label: "Principal & interest", amount: "1687.71" },
        { label: "Property tax",         amount: "0.00" },
        { label: "Home insurance",       amount: "0.00" },
        { label: "HOA",                  amount: "0.00" }
      ],
      balance_curve: []
    }
    slices = mortgage_donut(chart)
    assert_equal 1, slices.length
    assert_equal "Principal & interest", slices.first[:label]
    assert_equal "accent", slices.first[:color]
    assert_in_delta 100.0, slices.first[:pct], 0.0001
  end

  # ── mortgage_donut_gradient ──────────────────────────────────────────────

  test "mortgage_donut_gradient composes a conic-gradient from token custom properties" do
    g = mortgage_donut_gradient(mortgage_donut(CHART))
    assert_match(/\Aconic-gradient\(/, g)
    # No raw hex — only token CSS custom properties (DESIGN.md §5 guardrail).
    assert_no_match(/#[0-9a-fA-F]{3,6}/, g)
    assert_includes g, "var(--color-accent)"
    assert_includes g, "var(--color-primary)"
    assert_includes g, "var(--color-amber)"
    assert_includes g, "var(--color-faint)"
    # The first slice starts at 0%.
    assert_includes g, "var(--color-accent) 0.0%"
  end

  # ── mortgage_donut_data ──────────────────────────────────────────────────

  test "mortgage_donut_data flattens the slices into the chart controller payload" do
    data = mortgage_donut_data(mortgage_donut(CHART))
    assert_equal 4, data.length
    assert_equal({ amount: "1995.91", label: "Principal & interest", color: "accent" }, data.first)
    assert_equal({ amount: "50.00", label: "HOA", color: "faint" }, data.last)
  end

  # ── mortgage_curve_points ────────────────────────────────────────────────

  test "mortgage_curve_points maps the endpoints to the box corners" do
    pts = mortgage_curve_points(CHART[:balance_curve]).split(" ")
    # Month 0, full balance → bottom-left mapped to top-left of the inverted box: x=0, y=0.
    assert_equal "0.0,0.0", pts.first
    # Final month, zero balance → x=100, y=100 (fallen to the floor).
    assert_equal "100.0,100.0", pts.last
  end

  test "mortgage_curve_points guards a degenerate all-zero curve without dividing by zero" do
    # A pathological single-point/zero curve (never produced in practice) must not raise — the
    # max_month / max_balance .zero? guards swap in 1.0 so the division is safe.
    curve = [ { month: 0, balance: "0.00" } ]
    assert_equal "0.0,100.0", mortgage_curve_points(curve)
  end
end
