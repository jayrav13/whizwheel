require "test_helper"

# Reference-value + validation tests for Calculators::PythagoreanTheorem (spec issue
# #243). The reference table below is lifted verbatim from the spec's "Reference
# values" section — it pins correctness and must reproduce exactly (§11). Sides are
# displayed as fixed six-decimal-place strings, half-up (spec Notes).
class Calculators::PythagoreanTheoremTest < ActiveSupport::TestCase
  # --- Reference values: each row gives two sides and solves for the third. ---
  # [ mode, a, b, c => a_out, b_out, c_out ]
  # (the side the mode SOLVES FOR is supplied as nil; the spec's table shows the
  #  solved value in the corresponding output column.)
  [
    [ "hypotenuse", 3, 4,   nil, "3.000000",  "4.000000",  "5.000000" ],
    [ "hypotenuse", 5, 12,  nil, "5.000000",  "12.000000", "13.000000" ],
    [ "hypotenuse", 8, 15,  nil, "8.000000",  "15.000000", "17.000000" ],
    [ "hypotenuse", 1, 1,   nil, "1.000000",  "1.000000",  "1.414214" ],
    [ "leg",        5, nil, 13,  "5.000000",  "12.000000", "13.000000" ],
    [ "leg",        6, nil, 10,  "6.000000",  "8.000000",  "10.000000" ]
  ].each do |mode, a, b, c, a_out, b_out, c_out|
    test "#{mode}: a=#{a.inspect} b=#{b.inspect} c=#{c.inspect} solves the third side" do
      calc = Calculators::PythagoreanTheorem.new(mode: mode, a: a, b: b, c: c)
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result
      assert_equal mode,  result[:mode]
      assert_equal a_out, result[:a], "a"
      assert_equal b_out, result[:b], "b"
      assert_equal c_out, result[:c], "c"
    end
  end

  # --- The result always carries exactly the spec output key set (§4 shape). ---
  test "result carries exactly the spec output keys" do
    result = Calculators::PythagoreanTheorem.new(mode: "hypotenuse", a: 3, b: 4).result
    assert_equal %i[a b c mode].sort, result.keys.sort
  end

  # --- every output side is a fixed six-decimal-place string ---
  test "side outputs are fixed six-decimal-place strings, trailing zeros padded" do
    result = Calculators::PythagoreanTheorem.new(mode: "hypotenuse", a: 3, b: 4).result
    %i[a b c].each do |key|
      assert_match(/\A\d+\.\d{6}\z/, result[key], key.to_s)
    end
  end

  # --- hypotenuse and leg modes agree on the same 5-12-13 triangle (cross-mode). ---
  test "hypotenuse and leg modes describe the same 5-12-13 triangle identically" do
    by_hyp = Calculators::PythagoreanTheorem.new(mode: "hypotenuse", a: 5, b: 12).result
    by_leg = Calculators::PythagoreanTheorem.new(mode: "leg", a: 5, c: 13).result
    %i[a b c].each do |key|
      assert_equal by_hyp[key], by_leg[key], key.to_s
    end
  end

  # --- mode validation ---
  test "mode is required" do
    calc = Calculators::PythagoreanTheorem.new(mode: nil, a: 3, b: 4)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "can't be blank"
    assert_nil calc.result
  end

  test "mode must be one of the known modes" do
    calc = Calculators::PythagoreanTheorem.new(mode: "xyz", a: 3, b: 4)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "is not included in the list"
    assert_nil calc.result
  end

  # --- leg a is required and positive in both modes ---
  test "a is required" do
    calc = Calculators::PythagoreanTheorem.new(mode: "hypotenuse", b: 4)
    assert_not calc.valid?
    assert_includes calc.errors[:a], "can't be blank"
  end

  test "a must be greater than 0 (hypotenuse mode)" do
    calc = Calculators::PythagoreanTheorem.new(mode: "hypotenuse", a: 0, b: 4)
    assert_not calc.valid?
    assert_includes calc.errors[:a], "must be greater than 0"
    assert_nil calc.result
  end

  test "a must be greater than 0 (leg mode)" do
    calc = Calculators::PythagoreanTheorem.new(mode: "leg", a: 0, c: 10)
    assert_not calc.valid?
    assert_includes calc.errors[:a], "must be greater than 0"
  end

  # --- per-mode required second side ---
  test "b is required in hypotenuse mode" do
    calc = Calculators::PythagoreanTheorem.new(mode: "hypotenuse", a: 3)
    assert_not calc.valid?
    assert_includes calc.errors[:b], "can't be blank"
    assert_nil calc.result
  end

  test "c is required in leg mode" do
    calc = Calculators::PythagoreanTheorem.new(mode: "leg", a: 6)
    assert_not calc.valid?
    assert_includes calc.errors[:c], "can't be blank"
    assert_nil calc.result
  end

  test "b must be greater than 0 in hypotenuse mode" do
    calc = Calculators::PythagoreanTheorem.new(mode: "hypotenuse", a: 3, b: 0)
    assert_not calc.valid?
    assert_includes calc.errors[:b], "must be greater than 0"
  end

  test "c must be greater than 0 in leg mode" do
    calc = Calculators::PythagoreanTheorem.new(mode: "leg", a: 6, c: 0)
    assert_not calc.valid?
    assert_includes calc.errors[:c], "must be greater than 0"
  end

  test "the side not named by the mode is ignored, not required" do
    # hypotenuse needs only a + b; a blank c is fine.
    hyp = Calculators::PythagoreanTheorem.new(mode: "hypotenuse", a: 3, b: 4)
    assert hyp.valid?, hyp.errors.full_messages.to_sentence
    # leg needs only a + c; a blank b is fine.
    leg = Calculators::PythagoreanTheorem.new(mode: "leg", a: 6, c: 10)
    assert leg.valid?, leg.errors.full_messages.to_sentence
  end

  # --- leg mode: hypotenuse must be strictly greater than the leg ---
  test "leg mode rejects a hypotenuse equal to the leg" do
    calc = Calculators::PythagoreanTheorem.new(mode: "leg", a: 5, c: 5)
    assert_not calc.valid?
    assert_includes calc.errors[:c], "must be greater than leg a"
    assert_nil calc.result
  end

  test "leg mode rejects a hypotenuse smaller than the leg" do
    calc = Calculators::PythagoreanTheorem.new(mode: "leg", a: 8, c: 6)
    assert_not calc.valid?
    assert_includes calc.errors[:c], "must be greater than leg a"
    assert_nil calc.result
  end

  # --- Base numeric coercion guard (#110) on a string side ---
  test "a non-numeric side is rejected by the Base coercion guard" do
    calc = Calculators::PythagoreanTheorem.new(mode: "hypotenuse", a: "x", b: 4)
    assert_not calc.valid?
    assert_includes calc.errors[:a], "is not a number"
    assert_nil calc.result
  end

  # --- numeric strings coerce to exact BigDecimal and solve correctly ---
  test "numeric-string sides are accepted and solved" do
    calc = Calculators::PythagoreanTheorem.new(mode: "hypotenuse", a: "3", b: "4")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "5.000000", calc.result[:c]
  end

  # --- envelope/contract surface ---
  test "to_calculation records the slug, inputs and the full result set" do
    calc = Calculators::PythagoreanTheorem.new(mode: "hypotenuse", a: 3, b: 4)
    record = calc.to_calculation
    assert_equal "pythagorean_theorem", record.calculator
    assert_equal "hypotenuse", record.inputs["mode"]
    # jsonb stringifies hash keys on assignment.
    assert_equal "5.000000", record.result["c"]
  end
end
