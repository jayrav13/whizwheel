require "test_helper"

# Reference-value + validation tests for Calculators::CompoundInterest (spec issue
# #188). The reference table is lifted verbatim from the spec's "Reference values"
# section — it pins correctness and must reproduce exactly (ARCHITECTURE.md §11).
# This is a multi-mode (compounding-frequency picker) calculator with a growth-series
# chart, so the suite also asserts each mode's m, the growth-series shape, and that
# the series anchors the spec's worked example (year 0 = principal, year 10 = FV).
class Calculators::CompoundInterestTest < ActiveSupport::TestCase
  # [ principal, annual_rate, years, compounding, m, future_value, total_interest ]
  REFERENCE = [
    [ 20000, 5,   10, "monthly",   12,  "32940.19", "12940.19" ],
    [ 10000, 6,   5,  "annually",  1,   "13382.26", "3382.26" ],
    [ 5000,  8,   3,  "quarterly", 4,   "6341.21",  "1341.21" ],
    [ 15000, 4.5, 2,  "daily",     365, "16412.52", "1412.52" ],
    [ 1000,  0,   5,  "monthly",   12,  "1000.00",  "0.00" ]
  ].freeze

  REFERENCE.each do |p, rate, y, mode, m, fv, ti|
    test "#{p} @ #{rate}% #{mode} #{y}y -> FV #{fv}, interest #{ti}" do
      calc = Calculators::CompoundInterest.new(
        principal: p, annual_rate: rate, years: y, compounding: mode
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result

      assert_equal fv, result[:future_value], "future_value"
      assert_equal ti, result[:total_interest], "total_interest"
      assert_equal m,  result[:periods_per_year], "periods_per_year"
      assert_equal mode, result[:compounding], "compounding echo"

      # total_interest == future_value − principal
      assert_equal BigDecimal(fv) - BigDecimal(p), BigDecimal(ti)
    end
  end

  # --- each compounding mode maps to the spec's periods/year ---
  test "each compounding mode maps to its periods per year" do
    {
      "annually" => 1, "semiannually" => 2, "quarterly" => 4,
      "monthly" => 12, "daily" => 365
    }.each do |mode, m|
      result = Calculators::CompoundInterest.new(
        principal: 1000, annual_rate: 5, years: 1, compounding: mode
      ).result
      assert_equal m, result[:periods_per_year], "#{mode} -> m"
    end
  end

  # --- output contract: the exact set of result keys (the §4 result shape) ---
  test "result carries exactly the spec's output keys" do
    result = Calculators::CompoundInterest.new(
      principal: 20000, annual_rate: 5, years: 10, compounding: "monthly"
    ).result
    expected = %i[future_value total_interest principal periods_per_year compounding growth_series]
    assert_equal expected.sort, result.keys.sort
  end

  # --- principal echo is a two-dp money string ---
  test "principal is echoed as a two-decimal money string" do
    result = Calculators::CompoundInterest.new(
      principal: "5000", annual_rate: 8, years: 3, compounding: "quarterly"
    ).result
    assert_equal "5000.00", result[:principal]
  end

  # ----------------------------------------------------------------------------
  # Growth series (the chart data — the FE draws the curve without doing math)
  # ----------------------------------------------------------------------------
  test "growth series has one row per whole year, year 0 = principal, last year = FV" do
    result = Calculators::CompoundInterest.new(
      principal: 20000, annual_rate: 5, years: 10, compounding: "monthly"
    ).result
    series = result[:growth_series]

    # years 0..10 inclusive => 11 points.
    assert_equal 11, series.length
    assert_equal (0..10).to_a, series.map { |pt| pt[:year] }

    # year 0 is exactly the principal; the final year is the future value.
    assert_equal "20000.00", series.first[:balance]
    assert_equal 0, series.first[:year]
    assert_equal result[:future_value], series.last[:balance]
    assert_equal 10, series.last[:year]
  end

  test "growth series balances are computed by the authoritative balance formula" do
    # balance_y = P × (1 + r/m)^(m·y), rounded to the cent. Spot-check year 5 of the
    # worked anchor against an independent BigDecimal evaluation of that formula.
    result = Calculators::CompoundInterest.new(
      principal: 20000, annual_rate: 5, years: 10, compounding: "monthly"
    ).result
    base = 1 + (BigDecimal("5") / 100 / 12)
    expected_y5 = (BigDecimal("20000") * base.power(12 * 5, 60)).round(2).to_s("F")
    actual_y5 = result[:growth_series].find { |pt| pt[:year] == 5 }[:balance]
    assert_equal expected_y5, actual_y5
  end

  test "every growth-series balance is a two-decimal money string" do
    series = Calculators::CompoundInterest.new(
      principal: 5000, annual_rate: 8, years: 3, compounding: "quarterly"
    ).result[:growth_series]
    series.each do |pt|
      assert_match(/\A\d+\.\d{2}\z/, pt[:balance], "balance #{pt.inspect}")
      assert_kind_of Integer, pt[:year]
    end
  end

  test "growth series is monotonically non-decreasing for a positive rate" do
    series = Calculators::CompoundInterest.new(
      principal: 10000, annual_rate: 6, years: 5, compounding: "annually"
    ).result[:growth_series]
    prev = BigDecimal("0")
    series.each do |pt|
      bal = BigDecimal(pt[:balance])
      assert_operator bal, :>=, prev, "balance should not decrease at year #{pt[:year]}"
      prev = bal
    end
  end

  # --- fractional term: the series ends exactly on the term, labelled with t ---
  test "a fractional term appends the term endpoint with a decimal year label" do
    result = Calculators::CompoundInterest.new(
      principal: 1000, annual_rate: 5, years: "2.5", compounding: "annually"
    ).result
    series = result[:growth_series]

    # whole years 0,1,2,3 (ceil 2.5 == 3) plus the 2.5 endpoint => 5 points.
    assert_equal [ 0, 1, 2, 3, BigDecimal("2.5") ], series.map { |pt| pt[:year] }

    # the final point is the full-term future value.
    assert_equal result[:future_value], series.last[:balance]
    assert_kind_of BigDecimal, series.last[:year]
  end

  test "a fractional term computes the future value via the fractional exponent path" do
    # 2.5 years annually: A = 1000 × (1.05)^2.5, exact via exp(2.5·ln 1.05).
    result = Calculators::CompoundInterest.new(
      principal: 1000, annual_rate: 5, years: "2.5", compounding: "annually"
    ).result
    expected = (BigDecimal("1000") *
      BigMath.exp(BigDecimal("2.5") * BigMath.log(BigDecimal("1.05"), 60), 60)).round(2)
    whole, frac = expected.to_s("F").split(".")
    assert_equal "#{whole}.#{(frac.to_s + '00')[0, 2]}", result[:future_value]
  end

  # --- zero rate: no growth at all ---
  test "a zero rate yields future value equal to principal and zero interest" do
    result = Calculators::CompoundInterest.new(
      principal: 1000, annual_rate: 0, years: 5, compounding: "monthly"
    ).result
    assert_equal "1000.00", result[:future_value]
    assert_equal "0.00", result[:total_interest]
    result[:growth_series].each { |pt| assert_equal "1000.00", pt[:balance] }
  end

  # --- full BigDecimal precision (no float drift) on string inputs ---
  test "string inputs are coerced to exact BigDecimal" do
    calc = Calculators::CompoundInterest.new(
      principal: "20000", annual_rate: "5", years: "10", compounding: "monthly"
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "32940.19", calc.result[:future_value]
  end

  # ----------------------------------------------------------------------------
  # Validation
  # ----------------------------------------------------------------------------
  test "principal is required" do
    calc = Calculators::CompoundInterest.new(annual_rate: 5, years: 10, compounding: "monthly")
    assert_not calc.valid?
    assert_includes calc.errors[:principal], "can't be blank"
    assert_nil calc.result
  end

  test "principal must be greater than 0" do
    [ 0, -100 ].each do |bad|
      calc = Calculators::CompoundInterest.new(
        principal: bad, annual_rate: 5, years: 10, compounding: "monthly"
      )
      assert_not calc.valid?, "principal=#{bad} should be invalid"
      assert_includes calc.errors[:principal], "must be greater than 0"
    end
  end

  test "annual_rate is required" do
    calc = Calculators::CompoundInterest.new(principal: 20000, years: 10, compounding: "monthly")
    assert_not calc.valid?
    assert_includes calc.errors[:annual_rate], "can't be blank"
  end

  test "annual_rate must be >= 0 (negative rejected, zero accepted)" do
    neg = Calculators::CompoundInterest.new(
      principal: 20000, annual_rate: -1, years: 10, compounding: "monthly"
    )
    assert_not neg.valid?
    assert_includes neg.errors[:annual_rate], "must be greater than or equal to 0"

    zero = Calculators::CompoundInterest.new(
      principal: 1000, annual_rate: 0, years: 5, compounding: "monthly"
    )
    assert zero.valid?, zero.errors.full_messages.to_sentence
  end

  test "years is required" do
    calc = Calculators::CompoundInterest.new(principal: 20000, annual_rate: 5, compounding: "monthly")
    assert_not calc.valid?
    assert_includes calc.errors[:years], "can't be blank"
  end

  test "years must be greater than 0" do
    calc = Calculators::CompoundInterest.new(
      principal: 20000, annual_rate: 5, years: 0, compounding: "monthly"
    )
    assert_not calc.valid?
    assert_includes calc.errors[:years], "must be greater than 0"
    assert_nil calc.result
  end

  test "compounding is required" do
    calc = Calculators::CompoundInterest.new(principal: 20000, annual_rate: 5, years: 10)
    assert_not calc.valid?
    assert_includes calc.errors[:compounding], "can't be blank"
  end

  test "compounding must be one of the allowed modes" do
    calc = Calculators::CompoundInterest.new(
      principal: 20000, annual_rate: 5, years: 10, compounding: "weekly"
    )
    assert_not calc.valid?
    assert_includes calc.errors[:compounding], "is not included in the list"
    assert_nil calc.result
  end

  test "a non-numeric annual_rate fails validation (Base numeric guard)" do
    # Base's coercion guard (#110) catches the raw "abc" before the :decimal cast
    # turns it into BigDecimal(0) — a label-led "is not a number", not a coerced 0.
    calc = Calculators::CompoundInterest.new(
      principal: 20000, annual_rate: "abc", years: 10, compounding: "monthly"
    )
    assert_not calc.valid?
    assert_includes calc.errors[:annual_rate], "is not a number"
    assert_nil calc.result
  end

  # --- envelope/contract surface ---
  test "to_calculation records the slug, inputs and result" do
    calc = Calculators::CompoundInterest.new(
      principal: 20000, annual_rate: 5, years: 10, compounding: "monthly"
    )
    record = calc.to_calculation
    assert_equal "compound_interest", record.calculator
    assert_equal "monthly", record.inputs["compounding"]
    assert_equal "32940.19", record.result["future_value"]
    assert_equal 11, record.result["growth_series"].length
  end
end
