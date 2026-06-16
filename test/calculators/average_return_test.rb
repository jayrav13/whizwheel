require "test_helper"

# Reference-value + validation tests for Calculators::AverageReturn (spec issue #247).
# The reference table below is lifted VERBATIM from the spec's "Reference values"
# section — it pins correctness (the arithmetic mean alongside the compounded
# geometric average, computed via a real-precision n-th root) and must reproduce
# exactly (ARCHITECTURE.md §11). Expected percentages are compared as BigDecimal, so
# the 4-dp display padding (a frontend concern) does not affect the assertions.
class Calculators::AverageReturnTest < ActiveSupport::TestCase
  # --- Reference values: {returns} -> {count, arithmetic_average, geometric_average} ---
  [
    [ %w[10 20 -5 15], 4, "10.0000", "9.5844" ],
    [ %w[5 5 5 5],     4, "5.0000",  "5.0000" ],
    [ %w[100 -50],     2, "25.0000", "0.0000" ],
    [ %w[10 -10],      2, "0.0000",  "-0.5013" ]
  ].each do |returns, count, arithmetic, geometric|
    test "#{returns.inspect} -> arithmetic #{arithmetic}, geometric #{geometric}" do
      calc = Calculators::AverageReturn.new(returns: returns)
      assert calc.valid?, calc.errors.full_messages.to_sentence

      r = calc.result
      assert_equal count,                    r[:count]
      assert_equal BigDecimal(arithmetic),   r[:arithmetic_average]
      assert_equal BigDecimal(geometric),    r[:geometric_average]
    end
  end

  # --- worked anchors, pinned directly -------------------------------------

  test "the +100%/−50% sequence nets zero geometric growth yet a +25% arithmetic average" do
    calc = Calculators::AverageReturn.new(returns: %w[100 -50])
    assert calc.valid?
    # growth factor 2.0 × 0.5 = 1.0 → geometric (1.0^(1/2) − 1) × 100 = 0
    assert_equal BigDecimal("25"), calc.result[:arithmetic_average]
    assert_equal BigDecimal("0"),  calc.result[:geometric_average]
  end

  test "an arithmetic-zero sequence still loses ground geometrically" do
    calc = Calculators::AverageReturn.new(returns: %w[10 -10])
    assert calc.valid?
    # growth factor 1.10 × 0.90 = 0.99 → geometric (0.99^(1/2) − 1) × 100 = −0.5013…
    assert_equal BigDecimal("0"),       calc.result[:arithmetic_average]
    assert_equal BigDecimal("-0.5013"), calc.result[:geometric_average]
  end

  # --- single period: both averages equal ----------------------------------

  test "a single period makes the arithmetic and geometric averages equal" do
    calc = Calculators::AverageReturn.new(returns: %w[10])
    assert calc.valid?, calc.errors.full_messages.to_sentence
    r = calc.result
    assert_equal 1, r[:count]
    assert_equal BigDecimal("10"), r[:arithmetic_average]
    assert_equal BigDecimal("10"), r[:geometric_average]
  end

  # --- the degenerate total-loss case (growth factor 0) --------------------

  test "a −100% total-loss period drives the geometric average to exactly −100%" do
    calc = Calculators::AverageReturn.new(returns: %w[-100])
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("-100"), calc.result[:geometric_average]
  end

  test "a −100% period drags the geometric average to −100% regardless of other periods" do
    # growth factor = (1 + 0.50) × (1 + 0.20) × 0 = 0 → geometric average = −100%.
    calc = Calculators::AverageReturn.new(returns: %w[50 20 -100])
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("-100"), calc.result[:geometric_average]
  end

  # --- precision (BigDecimal, not float) -----------------------------------

  test "the geometric n-th root is computed at full precision, not float" do
    # √1.44210 − 1 over 4 periods → 9.5844% (half-up at the 4th place).
    calc = Calculators::AverageReturn.new(returns: %w[10 20 -5 15])
    assert calc.valid?
    assert_equal BigDecimal("9.5844"), calc.result[:geometric_average]
  end

  test "the arithmetic average is exact (no float drift)" do
    calc = Calculators::AverageReturn.new(returns: %w[0.1 0.2])
    assert calc.valid?
    # (0.1 + 0.2) / 2 = 0.15 exactly
    assert_equal BigDecimal("0.15"), calc.result[:arithmetic_average]
  end

  test "percentages are rounded to 4 dp half-up" do
    # 1/3 % per period over a single period → arithmetic 0.3333 (half-up at 4th dp).
    calc = Calculators::AverageReturn.new(returns: %w[0.33335])
    assert calc.valid?
    assert_equal BigDecimal("0.3334"), calc.result[:arithmetic_average]
  end

  # --- list handling --------------------------------------------------------

  test "blank and whitespace-only entries are dropped before validation" do
    calc = Calculators::AverageReturn.new(returns: [ "10", "", "  ", "20" ])
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 2, calc.result[:count]
    assert_equal BigDecimal("15"), calc.result[:arithmetic_average]
  end

  test "a lone scalar (not posted as an array) is accepted as a one-element list" do
    calc = Calculators::AverageReturn.new(returns: "10")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 1, calc.result[:count]
    assert_equal BigDecimal("10"), calc.result[:arithmetic_average]
  end

  test "accepts negative, signed and bare-fractional entries" do
    calc = Calculators::AverageReturn.new(returns: [ "-2.5", "+1", ".5" ])
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 3, calc.result[:count]
    # (−2.5 + 1 + 0.5) / 3 = −1 / 3 = −0.3333 (half-up at the 4th dp)
    assert_equal BigDecimal("-0.3333"), calc.result[:arithmetic_average]
  end

  # --- validation -----------------------------------------------------------

  test "an empty list is rejected (at least one value required)" do
    calc = Calculators::AverageReturn.new(returns: [])
    assert_not calc.valid?
    assert_includes calc.errors[:returns], "can't be blank"
    assert_nil calc.result
  end

  test "an all-blank list is rejected as blank" do
    calc = Calculators::AverageReturn.new(returns: [ "", "  ", nil ])
    assert_not calc.valid?
    assert_includes calc.errors[:returns], "can't be blank"
    assert_nil calc.result
  end

  test "nil returns is rejected as blank" do
    calc = Calculators::AverageReturn.new(returns: nil)
    assert_not calc.valid?
    assert_includes calc.errors[:returns], "can't be blank"
    assert_nil calc.result
  end

  test "a non-numeric entry invalidates the whole input" do
    calc = Calculators::AverageReturn.new(returns: [ "10", "x", "20" ])
    assert_not calc.valid?
    assert_includes calc.errors[:returns], "must be a list of numbers"
    assert_nil calc.result
  end

  test "a malformed numeric entry (double dot) is rejected" do
    calc = Calculators::AverageReturn.new(returns: [ "1", "2.3.4" ])
    assert_not calc.valid?
    assert_includes calc.errors[:returns], "must be a list of numbers"
  end

  test "a return below −100% is rejected (a negative growth factor is impossible)" do
    calc = Calculators::AverageReturn.new(returns: [ "-150" ])
    assert_not calc.valid?
    assert_includes calc.errors[:returns], "each return must be at least −100%"
    assert_nil calc.result
  end

  test "exactly −100% is allowed (the boundary is valid)" do
    calc = Calculators::AverageReturn.new(returns: [ "-100" ])
    assert calc.valid?, calc.errors.full_messages.to_sentence
  end

  test "the below-minimum check is skipped when an entry is non-numeric" do
    # The list-of-numbers error should fire; we should NOT also blame the minimum.
    calc = Calculators::AverageReturn.new(returns: [ "-150", "x" ])
    assert_not calc.valid?
    assert_includes calc.errors[:returns], "must be a list of numbers"
    assert_not_includes calc.errors[:returns], "each return must be at least −100%"
  end

  test "the numeric and minimum checks are skipped when the list is empty" do
    calc = Calculators::AverageReturn.new(returns: [])
    assert_not calc.valid?
    assert_equal [ "can't be blank" ], calc.errors[:returns]
  end

  # --- envelope / contract surface ------------------------------------------

  test "to_calculation records the slug, inputs and result keys" do
    calc = Calculators::AverageReturn.new(returns: %w[100 -50])
    record = calc.to_calculation
    assert_equal "average_return", record.calculator
    assert_equal %w[100 -50], record.inputs["returns"]
    # jsonb stringifies hash keys on assignment, so read back under string keys.
    assert_equal 2, record.result["count"]
    assert_equal BigDecimal("25"), BigDecimal(record.result["arithmetic_average"].to_s)
    assert_equal BigDecimal("0"),  BigDecimal(record.result["geometric_average"].to_s)
  end

  test "the result carries exactly the three output keys" do
    calc = Calculators::AverageReturn.new(returns: %w[10 20])
    assert calc.valid?
    assert_equal %w[arithmetic_average count geometric_average], calc.result.keys.map(&:to_s).sort
  end
end
