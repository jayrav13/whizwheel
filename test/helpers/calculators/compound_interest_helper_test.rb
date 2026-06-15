require "test_helper"

# Unit tests for the per-calculator Compound Interest helper (issue #189) — the chart-
# derivation helpers (growth-curve points + curve data, principal-vs-interest donut series +
# gradient + chart payload) and the small display helpers (mode list + label). Ruby helpers
# are coverage-counted (ARCHITECTURE.md §11), so every branch here is exercised. The FE does
# no math beyond mapping the backend's computed money strings into display proportions
# (ARCHITECTURE.md §4); these assert that mapping, not calculator correctness.
class Calculators::CompoundInterestHelperTest < ActionView::TestCase
  include Calculators::CompoundInterestHelper

  # ── FIELD_LABELS + the mode list ─────────────────────────────────────────

  test "FIELD_LABELS maps every input to its visible label" do
    labels = Calculators::CompoundInterestHelper::FIELD_LABELS
    assert_equal "Principal", labels["principal"]
    assert_equal "Annual interest rate", labels["annual_rate"]
    assert_equal "Time", labels["years"]
    assert_equal "Compounding frequency", labels["compounding"]
  end

  test "compound_interest_modes exposes all five compounding options in order" do
    values = compound_interest_modes.map(&:first)
    assert_equal %w[annually semiannually quarterly monthly daily], values
    # Each row is [value, label, helper] — all present.
    compound_interest_modes.each { |row| assert_equal 3, row.length }
  end

  # ── compounding_label ────────────────────────────────────────────────────

  test "compounding_label returns the visible label for a known mode" do
    assert_equal "Monthly", compounding_label("monthly")
    assert_equal "Annually", compounding_label("annually")
  end

  test "compounding_label humanizes an unmapped value (defensive fallback)" do
    # Never reached in practice (the value is validated into the mode keys), but the branch
    # must be covered — an unmapped value humanizes rather than erroring.
    assert_equal "Weekly", compounding_label("weekly")
  end

  # ── compound_interest_curve_data ─────────────────────────────────────────

  test "compound_interest_curve_data forwards each backend sample as plotting strings" do
    series = [ { year: 0, balance: "1000.00" }, { year: 1, balance: "1050.00" } ]
    data = compound_interest_curve_data(series)
    assert_equal [ { year: "0", balance: "1000.00" }, { year: "1", balance: "1050.00" } ], data
  end

  test "compound_interest_curve_data stringifies a fractional final-year label" do
    series = [ { year: 0, balance: "1000.00" }, { year: 2.5, balance: "1100.00" } ]
    assert_equal "2.5", compound_interest_curve_data(series).last[:year]
  end

  # ── compound_interest_curve_points ───────────────────────────────────────

  test "compound_interest_curve_points maps samples into the unit viewBox (rising curve)" do
    series = [ { year: 0, balance: "1000.00" }, { year: 1, balance: "2000.00" } ]
    points = compound_interest_curve_points(series)
    # Year 0 → x=0, balance half the peak → y=50; final year → x=100, peak → y=0 (top).
    assert_equal "0.0,50.0 100.0,0.0", points
  end

  test "compound_interest_curve_points guards a zero final year (single-point safety)" do
    # Defensive zero-guard branch (years validates > 0, so unreachable in practice): a single
    # year-0 point must not divide by zero.
    points = compound_interest_curve_points([ { year: 0, balance: "1000.00" } ])
    assert_equal "0.0,0.0", points
  end

  test "compound_interest_curve_points guards a zero final balance" do
    # Defensive zero-balance guard: with every balance zero, y maps to the baseline (100),
    # not a divide-by-zero.
    points = compound_interest_curve_points([ { year: 0, balance: "0.00" }, { year: 1, balance: "0.00" } ])
    assert_equal "0.0,100.0 100.0,100.0", points
  end

  # ── compound_interest_donut (the colour decision) ────────────────────────

  test "compound_interest_donut paints the larger slice (principal) accent green" do
    slices = compound_interest_donut("10000.00", "2000.00")
    principal, interest = slices
    assert_equal "accent", principal[:color]   # principal is larger → green
    assert_equal "primary", interest[:color]   # interest smaller → coral
    assert_in_delta 83.33, principal[:pct], 0.1
  end

  test "compound_interest_donut paints the larger slice accent green when interest dominates" do
    # The other branch of the ternary: a long term where interest exceeds the principal.
    slices = compound_interest_donut("1000.00", "5000.00")
    principal, interest = slices
    assert_equal "primary", principal[:color]  # principal smaller → coral
    assert_equal "accent", interest[:color]    # interest larger → green
  end

  test "compound_interest_donut treats an equal split as principal-larger (>= boundary)" do
    slices = compound_interest_donut("1000.00", "1000.00")
    assert_equal "accent", slices.first[:color] # principal_bigger is >= → green
    assert_equal "primary", slices.last[:color]
  end

  # ── compound_interest_donut_gradient + _data ─────────────────────────────

  test "compound_interest_donut_gradient composes a conic-gradient from token custom properties" do
    g = compound_interest_donut_gradient(compound_interest_donut("3000.00", "1000.00"))
    # No inline hex (DESIGN.md §5 guardrail) — colours come from the @theme CSS custom props.
    assert_includes g, "conic-gradient("
    assert_includes g, "var(--color-accent)"
    assert_includes g, "var(--color-primary)"
    assert_not_includes g, "#"
  end

  test "compound_interest_donut_data flattens the slices into the chart controller payload" do
    data = compound_interest_donut_data(compound_interest_donut("3000.00", "1000.00"))
    assert_equal "3000.00", data[:principal]
    assert_equal "Principal", data[:principalLabel]
    assert_equal "accent", data[:principalColor]
    assert_equal "1000.00", data[:interest]
    assert_equal "Total interest", data[:interestLabel]
    assert_equal "primary", data[:interestColor]
  end
end
