require "test_helper"

# Reference-value + validation tests for Calculators::RightTriangle (spec issue
# #192). The reference table below is lifted verbatim from the spec's "Reference
# values" section — it pins correctness and must reproduce exactly (§11). Outputs are
# fixed six-decimal-place strings (spec Notes).
class Calculators::RightTriangleTest < ActiveSupport::TestCase
  # --- Reference values: each row supplies two sides and solves everything. ---
  # [ mode, a, b, c => a_out, b_out, c_out, alpha, beta, area, perimeter, altitude ]
  [
    [ "legs",    3, 4,  nil, "3.000000", "4.000000", "5.000000",  "36.869898", "53.130102", "6.000000",  "12.000000", "2.400000" ],
    [ "legs",    5, 12, nil, "5.000000", "12.000000", "13.000000", "22.619865", "67.380135", "30.000000", "30.000000", "4.615385" ],
    [ "legs",    1, 1,  nil, "1.000000", "1.000000", "1.414214",  "45.000000", "45.000000", "0.500000",  "3.414214",  "0.707107" ],
    [ "leg_hyp", 6, nil, 10, "6.000000", "8.000000", "10.000000", "36.869898", "53.130102", "24.000000", "24.000000", "4.800000" ]
  ].each do |mode, a, b, c, a_out, b_out, c_out, alpha, beta, area, perimeter, altitude|
    test "#{mode}: a=#{a.inspect} b=#{b.inspect} c=#{c.inspect} solves the full triangle" do
      calc = Calculators::RightTriangle.new(mode: mode, a: a, b: b, c: c)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result
      assert_equal mode,      result[:mode]
      assert_equal a_out,     result[:a],         "a"
      assert_equal b_out,     result[:b],         "b"
      assert_equal c_out,     result[:c],         "c"
      assert_equal alpha,     result[:alpha],     "alpha"
      assert_equal beta,      result[:beta],      "beta"
      assert_equal area,      result[:area],      "area"
      assert_equal perimeter, result[:perimeter], "perimeter"
      assert_equal altitude,  result[:altitude],  "altitude"
    end
  end

  # --- The result always carries the full spec output key set (§4 shape). ---
  test "result carries exactly the spec output keys" do
    result = Calculators::RightTriangle.new(mode: "legs", a: 3, b: 4).result
    assert_equal %i[a alpha altitude area b beta c mode perimeter].sort, result.keys.sort
  end

  # --- α + β must equal 90° (spec invariant). ---
  test "alpha + beta equal 90 degrees" do
    result = Calculators::RightTriangle.new(mode: "legs", a: 7, b: 11).result
    assert_equal BigDecimal("90"),
      BigDecimal(result[:alpha]) + BigDecimal(result[:beta])
  end

  # --- legs and leg_hyp agree on the same 6-8-10 triangle (cross-mode). ---
  test "legs and leg_hyp describe the same 6-8-10 triangle identically" do
    by_legs    = Calculators::RightTriangle.new(mode: "legs", a: 6, b: 8).result
    by_leg_hyp = Calculators::RightTriangle.new(mode: "leg_hyp", a: 6, c: 10).result
    %i[a b c alpha beta area perimeter altitude].each do |key|
      assert_equal by_legs[key], by_leg_hyp[key], key.to_s
    end
  end

  # --- every output is a fixed six-decimal-place string ---
  test "outputs are fixed six-decimal-place strings, trailing zeros padded" do
    result = Calculators::RightTriangle.new(mode: "legs", a: 3, b: 4).result
    %i[a b c alpha beta area perimeter altitude].each do |key|
      assert_match(/\A\d+\.\d{6}\z/, result[key], key.to_s)
    end
  end

  # --- mode validation ---
  test "mode is required" do
    calc = Calculators::RightTriangle.new(mode: nil, a: 3, b: 4)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "can't be blank"
    assert_nil calc.result
  end

  test "mode must be one of the known modes" do
    calc = Calculators::RightTriangle.new(mode: "xyz", a: 3, b: 4)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "is not included in the list"
    assert_nil calc.result
  end

  # --- leg a is required and positive in both modes ---
  test "a is required" do
    calc = Calculators::RightTriangle.new(mode: "legs", b: 4)
    assert_not calc.valid?
    assert_includes calc.errors[:a], "can't be blank"
  end

  test "a must be greater than 0 (legs mode)" do
    calc = Calculators::RightTriangle.new(mode: "legs", a: 0, b: 4)
    assert_not calc.valid?
    assert_includes calc.errors[:a], "must be greater than 0"
    assert_nil calc.result
  end

  test "a must be greater than 0 (leg_hyp mode)" do
    calc = Calculators::RightTriangle.new(mode: "leg_hyp", a: 0, c: 10)
    assert_not calc.valid?
    assert_includes calc.errors[:a], "must be greater than 0"
  end

  # --- per-mode required second side ---
  test "b is required in legs mode" do
    calc = Calculators::RightTriangle.new(mode: "legs", a: 3)
    assert_not calc.valid?
    assert_includes calc.errors[:b], "can't be blank"
    assert_nil calc.result
  end

  test "c is required in leg_hyp mode" do
    calc = Calculators::RightTriangle.new(mode: "leg_hyp", a: 6)
    assert_not calc.valid?
    assert_includes calc.errors[:c], "can't be blank"
    assert_nil calc.result
  end

  test "b must be greater than 0 in legs mode" do
    calc = Calculators::RightTriangle.new(mode: "legs", a: 3, b: 0)
    assert_not calc.valid?
    assert_includes calc.errors[:b], "must be greater than 0"
  end

  test "c must be greater than 0 in leg_hyp mode" do
    calc = Calculators::RightTriangle.new(mode: "leg_hyp", a: 6, c: 0)
    assert_not calc.valid?
    assert_includes calc.errors[:c], "must be greater than 0"
  end

  test "the side not named by the mode is ignored, not required" do
    # legs needs only a + b; a blank c is fine.
    legs = Calculators::RightTriangle.new(mode: "legs", a: 3, b: 4)
    assert legs.valid?, legs.errors.full_messages.to_sentence
    # leg_hyp needs only a + c; a blank b is fine.
    leg_hyp = Calculators::RightTriangle.new(mode: "leg_hyp", a: 6, c: 10)
    assert leg_hyp.valid?, leg_hyp.errors.full_messages.to_sentence
  end

  # --- leg_hyp: hypotenuse must be strictly greater than the leg ---
  test "leg_hyp rejects a hypotenuse equal to the leg" do
    calc = Calculators::RightTriangle.new(mode: "leg_hyp", a: 5, c: 5)
    assert_not calc.valid?
    assert_includes calc.errors[:c], "must be greater than leg a"
    assert_nil calc.result
  end

  test "leg_hyp rejects a hypotenuse smaller than the leg" do
    calc = Calculators::RightTriangle.new(mode: "leg_hyp", a: 8, c: 6)
    assert_not calc.valid?
    assert_includes calc.errors[:c], "must be greater than leg a"
    assert_nil calc.result
  end

  # --- Base numeric coercion guard (#110) on a string side ---
  test "a non-numeric side is rejected by the Base coercion guard" do
    calc = Calculators::RightTriangle.new(mode: "legs", a: "x", b: 4)
    assert_not calc.valid?
    assert_includes calc.errors[:a], "is not a number"
    assert_nil calc.result
  end

  # --- numeric strings coerce to exact BigDecimal and solve correctly ---
  test "numeric-string sides are accepted and solved" do
    calc = Calculators::RightTriangle.new(mode: "legs", a: "3", b: "4")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "5.000000", calc.result[:c]
  end

  # --- envelope/contract surface ---
  test "to_calculation records the slug, inputs and the full result set" do
    calc = Calculators::RightTriangle.new(mode: "legs", a: 3, b: 4)
    record = calc.to_calculation
    assert_equal "right_triangle", record.calculator
    assert_equal "legs", record.inputs["mode"]
    # jsonb stringifies hash keys on assignment.
    assert_equal "5.000000", record.result["c"]
  end
end
