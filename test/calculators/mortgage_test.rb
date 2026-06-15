require "test_helper"

# Reference-value + validation tests for Calculators::Mortgage (spec issue #186).
# The reference table is lifted verbatim from the spec's "Reference values" section —
# it pins correctness and must reproduce exactly (ARCHITECTURE.md §11). Mortgage is the
# loan cluster's charts-bearing member, so the suite also asserts the P&I schedule
# shape (length, first/last rows, reconciliation to the totals) and the chart series
# (payment-component donut + balance curve).
class Calculators::MortgageTest < ActiveSupport::TestCase
  # [ home_price, down_payment, annual_rate, loan_term_years,
  #   annual_property_tax, annual_home_insurance, monthly_hoa,
  #   loan_amount, pi_monthly, tax_monthly, insurance_monthly, hoa_monthly,
  #   total_monthly, total_interest, total_of_pi ]
  REFERENCE = [
    [ 360000, 60000, 7, 30, 3500, 1200, 50,
      "300000.00", "1995.91", "291.67", "100.00", "50.00",
      "2437.58", "418524.05", "718524.05" ],
    [ 250000, 50000, 6, 15, 0, 0, 0,
      "200000.00", "1687.71", "0.00", "0.00", "0.00",
      "1687.71", "103788.82", "303788.82" ]
  ].freeze

  REFERENCE.each do |hp, dp, rate, term, tax, ins, hoa, loan_amt, pi, tax_m, ins_m, hoa_m, total_m, ti, tpi|
    test "#{hp} / #{dp} down @ #{rate}% / #{term}y -> P&I #{pi}, total #{total_m}" do
      calc = Calculators::Mortgage.new(
        home_price: hp, down_payment: dp, annual_rate: rate, loan_term_years: term,
        annual_property_tax: tax, annual_home_insurance: ins, monthly_hoa: hoa
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result

      assert_equal loan_amt, result[:loan_amount], "loan_amount"
      assert_equal pi,       result[:pi_monthly], "pi_monthly"
      assert_equal tax_m,    result[:tax_monthly], "tax_monthly"
      assert_equal ins_m,    result[:insurance_monthly], "insurance_monthly"
      assert_equal hoa_m,    result[:hoa_monthly], "hoa_monthly"
      assert_equal total_m,  result[:total_monthly], "total_monthly"
      assert_equal ti,       result[:total_interest], "total_interest"
      assert_equal tpi,      result[:total_of_pi], "total_of_pi"
      assert_equal term * 12, result[:number_of_payments], "number_of_payments"

      # total_monthly == sum of its four components
      sum_components = [ pi, tax_m, ins_m, hoa_m ].sum { |s| BigDecimal(s) }
      assert_equal BigDecimal(total_m), sum_components, "total_monthly == Σ components"

      # total_of_pi == loan_amount + total_interest
      assert_equal BigDecimal(loan_amt) + BigDecimal(ti), BigDecimal(tpi), "total_of_pi == loan_amount + total_interest"
    end
  end

  # --- worked anchor (spec row 1): the month-1 P&I breakdown ---
  test "month-1 P&I breakdown matches the worked anchor for row 1" do
    result = mortgage_row1.result
    first = result[:schedule].first
    assert_equal 1, first[:month]
    assert_equal "1750.00", first[:interest],  "month-1 interest = 300000 × 0.07/12"
    assert_equal "245.91",  first[:principal], "month-1 principal = 1995.91 − 1750.00"
    assert_equal "299754.09", first[:balance], "month-1 balance"
    assert_equal "1995.91", first[:payment],   "month-1 P&I payment is the level payment"
  end

  # --- schedule shape (the tabular-output) ---
  test "schedule length equals number_of_payments and the final balance clears to zero" do
    result = mortgage_row1.result
    schedule = result[:schedule]
    assert_equal result[:number_of_payments], schedule.length, "schedule length == number_of_payments"
    assert_equal 360, schedule.length
    assert_equal 360, schedule.last[:month]
    assert_equal "0.00", schedule.last[:balance], "final-row balance == 0.00"
  end

  test "the schedule reconciles to the summary totals" do
    result = mortgage_row1.result
    schedule = result[:schedule]
    sum_interest = schedule.sum { |row| BigDecimal(row[:interest]) }
    sum_payment  = schedule.sum { |row| BigDecimal(row[:payment]) }
    assert_equal sum_interest, BigDecimal(result[:total_interest]), "Σ interest == total_interest"
    assert_equal sum_payment,  BigDecimal(result[:total_of_pi]),    "Σ payment == total_of_pi"
  end

  test "all schedule money fields are formatted to exactly two decimal places" do
    schedule = mortgage_row1.result[:schedule]
    schedule.each do |row|
      %i[payment interest principal balance].each do |key|
        assert_match(/\A\d+\.\d{2}\z/, row[key], "#{key} = #{row[key].inspect}")
      end
      assert_kind_of Integer, row[:month]
    end
  end

  test "non-final rows all carry the level P&I payment" do
    result = mortgage_row1.result
    level = result[:pi_monthly]
    result[:schedule][0..-2].each do |row|
      assert_equal level, row[:payment], "row #{row[:month]} payment"
    end
  end

  test "balances decrease monotonically to zero" do
    schedule = mortgage_row1.result[:schedule]
    prev = BigDecimal(300000)
    schedule.each do |row|
      bal = BigDecimal(row[:balance])
      assert_operator bal, :<, prev, "balance should decrease at month #{row[:month]}"
      assert_operator bal, :>=, 0
      prev = bal
    end
    assert_equal BigDecimal("0"), prev
  end

  # --- output contract: the exact set of result keys (the §4 result shape) ---
  test "result carries exactly the spec's output keys" do
    expected = %i[
      loan_amount pi_monthly tax_monthly insurance_monthly hoa_monthly
      total_monthly total_interest total_of_pi number_of_payments schedule chart
    ]
    assert_equal expected.sort, mortgage_row1.result.keys.sort
  end

  # --- chart series (the donut + balance curve) ---
  test "chart payment_components carries the four monthly slices as labelled money strings" do
    components = mortgage_row1.result[:chart][:payment_components]
    assert_equal(
      [
        { label: "Principal & interest", amount: "1995.91" },
        { label: "Property tax",         amount: "291.67" },
        { label: "Home insurance",       amount: "100.00" },
        { label: "HOA",                  amount: "50.00" }
      ],
      components
    )
  end

  test "chart payment_components sum to total_monthly" do
    result = mortgage_row1.result
    sum = result[:chart][:payment_components].sum { |c| BigDecimal(c[:amount]) }
    assert_equal BigDecimal(result[:total_monthly]), sum
  end

  test "chart balance_curve carries month 0, yearly samples, and the final month" do
    result = mortgage_row1.result
    curve = result[:chart][:balance_curve]

    assert_equal({ month: 0, balance: "300000.00" }, curve.first)
    assert_equal "0.00", curve.last[:balance]
    assert_equal 360, curve.last[:month]

    # month 0 + 30 yearly samples (12,24,…,360)
    assert_equal 31, curve.length
    assert_equal (0..360).step(12).to_a, curve.map { |pt| pt[:month] }

    # year-1 sample matches the schedule's month-12 balance.
    month12_balance = result[:schedule].find { |r| r[:month] == 12 }[:balance]
    assert_equal month12_balance, curve.find { |pt| pt[:month] == 12 }[:balance]
  end

  # --- add-ons omitted → treated as 0; total_monthly == pi_monthly ---
  test "tax, insurance and HOA default to zero when omitted" do
    calc = Calculators::Mortgage.new(
      home_price: 250000, down_payment: 50000, annual_rate: 6, loan_term_years: 15
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    result = calc.result
    assert_equal "0.00", result[:tax_monthly]
    assert_equal "0.00", result[:insurance_monthly]
    assert_equal "0.00", result[:hoa_monthly]
    assert_equal result[:pi_monthly], result[:total_monthly], "total_monthly == pi_monthly when no add-ons"
  end

  # --- zero-rate edge: P&I = loan_amount / n, no interest anywhere ---
  test "zero rate yields loan_amount/n P&I and zero interest in every row" do
    result = Calculators::Mortgage.new(
      home_price: 132000, down_payment: 12000, annual_rate: 0, loan_term_years: 1
    ).result
    assert_equal "10000.00", result[:pi_monthly] # 120000 / 12
    assert_equal "0.00", result[:total_interest]
    result[:schedule].each { |row| assert_equal "0.00", row[:interest] }
  end

  # --- full BigDecimal precision (string inputs coerced exactly) ---
  test "string inputs are coerced to exact BigDecimal" do
    calc = Calculators::Mortgage.new(
      home_price: "360000", down_payment: "60000", annual_rate: "7", loan_term_years: "30",
      annual_property_tax: "3500", annual_home_insurance: "1200", monthly_hoa: "50"
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "1995.91", calc.result[:pi_monthly]
    assert_equal "2437.58", calc.result[:total_monthly]
  end

  # ----------------------------------------------------------------------------
  # Validation
  # ----------------------------------------------------------------------------
  test "home_price is required" do
    calc = Calculators::Mortgage.new(down_payment: 60000, annual_rate: 7, loan_term_years: 30)
    assert_not calc.valid?
    assert_includes calc.errors[:home_price], "can't be blank"
    assert_nil calc.result
  end

  test "home_price must be greater than 0" do
    [ 0, -100 ].each do |bad|
      calc = Calculators::Mortgage.new(home_price: bad, down_payment: 0, annual_rate: 7, loan_term_years: 30)
      assert_not calc.valid?, "home_price=#{bad} should be invalid"
      assert_includes calc.errors[:home_price], "must be greater than 0"
    end
  end

  test "down_payment is required" do
    calc = Calculators::Mortgage.new(home_price: 360000, annual_rate: 7, loan_term_years: 30)
    assert_not calc.valid?
    assert_includes calc.errors[:down_payment], "can't be blank"
  end

  test "down_payment must be >= 0 (negative rejected, zero accepted)" do
    calc = Calculators::Mortgage.new(home_price: 360000, down_payment: -1, annual_rate: 7, loan_term_years: 30)
    assert_not calc.valid?
    assert_includes calc.errors[:down_payment], "must be greater than or equal to 0"

    zero = Calculators::Mortgage.new(home_price: 360000, down_payment: 0, annual_rate: 7, loan_term_years: 30)
    assert zero.valid?, zero.errors.full_messages.to_sentence
  end

  test "down_payment equal to home_price is invalid (loan amount must be > 0)" do
    calc = Calculators::Mortgage.new(home_price: 200000, down_payment: 200000, annual_rate: 5, loan_term_years: 30)
    assert_not calc.valid?
    assert_includes calc.errors[:down_payment], "must be less than the home price"
    assert_nil calc.result
  end

  test "down_payment greater than home_price is invalid" do
    calc = Calculators::Mortgage.new(home_price: 200000, down_payment: 250000, annual_rate: 5, loan_term_years: 30)
    assert_not calc.valid?
    assert_includes calc.errors[:down_payment], "must be less than the home price"
    assert_nil calc.result
  end

  test "annual_rate is required" do
    calc = Calculators::Mortgage.new(home_price: 360000, down_payment: 60000, loan_term_years: 30)
    assert_not calc.valid?
    assert_includes calc.errors[:annual_rate], "can't be blank"
  end

  test "annual_rate must be >= 0 (negative rejected, zero accepted)" do
    calc = Calculators::Mortgage.new(home_price: 360000, down_payment: 60000, annual_rate: -1, loan_term_years: 30)
    assert_not calc.valid?
    assert_includes calc.errors[:annual_rate], "must be greater than or equal to 0"
  end

  test "loan_term_years is required" do
    calc = Calculators::Mortgage.new(home_price: 360000, down_payment: 60000, annual_rate: 7)
    assert_not calc.valid?
    assert_includes calc.errors[:loan_term_years], "can't be blank"
  end

  test "loan_term_years must be greater than 0" do
    calc = Calculators::Mortgage.new(home_price: 360000, down_payment: 60000, annual_rate: 7, loan_term_years: 0)
    assert_not calc.valid?
    assert_includes calc.errors[:loan_term_years], "must be greater than 0"
  end

  test "a fractional loan_term_years is rejected, not silently truncated" do
    # The spec declares loan_term_years as :integer; Base's coercion guard (#109)
    # catches the raw "29.5" before the :integer cast truncates it, so a fractional
    # term is a hard 422 rather than a silent 29-year loan.
    calc = Calculators::Mortgage.new(home_price: 360000, down_payment: 60000, annual_rate: 7, loan_term_years: "29.5")
    assert_not calc.valid?
    assert_includes calc.errors[:loan_term_years], "must be a whole number"
    assert_nil calc.result
  end

  test "a non-numeric home_price fails validation" do
    # Base's coercion guard (#110) catches the raw "abc" before the :decimal cast
    # turns it into BigDecimal(0) — a label-led "is not a number", not a coerced 0.
    calc = Calculators::Mortgage.new(home_price: "abc", down_payment: 60000, annual_rate: 7, loan_term_years: 30)
    assert_not calc.valid?
    assert_includes calc.errors[:home_price], "is not a number"
    assert_nil calc.result
  end

  test "annual_property_tax must be >= 0" do
    calc = Calculators::Mortgage.new(
      home_price: 360000, down_payment: 60000, annual_rate: 7, loan_term_years: 30, annual_property_tax: -1
    )
    assert_not calc.valid?
    assert_includes calc.errors[:annual_property_tax], "must be greater than or equal to 0"
  end

  test "annual_home_insurance must be >= 0" do
    calc = Calculators::Mortgage.new(
      home_price: 360000, down_payment: 60000, annual_rate: 7, loan_term_years: 30, annual_home_insurance: -1
    )
    assert_not calc.valid?
    assert_includes calc.errors[:annual_home_insurance], "must be greater than or equal to 0"
  end

  test "monthly_hoa must be >= 0" do
    calc = Calculators::Mortgage.new(
      home_price: 360000, down_payment: 60000, annual_rate: 7, loan_term_years: 30, monthly_hoa: -1
    )
    assert_not calc.valid?
    assert_includes calc.errors[:monthly_hoa], "must be greater than or equal to 0"
  end

  # --- envelope/contract surface ---
  test "to_calculation records the slug, inputs and result" do
    calc = mortgage_row1
    record = calc.to_calculation
    assert_equal "mortgage", record.calculator
    assert_equal BigDecimal("360000"), BigDecimal(record.inputs["home_price"].to_s)
    assert_equal 360, record.result["schedule"].length
  end

  private

  def mortgage_row1
    Calculators::Mortgage.new(
      home_price: 360000, down_payment: 60000, annual_rate: 7, loan_term_years: 30,
      annual_property_tax: 3500, annual_home_insurance: 1200, monthly_hoa: 50
    )
  end
end
