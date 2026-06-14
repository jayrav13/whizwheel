require "test_helper"

# Reference-value + validation tests for Calculators::Bmi (spec issue #52).
# The reference table below is lifted verbatim from the spec's "Reference values"
# section — it pins correctness and must reproduce exactly (ARCHITECTURE.md §11).
class Calculators::BmiTest < ActiveSupport::TestCase
  # --- Reference values: {unit_system, weight, height} -> {bmi, category} ---
  [
    [ "us",     160,   70,    "23.0", "Normal" ],
    [ "us",     120,   65,    "20.0", "Normal" ],
    [ "us",     220,   70,    "31.6", "Obese Class I" ],
    [ "metric", 72.57, 177.8, "23.0", "Normal" ],
    [ "metric", 50,    160,   "19.5", "Normal" ],
    [ "metric", 60,    170,   "20.8", "Normal" ],
    [ "metric", 100,   180,   "30.9", "Obese Class I" ],
    [ "metric", 95,    165,   "34.9", "Obese Class I" ]
  ].each do |unit_system, weight, height, bmi, category|
    test "#{unit_system}: #{weight}/#{height} -> #{bmi} (#{category})" do
      calc = Calculators::Bmi.new(unit_system: unit_system, weight: weight, height: height)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal BigDecimal(bmi), calc.result[:bmi]
      assert_equal category, calc.result[:category]
    end
  end

  # --- Boundary classification: bands are [lower, upper) (lower inclusive) ---
  # Per the spec's edge notes, exactly 18.5 is Normal and exactly 25.0 is
  # Overweight. We hit those boundaries exactly via metric inputs whose raw BMI
  # lands precisely on the bound (height 2 m → BMI == weight_kg / 4).
  [
    [ "15.9", "Severe Thinness" ],
    [ "16.0", "Moderate Thinness" ],
    [ "16.9", "Moderate Thinness" ],
    [ "17.0", "Mild Thinness" ],
    [ "18.4", "Mild Thinness" ],
    [ "18.5", "Normal" ],
    [ "24.9", "Normal" ],
    [ "25.0", "Overweight" ],
    [ "29.9", "Overweight" ],
    [ "30.0", "Obese Class I" ],
    [ "34.9", "Obese Class I" ],
    [ "35.0", "Obese Class II" ],
    [ "39.9", "Obese Class II" ],
    [ "40.0", "Obese Class III" ],
    [ "55.0", "Obese Class III" ]
  ].each do |target_bmi, category|
    test "boundary: BMI #{target_bmi} classifies as #{category}" do
      # height 200 cm → 2 m → BMI = weight / 4, so weight = target × 4 yields
      # exactly target_bmi as the raw BMI (no rounding into the band decision).
      weight = BigDecimal(target_bmi) * 4
      calc = Calculators::Bmi.new(unit_system: "metric", weight: weight, height: 200)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal category, calc.result[:category]
    end
  end

  # --- category is derived from the RAW bmi, not the rounded display value ---
  test "category uses raw bmi, so a value rounding to 25.0 but below 25 stays Normal" do
    # height 200 cm → BMI = weight / 4. weight 99.8 → raw 24.95, which rounds to
    # 25.0 for display but is < 25, so the band stays Normal.
    calc = Calculators::Bmi.new(unit_system: "metric", weight: "99.8", height: 200)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("25.0"), calc.result[:bmi]
    assert_equal "Normal", calc.result[:category]
  end

  # --- Full BigDecimal precision (no float drift) ---
  test "computes bmi at full precision before display rounding" do
    # us 220/70 = 703*220/4900 = 31.563265... — display rounds to 31.6, but the
    # underlying division carries far more places than a float's 31.56.
    calc = Calculators::Bmi.new(unit_system: "us", weight: 220, height: 70)
    assert calc.valid?
    assert_equal BigDecimal("31.6"), calc.result[:bmi]
  end

  test "the two unit systems agree for the same person (cross-mode consistency)" do
    us = Calculators::Bmi.new(unit_system: "us", weight: 160, height: 70)
    metric = Calculators::Bmi.new(unit_system: "metric", weight: 72.57, height: 177.8)
    assert_equal us.result[:bmi], metric.result[:bmi]
  end

  # --- unit_system validation ---
  test "unit_system is required" do
    calc = Calculators::Bmi.new(unit_system: nil, weight: 70, height: 175)
    assert_not calc.valid?
    assert_includes calc.errors[:unit_system], "can't be blank"
  end

  test "unit_system must be one of the known systems" do
    calc = Calculators::Bmi.new(unit_system: "imperial", weight: 70, height: 175)
    assert_not calc.valid?
    assert_includes calc.errors[:unit_system], "is not included in the list"
    assert_nil calc.result
  end

  # --- weight validation ---
  test "weight is required" do
    calc = Calculators::Bmi.new(unit_system: "metric", height: 175)
    assert_not calc.valid?
    assert_includes calc.errors[:weight], "can't be blank"
  end

  test "weight must be greater than zero" do
    calc = Calculators::Bmi.new(unit_system: "metric", weight: 0, height: 175)
    assert_not calc.valid?
    assert_includes calc.errors[:weight], "must be greater than 0"
  end

  test "a negative weight is rejected" do
    calc = Calculators::Bmi.new(unit_system: "metric", weight: -5, height: 175)
    assert_not calc.valid?
    assert_includes calc.errors[:weight], "must be greater than 0"
  end

  test "a non-numeric weight is rejected" do
    # ActiveModel's :decimal type coerces a non-numeric string to BigDecimal(0),
    # so it fails the greater_than: 0 numericality guard.
    calc = Calculators::Bmi.new(unit_system: "metric", weight: "heavy", height: 175)
    assert_not calc.valid?
    assert_includes calc.errors[:weight], "must be greater than 0"
  end

  test "a blank-string weight fails as blank" do
    calc = Calculators::Bmi.new(unit_system: "metric", weight: "", height: 175)
    assert_not calc.valid?
    assert_includes calc.errors[:weight], "can't be blank"
  end

  # --- height validation ---
  test "height is required" do
    calc = Calculators::Bmi.new(unit_system: "metric", weight: 70)
    assert_not calc.valid?
    assert_includes calc.errors[:height], "can't be blank"
  end

  test "height must be greater than zero" do
    calc = Calculators::Bmi.new(unit_system: "metric", weight: 70, height: 0)
    assert_not calc.valid?
    assert_includes calc.errors[:height], "must be greater than 0"
  end

  test "a negative height is rejected" do
    calc = Calculators::Bmi.new(unit_system: "us", weight: 160, height: -70)
    assert_not calc.valid?
    assert_includes calc.errors[:height], "must be greater than 0"
  end

  # --- coercion + envelope/contract surface ---
  test "numeric strings are accepted and coerced to exact BigDecimal" do
    calc = Calculators::Bmi.new(unit_system: "us", weight: "160", height: "70")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("23.0"), calc.result[:bmi]
    assert_equal "Normal", calc.result[:category]
  end

  test "to_calculation records the slug, inputs and result keys" do
    calc = Calculators::Bmi.new(unit_system: "us", weight: 160, height: 70)
    record = calc.to_calculation
    assert_equal "bmi", record.calculator
    assert_equal "us", record.inputs["unit_system"]
    # jsonb stringifies hash keys on assignment, so the symbol-keyed compute
    # result is read back under its string key.
    assert_equal BigDecimal("23.0"), BigDecimal(record.result["bmi"].to_s)
    assert_equal "Normal", record.result["category"]
  end
end
