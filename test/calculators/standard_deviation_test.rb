require "test_helper"

# Reference-value + validation tests for Calculators::StandardDeviation
# (spec issue #190). The reference table below is lifted verbatim from the spec's
# "Reference values" section — it pins correctness (population vs sample differ
# only by the n vs n−1 denominator) and must reproduce exactly (ARCHITECTURE.md §11).
class Calculators::StandardDeviationTest < ActiveSupport::TestCase
  # --- Reference values:
  #     {values, mode} -> {count, sum, mean, variance, standard_deviation} ---
  [
    [ "10,12,23,23,16,23,21,16", "population", 8, "144", "18.000000", "24.000000", "4.898979" ],
    [ "10,12,23,23,16,23,21,16", "sample",     8, "144", "18.000000", "27.428571", "5.237229" ],
    [ "2,4,6,8",                 "population", 4, "20",  "5.000000",  "5.000000",  "2.236068" ],
    [ "2,4,6,8",                 "sample",     4, "20",  "5.000000",  "6.666667",  "2.581989" ],
    [ "5,5,5",                   "population", 3, "15",  "5.000000",  "0.000000",  "0.000000" ],
    [ "5,5,5",                   "sample",     3, "15",  "5.000000",  "0.000000",  "0.000000" ]
  ].each do |values, mode, count, sum, mean, variance, sd|
    test "#{values.inspect} (#{mode}) -> mean #{mean}, variance #{variance}, sd #{sd}" do
      calc = Calculators::StandardDeviation.new(values: values, mode: mode)
      assert calc.valid?, calc.errors.full_messages.to_sentence

      r = calc.result
      assert_equal mode,              r[:mode]
      assert_equal count,             r[:count]
      assert_equal BigDecimal(sum),   r[:sum]
      assert_equal BigDecimal(mean),  r[:mean]
      assert_equal BigDecimal(variance), r[:variance]
      assert_equal BigDecimal(sd),    r[:standard_deviation]
    end
  end

  # --- the denominator difference, pinned directly -------------------------
  test "sample variance uses n−1 while population uses n on the same data" do
    pop = Calculators::StandardDeviation.new(values: "10,12,23,23,16,23,21,16", mode: "population")
    smp = Calculators::StandardDeviation.new(values: "10,12,23,23,16,23,21,16", mode: "sample")
    assert pop.valid?
    assert smp.valid?
    # SS = 192; population 192/8 = 24, sample 192/7 = 27.428571…
    assert_equal BigDecimal("24.000000"), pop.result[:variance]
    assert_equal BigDecimal("27.428571"), smp.result[:variance]
  end

  test "an all-equal set has zero variance and zero standard deviation in both modes" do
    %w[population sample].each do |mode|
      calc = Calculators::StandardDeviation.new(values: "5,5,5", mode: mode)
      assert calc.valid?
      assert_equal BigDecimal("0"), calc.result[:variance]
      assert_equal BigDecimal("0"), calc.result[:standard_deviation]
    end
  end

  # --- single value, population (defined for n ≥ 1) ------------------------
  test "a single value in population mode is valid: variance and SD are 0" do
    calc = Calculators::StandardDeviation.new(values: "5", mode: "population")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    r = calc.result
    assert_equal 1, r[:count]
    assert_equal BigDecimal("5"), r[:sum]
    assert_equal BigDecimal("5.000000"), r[:mean]
    assert_equal BigDecimal("0.000000"), r[:variance]
    assert_equal BigDecimal("0.000000"), r[:standard_deviation]
  end

  # --- precision / display rounding ----------------------------------------
  test "statistics are computed at full precision then rounded to 6 dp half-up" do
    # 20 / 3 = 6.6666666… -> 6.666667 (half-up at the 6th place).
    calc = Calculators::StandardDeviation.new(values: "2,4,6,8", mode: "sample")
    assert calc.valid?
    assert_equal BigDecimal("6.666667"), calc.result[:variance]
  end

  test "the square root is exact to 6 dp (√24)" do
    calc = Calculators::StandardDeviation.new(values: "10,12,23,23,16,23,21,16", mode: "population")
    assert calc.valid?
    # √24 = 4.89897948… -> 4.898979
    assert_equal BigDecimal("4.898979"), calc.result[:standard_deviation]
  end

  test "sum is exact (no float drift)" do
    calc = Calculators::StandardDeviation.new(values: "0.1, 0.2", mode: "population")
    assert calc.valid?
    assert_equal BigDecimal("0.3"), calc.result[:sum]
  end

  # --- list parsing ---------------------------------------------------------
  test "splits on commas" do
    calc = Calculators::StandardDeviation.new(values: "1,2,3", mode: "population")
    assert calc.valid?
    assert_equal 3, calc.result[:count]
    assert_equal BigDecimal("6"), calc.result[:sum]
  end

  test "splits on whitespace" do
    calc = Calculators::StandardDeviation.new(values: "1 2 3", mode: "population")
    assert calc.valid?
    assert_equal 3, calc.result[:count]
  end

  test "splits on mixed commas and whitespace and collapses separators" do
    calc = Calculators::StandardDeviation.new(values: " ,1, 2\t3\n4,, ", mode: "population")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 4, calc.result[:count]
    assert_equal BigDecimal("10"), calc.result[:sum]
  end

  test "accepts negative, decimal, signed and bare-fractional tokens" do
    calc = Calculators::StandardDeviation.new(values: "-2.5, +1, .5", mode: "population")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 3, calc.result[:count]
    assert_equal BigDecimal("-1"), calc.result[:sum]
  end

  # --- validation -----------------------------------------------------------
  test "values is required" do
    calc = Calculators::StandardDeviation.new(values: nil, mode: "population")
    assert_not calc.valid?
    assert_includes calc.errors[:values], "can't be blank"
    assert_nil calc.result
  end

  test "a blank string is rejected as blank" do
    calc = Calculators::StandardDeviation.new(values: "", mode: "population")
    assert_not calc.valid?
    assert_includes calc.errors[:values], "can't be blank"
  end

  test "a separators-only string parses to nothing and is rejected" do
    calc = Calculators::StandardDeviation.new(values: " , , ", mode: "population")
    assert_not calc.valid?
    assert_includes calc.errors[:values], "can't be blank"
    assert_nil calc.result
  end

  test "a non-numeric token invalidates the whole input with the spec message" do
    calc = Calculators::StandardDeviation.new(values: "1, two, 3", mode: "population")
    assert_not calc.valid?
    assert_includes calc.errors[:values], "must be a list of numbers"
    assert_nil calc.result
  end

  test "a malformed numeric token (double dot) is rejected" do
    calc = Calculators::StandardDeviation.new(values: "1, 2.3.4", mode: "population")
    assert_not calc.valid?
    assert_includes calc.errors[:values], "must be a list of numbers"
  end

  test "mode is required" do
    calc = Calculators::StandardDeviation.new(values: "1, 2, 3", mode: nil)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "can't be blank"
    assert_nil calc.result
  end

  test "an unknown mode is rejected by the inclusion rule" do
    calc = Calculators::StandardDeviation.new(values: "1, 2, 3", mode: "pop")
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "is not included in the list"
    assert_nil calc.result
  end

  test "sample mode requires at least two values" do
    calc = Calculators::StandardDeviation.new(values: "5", mode: "sample")
    assert_not calc.valid?
    assert_includes calc.errors[:values], "need at least 2 values for sample mode"
    assert_nil calc.result
  end

  test "the sample-size check is skipped when the list has a non-numeric token" do
    # The list-of-numbers error should fire; we should NOT also blame the count.
    calc = Calculators::StandardDeviation.new(values: "x", mode: "sample")
    assert_not calc.valid?
    assert_includes calc.errors[:values], "must be a list of numbers"
    assert_not_includes calc.errors[:values], "need at least 2 values for sample mode"
  end

  test "the sample-size check is skipped when the list is blank" do
    calc = Calculators::StandardDeviation.new(values: "", mode: "sample")
    assert_not calc.valid?
    assert_includes calc.errors[:values], "can't be blank"
    assert_not_includes calc.errors[:values], "need at least 2 values for sample mode"
  end

  # --- envelope / contract surface ------------------------------------------
  test "to_calculation records the slug, inputs and result keys" do
    calc = Calculators::StandardDeviation.new(values: "2,4,6,8", mode: "sample")
    record = calc.to_calculation
    assert_equal "standard_deviation", record.calculator
    assert_equal "2,4,6,8", record.inputs["values"]
    assert_equal "sample", record.inputs["mode"]
    # jsonb stringifies hash keys on assignment, so read back under string keys.
    assert_equal "sample", record.result["mode"]
    assert_equal 4, record.result["count"]
    assert_equal BigDecimal("6.666667"), BigDecimal(record.result["variance"].to_s)
    assert_equal BigDecimal("2.581989"), BigDecimal(record.result["standard_deviation"].to_s)
  end

  test "the result carries exactly the six output keys" do
    calc = Calculators::StandardDeviation.new(values: "2,4,6,8", mode: "population")
    assert calc.valid?
    assert_equal %w[count mean mode standard_deviation sum variance], calc.result.keys.map(&:to_s).sort
  end
end
