require "test_helper"

# Unit tests for Calculators::IncomeTaxHelper (issue #260) — the per-calculator helper for
# the Income Tax calculator. Ruby helpers are coverage-counted (ARCHITECTURE.md §11), so
# every method and branch here is exercised. The shared calculators_helper_test.rb is a
# derived file we never edit, so each per-calculator helper carries its own test alongside it
# (the #107 no-shared-edit convention). ActionView::TestCase includes the module under test so
# its methods are callable in the view context, exactly as a template sees them.
class Calculators::IncomeTaxHelperTest < ActionView::TestCase
  include Calculators::IncomeTaxHelper

  # ── FIELD_LABELS ─────────────────────────────────────────────────────────

  test "FIELD_LABELS maps every input key to its visible label" do
    assert_equal "Taxable income", Calculators::IncomeTaxHelper::FIELD_LABELS["taxable_income"]
    assert_equal "Gross income", Calculators::IncomeTaxHelper::FIELD_LABELS["gross_income"]
    assert_equal "Deductions", Calculators::IncomeTaxHelper::FIELD_LABELS["deductions"]
  end

  # ── income_tax_modes ──────────────────────────────────────────────────────

  test "income_tax_modes lists the two modes in spec order with helper copy" do
    assert_equal %w[taxable gross], income_tax_modes.map { |m| m[:value] }
    assert income_tax_modes.all? { |m| m[:label].present? && m[:helper].present? }
  end

  # ── income_tax_brackets ───────────────────────────────────────────────────

  test "income_tax_brackets returns the solved calculator's bracket rows" do
    calc = Calculators::IncomeTax.new(taxable_income: "50000")
    rows = income_tax_brackets(calc)
    # 50,000 reaches brackets 1–3 (three rows). The raw `compute` rows carry symbol keys.
    assert_equal 3, rows.length
    assert_equal "10", rows.first[:rate]
  end

  # ── income_tax_bracket_range ──────────────────────────────────────────────

  test "income_tax_bracket_range formats a bounded bracket as a whole-dollar range" do
    row = { "lower" => "48475.00", "upper" => "103350.00" }
    assert_equal "$48,475 – $103,350", income_tax_bracket_range(row)
  end

  test "income_tax_bracket_range formats the unbounded top bracket as 'and up'" do
    # The top bracket's `upper` is nil → the range reads "$626,350 and up".
    row = { "lower" => "626350.00", "upper" => nil }
    assert_equal "$626,350 and up", income_tax_bracket_range(row)
  end

  test "income_tax_bracket_range drops the cents and delimits thousands" do
    row = { "lower" => "0.00", "upper" => "11925.00" }
    assert_equal "$0 – $11,925", income_tax_bracket_range(row)
  end
end
