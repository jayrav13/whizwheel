require "test_helper"

# Reference-value + validation tests for Calculators::Amortization (spec issue #83).
# The reference table is lifted verbatim from the spec's "Reference values" section —
# it pins correctness and must reproduce exactly (ARCHITECTURE.md §11). This is the
# project's first tabular-output + charts calculator, so the suite also asserts the
# schedule shape (length, first/last rows) and that the schedule reconciles to the
# summary totals.
class Calculators::AmortizationTest < ActiveSupport::TestCase
  # [ principal, annual_rate, years,
  #   monthly_payment, total_paid, total_interest,
  #   m1_interest, m1_principal, m1_balance, final_balance, n ]
  REFERENCE = [
    [ 100000, 6,   30, "599.55",  "215838.45", "115838.45", "500.00", "99.55",   "99900.45",  "0.00", 360 ],
    [ 200000, 5,   15, "1581.59", "284685.48", "84685.48",  "833.33", "748.26",  "199251.74", "0.00", 180 ],
    [ 10000,  4.5, 5,  "186.43",  "11185.83",  "1185.83",   "37.50",  "148.93",  "9851.07",   "0.00", 60 ],
    [ 12000,  0,   1,  "1000.00", "12000.00",  "0.00",      "0.00",   "1000.00", "11000.00",  "0.00", 12 ]
  ].freeze

  REFERENCE.each do |p, rate, y, pay, total, interest, m1_int, m1_prin, m1_bal, final_bal, n|
    test "#{p} @ #{rate}% / #{y}y -> payment #{pay}, total #{total}, interest #{interest}" do
      calc = Calculators::Amortization.new(principal: p, annual_rate: rate, years: y)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result

      # --- summary figures (money as two-dp display strings) ---
      assert_equal pay,      result[:monthly_payment], "monthly_payment"
      assert_equal total,    result[:total_paid], "total_paid"
      assert_equal interest, result[:total_interest], "total_interest"
      assert_equal n, result[:number_of_payments], "number_of_payments"

      # --- schedule shape (the tabular-output) ---
      schedule = result[:schedule]
      assert_equal n, schedule.length, "schedule length == number_of_payments"

      first = schedule.first
      assert_equal 1, first[:month]
      assert_equal m1_int,  first[:interest],  "month-1 interest"
      assert_equal m1_prin, first[:principal], "month-1 principal"
      assert_equal m1_bal,  first[:balance],   "month-1 balance"
      # month-1 payment is the level payment.
      assert_equal pay, first[:payment], "month-1 payment"

      last = schedule.last
      assert_equal n, last[:month]
      assert_equal final_bal, last[:balance], "final-row balance == 0.00"

      # --- reconciliation: the schedule sums to the summary totals (§ spec) ---
      sum_interest = schedule.sum { |row| BigDecimal(row[:interest]) }
      sum_payment  = schedule.sum { |row| BigDecimal(row[:payment]) }
      assert_equal BigDecimal(interest), sum_interest, "Σ interest == total_interest"
      assert_equal BigDecimal(total),    sum_payment,  "Σ payment == total_paid"
      assert_equal sum_interest, BigDecimal(result[:total_interest])
      assert_equal sum_payment,  BigDecimal(result[:total_paid])

      # total_paid == principal + total_interest
      assert_equal BigDecimal(p) + BigDecimal(interest), BigDecimal(total)
    end
  end

  # --- every schedule row is two-decimal money strings ---
  test "all schedule money fields are formatted to exactly two decimal places" do
    schedule = Calculators::Amortization.new(principal: 100000, annual_rate: 6, years: 30).result[:schedule]
    schedule.each do |row|
      %i[payment interest principal balance].each do |key|
        assert_match(/\A\d+\.\d{2}\z/, row[key], "#{key} = #{row[key].inspect}")
      end
      assert_kind_of Integer, row[:month]
    end
  end

  # --- every row's payment equals the level payment except the final one, which may
  #     absorb a few cents of rounding (spec's "final payment" rule) ---
  test "non-final rows all carry the level monthly payment" do
    result = Calculators::Amortization.new(principal: 10000, annual_rate: 4.5, years: 5).result
    level = result[:monthly_payment]
    result[:schedule][0..-2].each do |row|
      assert_equal level, row[:payment], "row #{row[:month]} payment"
    end
  end

  # --- balances strictly decrease and never go negative ---
  test "balances decrease monotonically to zero" do
    schedule = Calculators::Amortization.new(principal: 200000, annual_rate: 5, years: 15).result[:schedule]
    prev = BigDecimal(200000)
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
    result = Calculators::Amortization.new(principal: 100000, annual_rate: 6, years: 30).result
    expected = %i[monthly_payment total_paid total_interest number_of_payments schedule chart]
    assert_equal expected.sort, result.keys.sort
  end

  # --- chart series (the charts output — donut + balance curve) ---
  test "chart carries the donut slices (principal vs. total interest) as money strings" do
    result = Calculators::Amortization.new(principal: 100000, annual_rate: 6, years: 30).result
    chart = result[:chart]
    assert_equal "100000.00", chart[:principal]
    assert_equal "115838.45", chart[:total_interest]
    assert_equal result[:total_interest], chart[:total_interest]
  end

  test "chart balance_curve carries month 0, yearly samples, and the final month" do
    result = Calculators::Amortization.new(principal: 100000, annual_rate: 6, years: 30).result
    curve = result[:chart][:balance_curve]

    # endpoints
    assert_equal({ month: 0, balance: "100000.00" }, curve.first)
    assert_equal "0.00", curve.last[:balance]
    assert_equal 360, curve.last[:month]

    # month 0 + 30 yearly samples (12,24,…,360); month 360 coincides with the final.
    assert_equal 31, curve.length
    assert_equal (0..360).step(12).to_a, curve.map { |pt| pt[:month] }

    # year-1 sample matches the schedule's month-12 balance.
    month12_balance = result[:schedule].find { |r| r[:month] == 12 }[:balance]
    assert_equal month12_balance, curve.find { |pt| pt[:month] == 12 }[:balance]
  end

  test "balance_curve ends on the final month (a yearly sample, since n is 12 × years)" do
    result = Calculators::Amortization.new(principal: 5000, annual_rate: 3, years: 1).result
    n = result[:number_of_payments]
    assert_equal 12, n
    curve = result[:chart][:balance_curve]
    assert_equal n, curve.last[:month]
    assert_equal "0.00", curve.last[:balance]
  end

  # --- zero-rate edge: payment = P / n, no interest anywhere ---
  test "zero rate yields P/n payment and zero interest in every row" do
    result = Calculators::Amortization.new(principal: 12000, annual_rate: 0, years: 1).result
    assert_equal "1000.00", result[:monthly_payment]
    assert_equal "0.00", result[:total_interest]
    result[:schedule].each { |row| assert_equal "0.00", row[:interest] }
  end

  # --- full BigDecimal precision (no float drift) on the raw payment ---
  test "string inputs are coerced to exact BigDecimal" do
    calc = Calculators::Amortization.new(principal: "200000", annual_rate: "5", years: "15")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "1581.59", calc.result[:monthly_payment]
  end

  # ----------------------------------------------------------------------------
  # Validation
  # ----------------------------------------------------------------------------
  test "principal is required" do
    calc = Calculators::Amortization.new(annual_rate: 5, years: 15)
    assert_not calc.valid?
    assert_includes calc.errors[:principal], "can't be blank"
    assert_nil calc.result
  end

  test "principal must be greater than 0" do
    [ 0, -100 ].each do |bad|
      calc = Calculators::Amortization.new(principal: bad, annual_rate: 5, years: 15)
      assert_not calc.valid?, "principal=#{bad} should be invalid"
      assert_includes calc.errors[:principal], "must be greater than 0"
    end
  end

  test "annual_rate is required" do
    calc = Calculators::Amortization.new(principal: 100000, years: 15)
    assert_not calc.valid?
    assert_includes calc.errors[:annual_rate], "can't be blank"
  end

  test "annual_rate must be >= 0 (negative rejected, zero accepted)" do
    calc = Calculators::Amortization.new(principal: 100000, annual_rate: -1, years: 15)
    assert_not calc.valid?
    assert_includes calc.errors[:annual_rate], "must be greater than or equal to 0"

    zero = Calculators::Amortization.new(principal: 12000, annual_rate: 0, years: 1)
    assert zero.valid?, zero.errors.full_messages.to_sentence
  end

  test "years is required" do
    calc = Calculators::Amortization.new(principal: 100000, annual_rate: 5)
    assert_not calc.valid?
    assert_includes calc.errors[:years], "can't be blank"
  end

  test "years must be a positive integer" do
    zero = Calculators::Amortization.new(principal: 100000, annual_rate: 5, years: 0)
    assert_not zero.valid?
    assert_includes zero.errors[:years], "must be greater than 0"
  end

  test "a fractional years value is rejected, not silently truncated" do
    # The spec declares years as :integer; Base's coercion guard (#109) catches the
    # raw "2.5" before the :integer cast truncates it to 2, so a fractional term is a
    # hard 422 rather than a silent 2-year (24-month) loan. The term is whole years.
    calc = Calculators::Amortization.new(principal: 100000, annual_rate: 5, years: "2.5")
    assert_not calc.valid?
    assert_includes calc.errors[:years], "must be a whole number"
    assert_nil calc.result
  end

  test "a non-numeric principal fails validation" do
    # Base's coercion guard (#110) catches the raw "abc" before the :decimal cast
    # turns it into BigDecimal(0) — a label-led "is not a number", not a coerced 0.
    calc = Calculators::Amortization.new(principal: "abc", annual_rate: 5, years: 15)
    assert_not calc.valid?
    assert_includes calc.errors[:principal], "is not a number"
    assert_nil calc.result
  end

  # --- envelope/contract surface ---
  test "to_calculation records the slug, inputs and result" do
    calc = Calculators::Amortization.new(principal: 100000, annual_rate: 6, years: 30)
    record = calc.to_calculation
    assert_equal "amortization", record.calculator
    assert_equal BigDecimal("100000"), BigDecimal(record.inputs["principal"].to_s)
    # the schedule survives as an array of 360 month rows.
    assert_equal 360, record.result["schedule"].length
  end
end
