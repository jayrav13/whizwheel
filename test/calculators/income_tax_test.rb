require "test_helper"

# Reference-value + validation tests for Calculators::IncomeTax (spec issue #250).
# The reference tables below are lifted VERBATIM from the spec's "Reference values"
# section — they pin correctness against the pinned 2025 US federal single-filer
# bracket schedule and must reproduce exactly (ARCHITECTURE.md §11). This is the
# iteration's new primitive (progressive bracket / piecewise math), so the breakdown-
# shape invariants are asserted alongside the headline figures.
class Calculators::IncomeTaxTest < ActiveSupport::TestCase
  # --- Reference values (direct taxable_income entry) ---
  # | taxable_income | total_tax | after_tax_income | effective_rate | marginal_rate |
  [
    [ "10000.00",  "1000.00",   "9000.00",   "10.0000", "10", 1 ],
    [ "50000.00",  "5914.00",   "44086.00",  "11.8280", "22", 3 ],
    [ "100000.00", "16914.00",  "83086.00",  "16.9140", "22", 3 ],
    [ "250000.00", "57063.00",  "192937.00", "22.8252", "32", 5 ],
    [ "700000.00", "216020.25", "483979.75", "30.8600", "37", 7 ],
    [ "0.00",      "0.00",      "0.00",      "0.0000",  "0",  0 ]
  ].each do |taxable, total_tax, after_tax, effective, marginal, n_brackets|
    test "taxable #{taxable} -> total_tax #{total_tax}, effective #{effective}, marginal #{marginal}" do
      calc = Calculators::IncomeTax.new(taxable_income: taxable)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result

      assert_equal money(taxable), result[:taxable_income]
      assert_equal total_tax, result[:total_tax]
      assert_equal after_tax, result[:after_tax_income]
      assert_equal effective, result[:effective_rate]
      assert_equal marginal, result[:marginal_rate]
      assert_equal n_brackets, result[:brackets].length
    end
  end

  # --- Breakdown-shape invariants (spec: "Breakdown-shape assertions, must also test") ---

  test "Σ brackets[*].tax equals total_tax for every reach" do
    %w[10000 50000 100000 250000 700000].each do |income|
      result = Calculators::IncomeTax.new(taxable_income: income).result
      sum = result[:brackets].sum { |b| BigDecimal(b[:tax]) }
      assert_equal BigDecimal(result[:total_tax]), sum, "tax sum mismatch at #{income}"
    end
  end

  test "Σ brackets[*].taxable_in_bracket equals taxable_income for every reach" do
    %w[10000 50000 100000 250000 700000].each do |income|
      result = Calculators::IncomeTax.new(taxable_income: income).result
      sum = result[:brackets].sum { |b| BigDecimal(b[:taxable_in_bracket]) }
      assert_equal BigDecimal(result[:taxable_income]), sum, "taxable sum mismatch at #{income}"
    end
  end

  # The full worked anchor from the spec — every per-bracket row for taxable 250000.
  test "the per-bracket breakdown for taxable 250000 matches the spec anchor exactly" do
    result = Calculators::IncomeTax.new(taxable_income: "250000").result
    expected = [
      { rate: "10", lower: "0.00",       upper: "11925.00",  taxable_in_bracket: "11925.00", tax: "1192.50" },
      { rate: "12", lower: "11925.00",   upper: "48475.00",  taxable_in_bracket: "36550.00", tax: "4386.00" },
      { rate: "22", lower: "48475.00",   upper: "103350.00", taxable_in_bracket: "54875.00", tax: "12072.50" },
      { rate: "24", lower: "103350.00",  upper: "197300.00", taxable_in_bracket: "93950.00", tax: "22548.00" },
      { rate: "32", lower: "197300.00",  upper: "250525.00", taxable_in_bracket: "52700.00", tax: "16864.00" }
    ]
    assert_equal expected, result[:brackets]
  end

  test "the top bracket row carries a null upper (unbounded)" do
    result = Calculators::IncomeTax.new(taxable_income: "700000").result
    top = result[:brackets].last
    assert_equal "37", top[:rate]
    assert_nil top[:upper]
    assert_equal "626350.00", top[:lower]
  end

  test "taxable_income 0 yields an empty brackets array" do
    result = Calculators::IncomeTax.new(taxable_income: "0").result
    assert_equal [], result[:brackets]
  end

  # --- Marginal rate at an exact bracket edge (spec validation table) ---

  test "taxable_income at an exact edge (11925) fills bracket 1 and stays at the lower marginal rate" do
    result = Calculators::IncomeTax.new(taxable_income: "11925").result
    assert_equal "1192.50", result[:total_tax]
    assert_equal "10", result[:marginal_rate]
    assert_equal 1, result[:brackets].length
    assert_equal "11925.00", result[:brackets].first[:taxable_in_bracket]
  end

  # --- gross_income / deductions derivation ---

  test "gross_income minus deductions derives taxable_income (60000 - 14600 = 45400)" do
    calc = Calculators::IncomeTax.new(gross_income: "60000", deductions: "14600")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    result = calc.result
    assert_equal "45400.00", result[:taxable_income]
    assert_equal "5209.50", result[:total_tax]
  end

  test "deductions exceeding gross_income floors taxable_income at 0 (10000 - 15000 -> 0)" do
    calc = Calculators::IncomeTax.new(gross_income: "10000", deductions: "15000")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    result = calc.result
    assert_equal "0.00", result[:taxable_income]
    assert_equal "0.00", result[:total_tax]
    assert_equal [], result[:brackets]
  end

  test "gross_income with omitted deductions uses the default of 0" do
    calc = Calculators::IncomeTax.new(gross_income: "50000")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "50000.00", calc.result[:taxable_income]
    assert_equal "5914.00", calc.result[:total_tax]
  end

  test "gross_income with a blank deductions field uses the default of 0 (#213)" do
    calc = Calculators::IncomeTax.new(gross_income: "50000", deductions: "")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "5914.00", calc.result[:total_tax]
  end

  test "a directly-entered taxable_income wins over gross_income/deductions" do
    calc = Calculators::IncomeTax.new(taxable_income: "100000", gross_income: "999999", deductions: "1")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "100000.00", calc.result[:taxable_income]
    assert_equal "16914.00", calc.result[:total_tax]
  end

  # --- Validation cases (from the spec's edge/validation table) ---

  test "neither taxable_income nor gross_income is invalid (one is required)" do
    calc = Calculators::IncomeTax.new(deductions: "5000")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :taxable_income
    assert_nil calc.result
  end

  test "a negative taxable_income is invalid (greater than or equal to 0)" do
    calc = Calculators::IncomeTax.new(taxable_income: "-100")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :taxable_income
  end

  test "a negative gross_income is invalid (greater than or equal to 0)" do
    calc = Calculators::IncomeTax.new(gross_income: "-100")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :gross_income
  end

  test "a negative deductions is invalid (greater than or equal to 0)" do
    calc = Calculators::IncomeTax.new(gross_income: "50000", deductions: "-1")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :deductions
  end

  test "a non-numeric taxable_income is rejected by the Base numeric guard" do
    calc = Calculators::IncomeTax.new(taxable_income: "x")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :taxable_income
    assert_includes calc.errors[:taxable_income], "is not a number"
  end

  test "a non-numeric gross_income is rejected by the Base numeric guard" do
    calc = Calculators::IncomeTax.new(gross_income: "abc")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :gross_income
    assert_includes calc.errors[:gross_income], "is not a number"
  end

  # --- Rounding / display ---

  test "money outputs are two-decimal strings, rates are four-decimal strings" do
    result = Calculators::IncomeTax.new(taxable_income: "50000").result
    assert_match(/\A\d+\.\d{2}\z/, result[:taxable_income])
    assert_match(/\A\d+\.\d{2}\z/, result[:total_tax])
    assert_match(/\A\d+\.\d{2}\z/, result[:after_tax_income])
    assert_match(/\A\d+\.\d{4}\z/, result[:effective_rate])
    result[:brackets].each do |row|
      assert_match(/\A\d+\.\d{2}\z/, row[:tax])
      assert_match(/\A\d+\.\d{2}\z/, row[:taxable_in_bracket])
      assert_match(/\A\d+\.\d{2}\z/, row[:lower])
    end
  end

  # --- Slug + envelope shape ---

  test "slug is income_tax" do
    assert_equal "income_tax", Calculators::IncomeTax.slug
  end

  test "result keys match the spec's output contract" do
    calc = Calculators::IncomeTax.new(taxable_income: "50000")
    assert calc.valid?
    assert_equal %i[taxable_income total_tax after_tax_income effective_rate marginal_rate brackets],
      calc.result.keys
  end

  # Helper mirroring the calculator's money formatting, for the reference table's
  # taxable_income echo (the table lists e.g. "10000.00").
  def money(string)
    whole, frac = BigDecimal(string).round(2, BigDecimal::ROUND_HALF_UP).to_s("F").split(".")
    "#{whole}.#{(frac.to_s + '00')[0, 2]}"
  end
end
