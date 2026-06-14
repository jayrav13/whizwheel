require "test_helper"

# Reference-value + validation tests for Calculators::MeanMedianModeRange
# (spec issue #79). The reference table below is lifted verbatim from the spec's
# "Reference values" section — it pins correctness and must reproduce exactly
# (ARCHITECTURE.md §11).
class Calculators::MeanMedianModeRangeTest < ActiveSupport::TestCase
  # --- Reference values: {numbers} -> {mean, median, mode, range, sum, count,
  #     smallest, largest} ---
  [
    [ "10, 2, 38, 23, 38, 23, 21", "22.143", "23", [ "23", "38" ], "36", "155", 7, "2", "38" ],
    [ "1, 2, 3, 4, 5",            "3",      "3",  [],              "4",  "15",  5, "1", "5"  ],
    [ "4, 4, 4, 2, 2",           "3.2",    "4",  [ "4" ],          "2",  "16",  5, "2", "4"  ],
    [ "7",                        "7",      "7",  [],              "0",  "7",   1, "7", "7"  ],
    [ "2, 4, 6, 8",              "5",      "5",  [],              "6",  "20",  4, "2", "8"  ]
  ].each do |numbers, mean, median, mode, range, sum, count, smallest, largest|
    test "#{numbers.inspect} -> mean #{mean}, median #{median}, mode #{mode.inspect}" do
      calc = Calculators::MeanMedianModeRange.new(numbers: numbers)
      assert calc.valid?, calc.errors.full_messages.to_sentence

      r = calc.result
      assert_equal BigDecimal(mean),   r[:mean]
      assert_equal BigDecimal(median), r[:median]
      assert_equal mode.map { |m| BigDecimal(m) }, r[:mode]
      assert_equal BigDecimal(range),  r[:range]
      assert_equal BigDecimal(sum),    r[:sum]
      assert_equal count,              r[:count]
      assert_equal BigDecimal(smallest), r[:smallest]
      assert_equal BigDecimal(largest),  r[:largest]
    end
  end

  # --- mode semantics -------------------------------------------------------
  test "all-unique values yield no mode (empty array)" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "1, 2, 3, 4, 5")
    assert calc.valid?
    assert_equal [], calc.result[:mode]
  end

  test "a single value has no mode and a range of zero" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "7")
    assert calc.valid?
    assert_equal [], calc.result[:mode]
    assert_equal BigDecimal("0"), calc.result[:range]
  end

  test "unimodal returns a single-element array" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "4, 4, 4, 2, 2")
    assert calc.valid?
    assert_equal [ BigDecimal("4") ], calc.result[:mode]
  end

  test "multimodal returns all tied values, sorted ascending" do
    # 38 and 23 each appear twice; sorted ascending the array is [23, 38].
    calc = Calculators::MeanMedianModeRange.new(numbers: "38, 23, 10, 38, 23")
    assert calc.valid?
    assert_equal [ BigDecimal("23"), BigDecimal("38") ], calc.result[:mode]
  end

  test "a fully repeated value is itself the (single) mode" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "5, 5, 5")
    assert calc.valid?
    assert_equal [ BigDecimal("5") ], calc.result[:mode]
  end

  # --- median semantics -----------------------------------------------------
  test "odd count median is the middle value of the sorted list" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "5, 1, 3")
    assert calc.valid?
    assert_equal BigDecimal("3"), calc.result[:median]
  end

  test "even count median is the average of the two middle values" do
    # sorted [1, 2, 3, 4] -> (2 + 3) / 2 = 2.5
    calc = Calculators::MeanMedianModeRange.new(numbers: "4, 1, 3, 2")
    assert calc.valid?
    assert_equal BigDecimal("2.5"), calc.result[:median]
  end

  test "a fractional even-count median is rounded to 3 dp for display" do
    # sorted [0, 1] middle pair averaged with a third number to force >3 dp.
    # [1, 2] is too clean; use a pair whose mean has many places: (1 + 2) values
    # around a non-terminating average via three values is odd, so build an even
    # set whose middle average is non-terminating: [0, 0, 1, 1] -> (0+1)/2 = 0.5.
    # For a long decimal, average 1 and 2 of a set whose mid pair is 1 and 1.0001
    calc = Calculators::MeanMedianModeRange.new(numbers: "1, 1.000333, 0, 9")
    # sorted [0, 1, 1.000333, 9] -> (1 + 1.000333) / 2 = 1.0001665 -> 1.000 (3 dp)
    assert calc.valid?
    assert_equal BigDecimal("1.000"), calc.result[:median]
  end

  # --- mean precision + display rounding ------------------------------------
  test "mean is computed at full precision then rounded to 3 dp half-up" do
    # 155 / 7 = 22.142857142857... -> 22.143 (half-up at the 3rd place).
    calc = Calculators::MeanMedianModeRange.new(numbers: "10, 2, 38, 23, 38, 23, 21")
    assert calc.valid?
    assert_equal BigDecimal("22.143"), calc.result[:mean]
  end

  test "an integer mean is returned whole (no trailing zeros)" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "2, 4, 6")
    assert calc.valid?
    assert_equal BigDecimal("4"), calc.result[:mean]
    assert_equal 0, calc.result[:mean].frac
  end

  # --- list parsing (the headline stressor) ---------------------------------
  test "splits on commas" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "1,2,3")
    assert calc.valid?
    assert_equal 3, calc.result[:count]
    assert_equal BigDecimal("6"), calc.result[:sum]
  end

  test "splits on whitespace" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "1 2 3")
    assert calc.valid?
    assert_equal 3, calc.result[:count]
  end

  test "splits on mixed commas and whitespace" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "1, 2\t3\n4")
    assert calc.valid?
    assert_equal 4, calc.result[:count]
    assert_equal BigDecimal("10"), calc.result[:sum]
  end

  test "collapses consecutive separators and tolerates trailing/leading ones" do
    calc = Calculators::MeanMedianModeRange.new(numbers: " ,, 1,  2 ,,3,, ")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 3, calc.result[:count]
    assert_equal BigDecimal("6"), calc.result[:sum]
  end

  test "accepts negative and decimal tokens" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "-2.5, 0, 2.5")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("0"), calc.result[:sum]
    assert_equal BigDecimal("-2.5"), calc.result[:smallest]
    assert_equal BigDecimal("2.5"), calc.result[:largest]
  end

  test "accepts an explicit plus sign and a bare fractional" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "+3, .5")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("3.5"), calc.result[:sum]
  end

  test "values are coerced to exact BigDecimal (no float drift)" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "0.1, 0.2")
    assert calc.valid?
    assert_equal BigDecimal("0.3"), calc.result[:sum]
  end

  # --- validation -----------------------------------------------------------
  test "numbers is required" do
    calc = Calculators::MeanMedianModeRange.new(numbers: nil)
    assert_not calc.valid?
    assert_includes calc.errors[:numbers], "can't be blank"
    assert_nil calc.result
  end

  test "a blank string is rejected as blank" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "")
    assert_not calc.valid?
    assert_includes calc.errors[:numbers], "can't be blank"
  end

  test "a separators-only string parses to nothing and is rejected" do
    calc = Calculators::MeanMedianModeRange.new(numbers: " , , ")
    assert_not calc.valid?
    assert_includes calc.errors[:numbers], "can't be blank"
    assert_nil calc.result
  end

  test "a non-numeric token invalidates the whole input (not silently dropped)" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "1, 2, foo, 4")
    assert_not calc.valid?
    assert_includes calc.errors[:numbers], "contains a value that is not a number: foo"
    assert_nil calc.result
  end

  test "all non-numeric tokens are reported, not just the first" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "1, foo, 2, bar")
    assert_not calc.valid?
    assert_includes calc.errors[:numbers], "contains a value that is not a number: foo, bar"
  end

  test "a malformed numeric token (double dot) is rejected" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "1, 2.3.4")
    assert_not calc.valid?
    assert_includes calc.errors[:numbers], "contains a value that is not a number: 2.3.4"
  end

  test "a lone sign is not a valid number" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "1, -, 3")
    assert_not calc.valid?
    assert_includes calc.errors[:numbers], "contains a value that is not a number: -"
  end

  # --- envelope / contract surface ------------------------------------------
  test "to_calculation records the slug, inputs and result keys" do
    calc = Calculators::MeanMedianModeRange.new(numbers: "4, 4, 4, 2, 2")
    record = calc.to_calculation
    assert_equal "mean_median_mode_range", record.calculator
    assert_equal "4, 4, 4, 2, 2", record.inputs["numbers"]
    # jsonb stringifies hash keys on assignment, so the symbol-keyed compute
    # result is read back under its string key.
    assert_equal BigDecimal("3.2"), BigDecimal(record.result["mean"].to_s)
    assert_equal 5, record.result["count"]
    assert_equal [ BigDecimal("4") ], record.result["mode"].map { |m| BigDecimal(m.to_s) }
  end
end
