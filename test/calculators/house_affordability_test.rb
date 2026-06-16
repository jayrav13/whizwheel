require "test_helper"

# Reference-value + validation tests for Calculators::HouseAffordability (spec issue
# #249). The reference table is lifted verbatim from the spec's "Reference values"
# section — it pins correctness and must reproduce exactly (ARCHITECTURE.md §11). The
# calculator runs the mortgage amortization identity in reverse (income + DTI → a
# payment ceiling → loan principal → home price), so the suite also asserts the binding
# DTI cap, the P&I-room guard, and the back-end-binds branch.
class Calculators::HouseAffordabilityTest < ActiveSupport::TestCase
  # [ annual_income, monthly_debts, down_payment, annual_rate, loan_term_years,
  #   front_dti, back_dti, monthly_property_tax, monthly_home_insurance, monthly_hoa,
  #   gross_monthly_income, max_monthly_housing, max_pi, max_loan_amount, max_home_price ]
  REFERENCE = [
    [ 120000, 500, 60000, 6, 30, 28, 36, 250, 100, 0,
      "10000.00", "2800.00", "2450.00", "408639.46", "468639.46" ],
    [ 90000, 300, 40000, 7, 30, 28, 36, 200, 80, 0,
      "7500.00", "2100.00", "1820.00", "273559.77", "313559.77" ]
  ].freeze

  REFERENCE.each do |income, debts, down, rate, term, fdti, bdti, tax, ins, hoa,
                     gmi, housing, pi, loan, price|
    test "income #{income} / #{fdti}/#{bdti} DTI @ #{rate}% #{term}y -> price #{price}" do
      calc = build(
        annual_income: income, monthly_debts: debts, down_payment: down,
        annual_rate: rate, loan_term_years: term, front_dti: fdti, back_dti: bdti,
        monthly_property_tax: tax, monthly_home_insurance: ins, monthly_hoa: hoa
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result

      assert_equal gmi,     result[:gross_monthly_income], "gross_monthly_income"
      assert_equal housing, result[:max_monthly_housing], "max_monthly_housing"
      assert_equal pi,      result[:max_pi], "max_pi"
      assert_equal loan,    result[:max_loan_amount], "max_loan_amount"
      assert_equal price,   result[:max_home_price], "max_home_price"

      # max_home_price == max_loan_amount + down_payment
      assert_equal BigDecimal(loan) + BigDecimal(down), BigDecimal(price),
        "max_home_price == max_loan_amount + down_payment"
      # max_pi == max_monthly_housing − tax − ins − hoa
      assert_equal BigDecimal(housing) - BigDecimal(tax) - BigDecimal(ins) - BigDecimal(hoa),
        BigDecimal(pi), "max_pi == housing − tax − ins − hoa"
    end
  end

  # --- output contract: the exact set of result keys (the §4 result shape) ---
  test "result carries exactly the spec's output keys" do
    expected = %i[gross_monthly_income max_monthly_housing max_pi max_loan_amount max_home_price]
    assert_equal expected.sort, build.result.keys.sort
  end

  test "all output figures are formatted to exactly two decimal places" do
    result = build.result
    result.each_value { |v| assert_match(/\A\d+\.\d{2}\z/, v, v.inspect) }
  end

  # --- the binding DTI cap ---
  test "the front-end ratio binds when it is the smaller cap (reference row 1)" do
    # front = 10000 × 28% = 2800; back = 10000 × 36% − 500 = 3100; min is front.
    assert_equal "2800.00", build.result[:max_monthly_housing]
  end

  test "the back-end ratio binds when debts make it the smaller cap" do
    # front = 10000 × 28% = 2800; back = 10000 × 36% − 1500 = 2100; min is back.
    calc = build(monthly_debts: 1500)
    assert_equal "2100.00", calc.result[:max_monthly_housing]
  end

  # --- the r = 0 (no-interest) edge of the inversion ---
  test "a zero rate inverts to the straight max_pi times the number of payments" do
    calc = build(annual_rate: 0)
    # max_pi = 2450; n = 360 -> loan = 2450 × 360 = 882000.00
    assert_equal "882000.00", calc.result[:max_loan_amount]
    assert_equal "942000.00", calc.result[:max_home_price] # + 60000 down
  end

  # --- defaults: omitted optional numerics behave like 0 ---
  test "optional cost inputs default to zero when omitted" do
    calc = Calculators::HouseAffordability.new(
      annual_income: 120000, annual_rate: 6, loan_term_years: 30, front_dti: 28, back_dti: 36
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    # no debts/tax/ins/hoa, no down: max_pi = 2800, loan over 6%/30y, price == loan
    assert_equal "2800.00", calc.result[:max_pi]
    assert_equal calc.result[:max_loan_amount], calc.result[:max_home_price]
  end

  test "a blank optional cost field behaves like the default (#213)" do
    calc = build(monthly_debts: "", monthly_property_tax: "  ", down_payment: "")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    # blanks become 0: housing 2800, only insurance 100 backed out -> pi 2700
    assert_equal "2700.00", calc.result[:max_pi]
  end

  # --- validation cases (spec's edge table) ---
  test "annual_income must be greater than zero" do
    calc = build(annual_income: 0)
    assert_not calc.valid?
    assert calc.errors[:annual_income].present?
  end

  test "annual_income is required" do
    calc = build(annual_income: "")
    assert_not calc.valid?
    assert calc.errors[:annual_income].present?
  end

  test "loan_term_years must be greater than zero" do
    calc = build(loan_term_years: 0)
    assert_not calc.valid?
    assert calc.errors[:loan_term_years].present?
  end

  test "a fractional loan_term_years is rejected by the Base numeric guard" do
    calc = build(loan_term_years: "29.5")
    assert_not calc.valid?
    assert calc.errors[:loan_term_years].present?
  end

  test "front_dti must be greater than zero" do
    calc = build(front_dti: 0)
    assert_not calc.valid?
    assert calc.errors[:front_dti].present?
  end

  test "back_dti must be at most 100" do
    calc = build(back_dti: 150)
    assert_not calc.valid?
    assert calc.errors[:back_dti].present?
  end

  test "front_dti must be at most 100" do
    calc = build(front_dti: 150)
    assert_not calc.valid?
    assert calc.errors[:front_dti].present?
  end

  test "annual_rate is required and numeric" do
    calc = build(annual_rate: "x")
    assert_not calc.valid?
    assert calc.errors[:annual_rate].present?
  end

  test "a negative monthly_debts is rejected" do
    calc = build(monthly_debts: -100)
    assert_not calc.valid?
    assert calc.errors[:monthly_debts].present?
  end

  test "a negative down_payment is rejected" do
    calc = build(down_payment: -1)
    assert_not calc.valid?
    assert calc.errors[:down_payment].present?
  end

  test "a negative cost field is rejected" do
    assert_not build(monthly_property_tax: -1).valid?
    assert_not build(monthly_home_insurance: -1).valid?
    assert_not build(monthly_hoa: -1).valid?
  end

  # --- the affordability guard (no P&I room) ---
  test "constraints that exhaust the DTI ceiling leave no affordable home" do
    # income 30000 -> gmi 2500; front = 2500 × 28% = 700; back = 2500 × 36% − 2000 = −1100;
    # housing = −1100; minus tax 800 + ins 200 -> max_pi deeply negative -> invalid.
    calc = build(
      annual_income: 30000, monthly_debts: 2000, front_dti: 28, back_dti: 36,
      monthly_property_tax: 800, monthly_home_insurance: 200, monthly_hoa: 0
    )
    assert_not calc.valid?
    assert calc.errors[:base].present?, "expected a base-level affordability error"
    assert_nil calc.result
  end

  test "max_pi of exactly zero is not affordable (must be strictly positive)" do
    # gmi 10000; front cap 2800; tax+ins+hoa = 2800 -> max_pi == 0 -> invalid.
    calc = build(monthly_property_tax: 2800, monthly_home_insurance: 0, monthly_hoa: 0)
    assert_not calc.valid?
    assert calc.errors[:base].present?
  end

  test "the affordability guard is skipped while a dependent field is blank" do
    # annual_income blank -> presence error owns it; no base affordability error noise.
    calc = build(annual_income: "")
    assert_not calc.valid?
    assert calc.errors[:base].blank?
  end

  # Build a valid calculator (reference row 1's inputs), overriding any keys passed.
  def build(**overrides)
    defaults = {
      annual_income: 120000, monthly_debts: 500, down_payment: 60000,
      annual_rate: 6, loan_term_years: 30, front_dti: 28, back_dti: 36,
      monthly_property_tax: 250, monthly_home_insurance: 100, monthly_hoa: 0
    }
    Calculators::HouseAffordability.new(**defaults.merge(overrides))
  end
end
