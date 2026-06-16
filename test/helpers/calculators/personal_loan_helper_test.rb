require "test_helper"

# Unit tests for Calculators::PersonalLoanHelper (issue #256) — the per-calculator chart-
# derivation helpers (the principal-vs-interest donut series + conic gradient + the flat data
# payload, the balance curve, and its SVG points). Ruby helpers are coverage-counted
# (ARCHITECTURE.md §11), so every branch is exercised here.
#
# The integration test (personal_loan_page_test) renders the result partial and so exercises
# the happy paths through these helpers; this unit test pins the exact output shapes AND the
# branch coverage a view render can't reach: the colour ordering when interest is the larger
# slice, the down-sampling step in the balance curve, and the defensive degenerate-curve
# guards (the single-point / all-zero branches that never arise in practice but are present so
# the helper can't divide by zero). It lives in its own file rather than in the shared
# calculators_helper_test (a single source the fan-out frontend builds must not collide on).
class Calculators::PersonalLoanHelperTest < ActionView::TestCase
  helper Calculators::PersonalLoanHelper

  # A small result with principal >> interest (the spec's 15000 @ 7% / 36 anchor shape).
  RESULT = {
    loan_amount: "15000.00",
    monthly_payment: "463.16",
    total_paid: "16673.61",
    total_interest: "1673.61",
    number_of_payments: 36,
    schedule: [
      { month: 1, payment: "463.16", interest: "87.50", principal: "375.66", balance: "14624.34" },
      { month: 2, payment: "463.16", interest: "85.31", principal: "377.85", balance: "14246.49" },
      { month: 3, payment: "463.16", interest: "83.10", principal: "380.06", balance: "0.00" }
    ]
  }.freeze

  # ── personal_loan_donut — two slices; the LARGER is accent green (DESIGN.md §1) ──

  test "donut puts the larger slice (principal >= interest) in accent green" do
    slices = personal_loan_donut(RESULT)
    principal, interest = slices
    assert_equal "Principal", principal[:label]
    assert_equal "accent", principal[:color]      # principal is larger → green
    assert_equal "Total interest", interest[:label]
    assert_equal "primary", interest[:color]      # interest smaller → coral
    # Shares sum to 100.
    assert_in_delta 100.0, principal[:pct] + interest[:pct], 0.0001
  end

  test "donut puts the larger slice (interest > principal) in accent green" do
    # An interest-heavy loan (a long, high-rate loan) flips the colours.
    result = RESULT.merge(loan_amount: "1000.00", total_interest: "5000.00")
    slices = personal_loan_donut(result)
    principal, interest = slices
    assert_equal "primary", principal[:color]     # principal smaller → coral
    assert_equal "accent", interest[:color]       # interest larger → green
  end

  test "donut treats an equal split as principal-larger (>= boundary)" do
    result = RESULT.merge(loan_amount: "1000.00", total_interest: "1000.00")
    slices = personal_loan_donut(result)
    assert_equal "accent", slices.first[:color]   # the >= boundary keeps principal green
  end

  # ── personal_loan_donut_gradient — conic stops from the two token colours ──

  test "donut gradient composes the two token colours with the principal stop" do
    g = personal_loan_donut_gradient(personal_loan_donut(RESULT))
    assert_match(/conic-gradient\(var\(--color-accent\) 0 [\d.]+%, var\(--color-primary\) [\d.]+% 100%\)/, g)
  end

  # ── personal_loan_donut_data — the flat object the JS chart controller reads ──

  test "donut_data flattens the slices into the chart controller payload" do
    data = personal_loan_donut_data(personal_loan_donut(RESULT))
    assert_equal "15000.00", data[:principal]
    assert_equal "Principal", data[:principalLabel]
    assert_equal "accent", data[:principalColor]
    assert_equal "1673.61", data[:interest]
    assert_equal "Total interest", data[:interestLabel]
    assert_equal "primary", data[:interestColor]
  end

  # ── personal_loan_balance_curve — month-0 principal + per-row balances ──

  test "balance curve starts at the loan amount (month 0) and ends at 0.00" do
    curve = personal_loan_balance_curve(RESULT)
    assert_equal 0, curve.first[:month]
    assert_equal "15000.00", curve.first[:balance]
    assert_equal "0.00", curve.last[:balance]
    # A short (3-row) schedule samples every row: month 0 + 3 rows = 4 points.
    assert_equal 4, curve.length
  end

  test "balance curve down-samples a long schedule but always keeps the final row" do
    # A 120-row schedule → step = ceil(120/60) = 2, so every other row is plotted; the final
    # row (balance 0.00) is always kept via the `i == last` branch even when it isn't on the
    # step boundary.
    schedule = (1..120).map do |m|
      { month: m, payment: "100.00", interest: "1.00", principal: "99.00", balance: m == 120 ? "0.00" : "#{12000 - m * 99}.00" }
    end
    result = RESULT.merge(loan_amount: "12000.00", schedule: schedule)
    curve = personal_loan_balance_curve(result)
    assert_equal 0, curve.first[:month]
    assert_equal "0.00", curve.last[:balance]
    assert_equal 120, curve.last[:month]
    # Down-sampled: far fewer than 121 points, but more than a handful.
    assert_operator curve.length, :<, 121
    assert_operator curve.length, :>, 10
  end

  # ── personal_loan_curve_points — map (month, balance) into a 0..100 unit box ──

  test "curve points map the endpoints to the box corners" do
    curve = personal_loan_balance_curve(RESULT)
    pts = personal_loan_curve_points(curve).split(" ")
    # First sample (month 0, full balance) → top-left (x 0, y 0).
    assert_equal "0.0,0.0", pts.first
    # Last sample (final month, balance 0) → bottom-right (x 100, y 100).
    assert_equal "100.0,100.0", pts.last
  end

  test "curve points guard a degenerate all-zero curve without dividing by zero" do
    curve = [ { month: 0, balance: "0.00" } ]
    assert_equal "0.0,100.0", personal_loan_curve_points(curve)
  end
end
