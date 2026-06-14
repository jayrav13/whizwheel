require "test_helper"

# Reference-value + validation tests for Calculators::SimpleInterest (spec issue
# #77). The reference table below is lifted verbatim from the spec's "Reference
# values" section — it pins correctness and must reproduce exactly
# (ARCHITECTURE.md §11).
class Calculators::SimpleInterestTest < ActiveSupport::TestCase
  # --- Reference values: {principal, rate, time, unit} -> {interest, total} ---
  [
    [ 1000, 5,   3,  "years",  "150.00", "1150.00" ],
    [ 5000, 3.5, 2,  "years",  "350.00", "5350.00" ],
    [ 1000, 5,   6,  "months", "25.00",  "1025.00" ],
    [ 2000, 6,   18, "months", "180.00", "2180.00" ],
    [ 1000, 0,   5,  "years",  "0.00",   "1000.00" ],
    [ 0,    5,   3,  "years",  "0.00",   "0.00" ]
  ].each do |principal, rate, time, unit, interest, total|
    test "#{principal} @ #{rate}% for #{time} #{unit} -> interest #{interest}, total #{total}" do
      calc = Calculators::SimpleInterest.new(
        principal: principal, rate: rate, time: time, unit: unit
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal BigDecimal(interest), calc.result[:interest]
      assert_equal BigDecimal(total), calc.result[:total]
    end
  end

  # --- unit default + months-before-formula conversion ---
  test "unit defaults to years when omitted" do
    calc = Calculators::SimpleInterest.new(principal: 1000, rate: 5, time: 3)
    assert_equal "years", calc.unit
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("150.00"), calc.result[:interest]
    assert_equal BigDecimal("1150.00"), calc.result[:total]
  end

  test "months are converted to years before the formula is applied" do
    # 12 months must equal 1 year for the same principal/rate.
    in_months = Calculators::SimpleInterest.new(principal: 1000, rate: 5, time: 12, unit: "months")
    in_years  = Calculators::SimpleInterest.new(principal: 1000, rate: 5, time: 1, unit: "years")
    assert_equal in_years.result[:interest], in_months.result[:interest]
    assert_equal in_years.result[:total], in_months.result[:total]
  end

  # --- Full BigDecimal precision, money rounded to 2 dp half-up for display ---
  test "interest is rounded to 2 dp half-up for display" do
    # 1000 @ 3.333% for 1 year = 33.33 exactly to 2dp (raw 33.330).
    calc = Calculators::SimpleInterest.new(principal: 1000, rate: 3.333, time: 1, unit: "years")
    assert_equal BigDecimal("33.33"), calc.result[:interest]
    assert_equal BigDecimal("1033.33"), calc.result[:total]
  end

  test "half-up rounding rounds a trailing 5 up, not to even" do
    # 1000 @ 1.125% for 1 year = 11.25 raw → already 2dp; force a 3rd-place 5:
    # 100 @ 1.125% for 1 year = 1.125 → half-up → 1.13 (banker's even would give 1.12).
    calc = Calculators::SimpleInterest.new(principal: 100, rate: 1.125, time: 1, unit: "years")
    assert_equal BigDecimal("1.13"), calc.result[:interest]
  end

  test "computes at full precision before display rounding" do
    # 1000 @ 7% for 7 months → time_in_years = 7/12, interest = 1000*0.07*(7/12)
    # = 40.8333... → display 40.83 (a float path would risk 40.83/40.84 drift).
    calc = Calculators::SimpleInterest.new(principal: 1000, rate: 7, time: 7, unit: "months")
    assert_equal BigDecimal("40.83"), calc.result[:interest]
    assert_equal BigDecimal("1040.83"), calc.result[:total]
  end

  # --- principal validation ---
  test "principal is required" do
    calc = Calculators::SimpleInterest.new(rate: 5, time: 3, unit: "years")
    assert_not calc.valid?
    assert_includes calc.errors[:principal], "can't be blank"
    assert_nil calc.result
  end

  test "principal must be >= 0" do
    calc = Calculators::SimpleInterest.new(principal: -1, rate: 5, time: 3, unit: "years")
    assert_not calc.valid?
    assert_includes calc.errors[:principal], "must be greater than or equal to 0"
  end

  test "a blank-string principal fails as blank" do
    calc = Calculators::SimpleInterest.new(principal: "", rate: 5, time: 3, unit: "years")
    assert_not calc.valid?
    assert_includes calc.errors[:principal], "can't be blank"
  end

  test "a non-numeric principal is rejected" do
    # Base's coercion guard (#110) catches the raw "lots" before the :decimal cast
    # turns it into BigDecimal(0) — so it is a hard validation error, not a silent 0.
    calc = Calculators::SimpleInterest.new(principal: "lots", rate: 5, time: 3, unit: "years")
    assert_not calc.valid?
    assert_includes calc.errors[:principal], "is not a number"
    assert_nil calc.result
  end

  # --- rate validation ---
  test "rate is required" do
    calc = Calculators::SimpleInterest.new(principal: 1000, time: 3, unit: "years")
    assert_not calc.valid?
    assert_includes calc.errors[:rate], "can't be blank"
  end

  test "rate must be >= 0" do
    calc = Calculators::SimpleInterest.new(principal: 1000, rate: -2, time: 3, unit: "years")
    assert_not calc.valid?
    assert_includes calc.errors[:rate], "must be greater than or equal to 0"
  end

  # --- time validation ---
  test "time is required" do
    calc = Calculators::SimpleInterest.new(principal: 1000, rate: 5, unit: "years")
    assert_not calc.valid?
    assert_includes calc.errors[:time], "can't be blank"
  end

  test "time must be >= 0" do
    calc = Calculators::SimpleInterest.new(principal: 1000, rate: 5, time: -3, unit: "years")
    assert_not calc.valid?
    assert_includes calc.errors[:time], "must be greater than or equal to 0"
  end

  # --- unit validation ---
  test "unit must be one of the known units" do
    calc = Calculators::SimpleInterest.new(principal: 1000, rate: 5, time: 3, unit: "days")
    assert_not calc.valid?
    assert_includes calc.errors[:unit], "is not included in the list"
    assert_nil calc.result
  end

  test "an explicitly-blank unit fails presence" do
    calc = Calculators::SimpleInterest.new(principal: 1000, rate: 5, time: 3, unit: "")
    assert_not calc.valid?
    assert_includes calc.errors[:unit], "can't be blank"
  end

  # --- coercion + envelope/contract surface ---
  test "numeric strings are accepted and coerced to exact BigDecimal" do
    calc = Calculators::SimpleInterest.new(
      principal: "5000", rate: "3.5", time: "2", unit: "years"
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("350.00"), calc.result[:interest]
    assert_equal BigDecimal("5350.00"), calc.result[:total]
  end

  test "result carries exactly the interest and total keys" do
    calc = Calculators::SimpleInterest.new(principal: 1000, rate: 5, time: 3, unit: "years")
    assert_equal %i[interest total], calc.result.keys.sort
  end

  test "to_calculation records the slug, inputs and result keys" do
    calc = Calculators::SimpleInterest.new(principal: 1000, rate: 5, time: 3, unit: "years")
    record = calc.to_calculation
    assert_equal "simple_interest", record.calculator
    assert_equal "years", record.inputs["unit"]
    # jsonb stringifies hash keys on assignment, so the symbol-keyed compute
    # result is read back under its string key.
    assert_equal BigDecimal("150.00"), BigDecimal(record.result["interest"].to_s)
    assert_equal BigDecimal("1150.00"), BigDecimal(record.result["total"].to_s)
  end
end
