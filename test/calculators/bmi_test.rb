require "test_helper"

# Reference-value + validation tests for Calculators::Bmi (spec issue #52).
# The reference table is lifted verbatim from the spec's "Reference values"
# section — it pins correctness and must reproduce exactly (ARCHITECTURE.md §11).
class Calculators::BmiTest < ActiveSupport::TestCase
  # --- Reference values: {unit_system, weight, height} -> {bmi, category} ---
  # bmi is the display value (1 dp); category is the WHO band for the raw BMI.
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
    test "#{unit_system}: #{weight} / #{height} -> bmi #{bmi}, #{category}" do
      calc = Calculators::Bmi.new(unit_system: unit_system, weight: weight, height: height)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal BigDecimal(bmi), calc.result[:bmi]
      assert_equal category, calc.result[:category]
    end
  end

  # --- The default-example cross-mode consistency check (spec edge note) ---
  # 160 lb / 70 in and 72.57 kg / 177.8 cm are the same person; both yield 23.0.
  test "us and metric agree for the same person at the default example" do
    us     = Calculators::Bmi.new(unit_system: "us", weight: 160, height: 70)
    metric = Calculators::Bmi.new(unit_system: "metric", weight: 72.57, height: 177.8)
    assert_equal BigDecimal("23.0"), us.result[:bmi]
    assert_equal BigDecimal("23.0"), metric.result[:bmi]
  end

  # --- Full BigDecimal precision before display rounding ---
  test "bmi is computed at full precision and only rounded for display" do
    # us 220/70 = 703 × 220 / 4900 = 31.563265...  display rounds to 31.6, but the
    # underlying division carries far more places than a float's 31.56.
    calc = Calculators::Bmi.new(unit_system: "us", weight: 220, height: 70)
    assert calc.valid?
    assert_equal BigDecimal("31.6"), calc.result[:bmi]
    assert calc.result[:bmi].is_a?(BigDecimal)
  end

  # --- WHO band boundaries: [lower, upper), lower inclusive / upper exclusive ---
  # height 200 cm = 2 m, so raw BMI = weight_kg / 4; weight = target × 4 lands the
  # raw BMI exactly on the bound (no rounding into the band decision). This drives
  # the classifier across every band edge, including the spec's 18.5 and 25.0 notes.
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
    test "boundary: raw BMI #{target_bmi} classifies as #{category}" do
      weight = BigDecimal(target_bmi) * 4
      calc = Calculators::Bmi.new(unit_system: "metric", weight: weight, height: 200)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal category, calc.result[:category]
    end
  end

  # --- category is derived from the RAW bmi, not the rounded display value ---
  test "category uses the raw bmi, so 24.95 (displays 25.0) stays Normal" do
    # height 200 cm → raw BMI = weight / 4. weight 99.8 → raw 24.95: displays as
    # 25.0 but is < 25, so the band must stay Normal.
    calc = Calculators::Bmi.new(unit_system: "metric", weight: "99.8", height: 200)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("25.0"), calc.result[:bmi]
    assert_equal "Normal", calc.result[:category]
  end

  # --- unit_system validation ---
  test "unit_system is required" do
    calc = Calculators::Bmi.new(unit_system: nil, weight: 70, height: 175)
    assert_not calc.valid?
    assert_includes calc.errors[:unit_system], "can't be blank"
    assert_nil calc.result
  end

  test "unit_system must be one of the known systems" do
    calc = Calculators::Bmi.new(unit_system: "imperial", weight: 70, height: 175)
    assert_not calc.valid?
    assert_includes calc.errors[:unit_system], "is not included in the list"
    assert_nil calc.result
  end

  # --- weight validation (presence; numericality greater_than: 0) ---
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
    calc = Calculators::Bmi.new(unit_system: "us", weight: -5, height: 70)
    assert_not calc.valid?
    assert_includes calc.errors[:weight], "must be greater than 0"
  end

  test "a blank-string weight fails as blank" do
    calc = Calculators::Bmi.new(unit_system: "metric", weight: "", height: 175)
    assert_not calc.valid?
    assert_includes calc.errors[:weight], "can't be blank"
  end

  # --- height validation (presence; numericality greater_than: 0) ---
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
