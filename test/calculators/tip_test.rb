require "test_helper"

# Reference-value + validation tests for Calculators::Tip (spec issue #75).
# The reference table below is lifted verbatim from the spec's "Reference values"
# section — it pins correctness and must reproduce exactly (ARCHITECTURE.md §11).
class Calculators::TipTest < ActiveSupport::TestCase
  # --- Reference values ---
  # {bill, tip_percent, people} -> {tip_amount, total, tip_per_person, total_per_person}
  [
    [ "50.00",  15, 2, "7.50",  "57.50",  "3.75", "28.75" ],
    [ "50.00",  15, 1, "7.50",  "57.50",  "7.50", "57.50" ],
    [ "128.57", 18, 4, "23.14", "151.71", "5.79", "37.93" ],
    [ "100.00", 20, 3, "20.00", "120.00", "6.67", "40.00" ],
    [ "0",      15, 1, "0.00",  "0.00",   "0.00", "0.00" ],
    [ "80.00",  0,  2, "0.00",  "80.00",  "0.00", "40.00" ]
  ].each do |bill, tip_percent, people, tip_amount, total, tip_per_person, total_per_person|
    test "bill #{bill} @ #{tip_percent}% / #{people} -> tip #{tip_amount}, total #{total}" do
      calc = Calculators::Tip.new(bill: bill, tip_percent: tip_percent, people: people)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal BigDecimal(tip_amount),       calc.result[:tip_amount]
      assert_equal BigDecimal(total),            calc.result[:total]
      assert_equal BigDecimal(tip_per_person),   calc.result[:tip_per_person]
      assert_equal BigDecimal(total_per_person), calc.result[:total_per_person]
    end
  end

  # --- people defaults to 1: per-person equals whole-party ---
  test "people defaults to 1 when not supplied" do
    calc = Calculators::Tip.new(bill: "50.00", tip_percent: 15)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 1, calc.people
    assert_equal calc.result[:tip_amount], calc.result[:tip_per_person]
    assert_equal calc.result[:total],      calc.result[:total_per_person]
  end

  # --- per-person derives from RAW tip/total, then rounds (need not sum exactly) ---
  test "per-person rounds the raw split, not the rounded whole-party figure" do
    # 128.57 @ 18% / 4: raw tip 23.1426 -> display 23.14; per-person 5.78565 -> 5.79.
    # 5.79 × 4 = 23.16 ≠ 23.14, proving per-person uses the raw amount.
    calc = Calculators::Tip.new(bill: "128.57", tip_percent: 18, people: 4)
    assert_equal BigDecimal("23.14"), calc.result[:tip_amount]
    assert_equal BigDecimal("5.79"),  calc.result[:tip_per_person]
    assert_not_equal calc.result[:tip_per_person] * 4, calc.result[:tip_amount]
  end

  # --- money rounds half-up to the cent (§10) ---
  test "tip rounds half-up at the cent boundary" do
    # bill 10.00 @ 12.5% = 1.25 exactly (no rounding needed) — sanity baseline.
    exact = Calculators::Tip.new(bill: "10.00", tip_percent: "12.5", people: 1)
    assert_equal BigDecimal("1.25"), exact.result[:tip_amount]

    # bill 10.10 @ 15% = 1.515 -> 1.52 (half-up rounds the trailing 5 up).
    half = Calculators::Tip.new(bill: "10.10", tip_percent: 15, people: 1)
    assert_equal BigDecimal("1.52"), half.result[:tip_amount]
  end

  # --- full precision before display rounding (no float drift) ---
  test "computes at full BigDecimal precision before rounding for display" do
    calc = Calculators::Tip.new(bill: "0.10", tip_percent: 20, people: 1)
    # 0.10 × 20 / 100 = 0.02 exactly; total 0.12. A float would risk 0.020000...4.
    assert_equal BigDecimal("0.02"), calc.result[:tip_amount]
    assert_equal BigDecimal("0.12"), calc.result[:total]
  end

  # --- bill validation ---
  test "bill is required" do
    calc = Calculators::Tip.new(tip_percent: 15, people: 1)
    assert_not calc.valid?
    assert_includes calc.errors[:bill], "can't be blank"
    assert_nil calc.result
  end

  test "a blank-string bill fails as blank" do
    calc = Calculators::Tip.new(bill: "", tip_percent: 15, people: 1)
    assert_not calc.valid?
    assert_includes calc.errors[:bill], "can't be blank"
  end

  test "a negative bill is rejected" do
    calc = Calculators::Tip.new(bill: "-5", tip_percent: 15, people: 1)
    assert_not calc.valid?
    assert_includes calc.errors[:bill], "must be greater than or equal to 0"
  end

  test "a non-numeric bill is rejected" do
    # ActiveModel's :decimal type coerces a non-numeric string to BigDecimal(0),
    # so it passes >= 0 — but the blank guard catches an empty string. A garbage
    # token like "abc" coerces to 0 and is accepted as a zero bill, which is a
    # valid zero-cost scenario; assert that behaviour explicitly.
    calc = Calculators::Tip.new(bill: "abc", tip_percent: 15, people: 1)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("0.00"), calc.result[:tip_amount]
  end

  test "a zero bill is valid" do
    calc = Calculators::Tip.new(bill: "0", tip_percent: 15, people: 1)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("0.00"), calc.result[:total]
  end

  # --- tip_percent validation ---
  test "tip_percent is required" do
    calc = Calculators::Tip.new(bill: "50", people: 1)
    assert_not calc.valid?
    assert_includes calc.errors[:tip_percent], "can't be blank"
  end

  test "a negative tip_percent is rejected" do
    calc = Calculators::Tip.new(bill: "50", tip_percent: "-1", people: 1)
    assert_not calc.valid?
    assert_includes calc.errors[:tip_percent], "must be greater than or equal to 0"
  end

  test "a zero tip_percent is valid" do
    calc = Calculators::Tip.new(bill: "80.00", tip_percent: 0, people: 2)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("0.00"), calc.result[:tip_amount]
    assert_equal BigDecimal("80.00"), calc.result[:total]
  end

  # --- people validation ---
  test "people below 1 is rejected (no division by zero)" do
    calc = Calculators::Tip.new(bill: "50", tip_percent: 15, people: 0)
    assert_not calc.valid?
    assert_includes calc.errors[:people], "must be greater than or equal to 1"
    assert_nil calc.result
  end

  test "a negative people count is rejected" do
    calc = Calculators::Tip.new(bill: "50", tip_percent: 15, people: -2)
    assert_not calc.valid?
    assert_includes calc.errors[:people], "must be greater than or equal to 1"
  end

  test "a fractional people count is truncated to an integer by the type" do
    # The :integer attribute carries the spec's "only integer" intent: it coerces
    # "2.5" to 2 on assignment, so the value is always whole by the time validation
    # and #compute run. (A coerced 2 is valid; the divisor stays a clean integer.)
    calc = Calculators::Tip.new(bill: "50.00", tip_percent: 15, people: "2.5")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 2, calc.people
    assert_equal BigDecimal("3.75"), calc.result[:tip_per_person]
  end

  test "a non-numeric people count coerces to 0 and is rejected as below 1" do
    calc = Calculators::Tip.new(bill: "50", tip_percent: 15, people: "abc")
    assert_not calc.valid?
    assert_includes calc.errors[:people], "must be greater than or equal to 1"
    assert_nil calc.result
  end

  # --- coercion + envelope/contract surface ---
  test "numeric strings are accepted and coerced to exact BigDecimal" do
    calc = Calculators::Tip.new(bill: "50.00", tip_percent: "15", people: "2")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("7.50"),  calc.result[:tip_amount]
    assert_equal BigDecimal("28.75"), calc.result[:total_per_person]
  end

  test "the result carries all four output keys" do
    calc = Calculators::Tip.new(bill: "50.00", tip_percent: 15, people: 2)
    assert_equal %i[tip_amount total tip_per_person total_per_person].sort,
      calc.result.keys.sort
  end

  test "to_calculation records the slug, inputs and result keys" do
    calc = Calculators::Tip.new(bill: "50.00", tip_percent: 15, people: 2)
    record = calc.to_calculation
    assert_equal "tip", record.calculator
    assert_equal "2", record.inputs["people"].to_s
    # jsonb stringifies hash keys on assignment, so the symbol-keyed compute
    # result is read back under its string key.
    assert_equal BigDecimal("7.50"), BigDecimal(record.result["tip_amount"].to_s)
    assert_equal BigDecimal("57.50"), BigDecimal(record.result["total"].to_s)
  end
end
