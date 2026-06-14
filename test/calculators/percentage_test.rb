require "test_helper"

# Reference-value + validation tests for Calculators::Percentage (spec issue #30).
# The reference tables below are lifted verbatim from the spec's "Reference values"
# section — they pin correctness and must reproduce exactly (ARCHITECTURE.md §11).
class Calculators::PercentageTest < ActiveSupport::TestCase
  # --- Reference values: mode percent_of (value = v1 × percent / 100) ---
  [
    [ 50, 20, 10.0 ],
    [ 200, 5, 10.0 ],
    [ 0, 50, 0.0 ],
    [ 80, 0, 0.0 ]
  ].each do |v1, percent, expected|
    test "percent_of: #{v1}, #{percent}% -> #{expected}" do
      calc = Calculators::Percentage.new(mode: "percent_of", v1: v1, percent: percent)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal BigDecimal(expected.to_s), calc.result[:value]
    end
  end

  # --- Reference values: mode what_percent (percent = v1 / v2 × 100) ---
  [
    [ 10, 50, 20.0 ],
    [ 25, 200, 12.5 ],
    [ 0, 50, 0.0 ]
  ].each do |v1, v2, expected|
    test "what_percent: #{v1} is what % of #{v2} -> #{expected}" do
      calc = Calculators::Percentage.new(mode: "what_percent", v1: v1, v2: v2)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal BigDecimal(expected.to_s), calc.result[:percent]
    end
  end

  # --- Reference values: mode percent_of_what (base = v1 / (percent / 100)) ---
  [
    [ 10, 20, 50.0 ],
    [ 75, 7.5, 1000.0 ],
    [ 30, 100, 30.0 ]
  ].each do |v1, percent, expected|
    test "percent_of_what: #{v1} is #{percent}% of -> #{expected}" do
      calc = Calculators::Percentage.new(mode: "percent_of_what", v1: v1, percent: percent)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal BigDecimal(expected.to_s), calc.result[:base]
    end
  end

  # --- Reference values: mode difference (|v1-v2| / ((v1+v2)/2) × 100) ---
  [
    [ 10, 6, 50.0 ],
    [ 6, 10, 50.0 ],
    [ 50, 50, 0.0 ]
  ].each do |v1, v2, expected|
    test "difference: #{v1} and #{v2} -> #{expected}" do
      calc = Calculators::Percentage.new(mode: "difference", v1: v1, v2: v2)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal BigDecimal(expected.to_s), calc.result[:percent]
    end
  end

  # --- Reference values: mode change (incr: v×(1+p/100); decr: v×(1-p/100)) ---
  [
    [ 500, 10, "increase", 550.0 ],
    [ 500, 10, "decrease", 450.0 ],
    [ 100, 0, "increase", 100.0 ],
    [ 200, 50, "decrease", 100.0 ]
  ].each do |v1, percent, direction, expected|
    test "change: #{v1} #{direction} by #{percent}% -> #{expected}" do
      calc = Calculators::Percentage.new(mode: "change", v1: v1, percent: percent, direction: direction)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal BigDecimal(expected.to_s), calc.result[:value]
    end
  end

  # --- result carries only the selected mode's key(s) (the §4 result shape) ---
  {
    "percent_of" => { v1: 50, percent: 20 },
    "what_percent" => { v1: 10, v2: 50 },
    "percent_of_what" => { v1: 10, percent: 20 },
    "difference" => { v1: 10, v2: 6 },
    "change" => { v1: 500, percent: 10, direction: "increase" }
  }.each do |mode, inputs|
    expected_key = { "percent_of" => :value, "what_percent" => :percent,
                     "percent_of_what" => :base, "difference" => :percent,
                     "change" => :value }.fetch(mode)
    test "#{mode} result carries exactly the #{expected_key} key" do
      result = Calculators::Percentage.new(mode: mode, **inputs).result
      assert_equal [ expected_key ], result.keys
    end
  end

  # --- Full BigDecimal precision (no float drift) ---
  test "computes at full precision (1/3 of a percent)" do
    calc = Calculators::Percentage.new(mode: "what_percent", v1: 1, v2: 3)
    assert calc.valid?
    # 1 / 3 * 100 — BigDecimal carries far more places than a float's 33.33.
    assert_operator calc.result[:percent], :>, BigDecimal("33.3333333333")
  end

  # --- mode validation ---
  test "mode is required" do
    calc = Calculators::Percentage.new(mode: nil)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "can't be blank"
  end

  test "mode must be one of the known modes" do
    calc = Calculators::Percentage.new(mode: "bogus", v1: 1, v2: 2)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "is not included in the list"
    assert_nil calc.result
  end

  # --- per-mode required inputs ---
  test "percent_of requires v1 and percent" do
    calc = Calculators::Percentage.new(mode: "percent_of")
    assert_not calc.valid?
    assert_includes calc.errors[:v1], "can't be blank"
    assert_includes calc.errors[:percent], "can't be blank"
  end

  test "what_percent requires v1 and v2" do
    calc = Calculators::Percentage.new(mode: "what_percent")
    assert_not calc.valid?
    assert_includes calc.errors[:v1], "can't be blank"
    assert_includes calc.errors[:v2], "can't be blank"
  end

  test "percent_of_what requires v1 and percent" do
    calc = Calculators::Percentage.new(mode: "percent_of_what")
    assert_not calc.valid?
    assert_includes calc.errors[:v1], "can't be blank"
    assert_includes calc.errors[:percent], "can't be blank"
  end

  test "difference requires v1 and v2" do
    calc = Calculators::Percentage.new(mode: "difference")
    assert_not calc.valid?
    assert_includes calc.errors[:v1], "can't be blank"
    assert_includes calc.errors[:v2], "can't be blank"
  end

  test "change requires v1, percent and direction" do
    calc = Calculators::Percentage.new(mode: "change")
    assert_not calc.valid?
    assert_includes calc.errors[:v1], "can't be blank"
    assert_includes calc.errors[:percent], "can't be blank"
    assert_includes calc.errors[:direction], "can't be blank"
  end

  test "inputs not named by the mode are ignored, not required" do
    # percent_of needs only v1 + percent; v2/direction left blank is fine.
    calc = Calculators::Percentage.new(mode: "percent_of", v1: 50, percent: 20)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("10.0"), calc.result[:value]
  end

  test "numeric strings are accepted and coerced to exact BigDecimal" do
    calc = Calculators::Percentage.new(mode: "percent_of", v1: "50", percent: "20")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("10.0"), calc.result[:value]
  end

  test "a blank string required input fails as blank" do
    calc = Calculators::Percentage.new(mode: "percent_of", v1: "", percent: 20)
    assert_not calc.valid?
    assert_includes calc.errors[:v1], "can't be blank"
  end

  # --- direction validation (change only) ---
  test "change rejects a bad direction" do
    calc = Calculators::Percentage.new(mode: "change", v1: 100, percent: 10, direction: "sideways")
    assert_not calc.valid?
    assert_includes calc.errors[:direction], "is not included in the list"
    assert_nil calc.result
  end

  test "change rejects a blank direction" do
    calc = Calculators::Percentage.new(mode: "change", v1: 100, percent: 10, direction: "")
    assert_not calc.valid?
    assert_includes calc.errors[:direction], "can't be blank"
  end

  test "direction is ignored outside change mode" do
    calc = Calculators::Percentage.new(mode: "percent_of", v1: 50, percent: 20, direction: "sideways")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("10.0"), calc.result[:value]
  end

  # --- division-by-zero guards (validation, not exceptions) ---
  test "what_percent rejects v2 = 0" do
    calc = Calculators::Percentage.new(mode: "what_percent", v1: 10, v2: 0)
    assert_not calc.valid?
    assert_includes calc.errors[:v2], "must be other than 0"
    assert_nil calc.result
  end

  test "percent_of_what rejects percent = 0" do
    calc = Calculators::Percentage.new(mode: "percent_of_what", v1: 10, percent: 0)
    assert_not calc.valid?
    assert_includes calc.errors[:percent], "must be other than 0"
    assert_nil calc.result
  end

  test "difference rejects v1 + v2 = 0 (a whole-record :base error)" do
    calc = Calculators::Percentage.new(mode: "difference", v1: 5, v2: -5)
    assert_not calc.valid?
    assert_includes calc.errors[:base], "must be other than 0"
    assert_nil calc.result
  end

  test "difference allows a nonzero sum (e.g. opposite signs that don't cancel)" do
    calc = Calculators::Percentage.new(mode: "difference", v1: 10, v2: -6)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    # |10 − (−6)| / ((10 + (−6))/2) × 100 = 16 / 2 × 100 = 800
    assert_equal BigDecimal("800"), calc.result[:percent]
  end

  # --- envelope/contract surface ---
  test "to_calculation records the slug, inputs and the mode's result key" do
    calc = Calculators::Percentage.new(mode: "percent_of", v1: 50, percent: 20)
    record = calc.to_calculation
    assert_equal "percentage", record.calculator
    assert_equal "percent_of", record.inputs["mode"]
    # jsonb stringifies hash keys on assignment, so the symbol-keyed compute
    # result is read back under its string key.
    assert_equal BigDecimal("10.0"), BigDecimal(record.result["value"].to_s)
  end
end
