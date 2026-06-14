require "test_helper"

# Reference-value + validation tests for Calculators::OhmsLaw (spec issue #54).
# The reference table below is lifted verbatim from the spec's "Reference values"
# section — it pins correctness and must reproduce exactly (ARCHITECTURE.md §11).
class Calculators::OhmsLawTest < ActiveSupport::TestCase
  # --- Reference values: every row supplies two quantities and solves all four. ---
  # [ mode, voltage, current, resistance, power => V_out, I_out, R_out, P_out ]
  [
    [ "vi", 12, 2, nil, nil, 12, 2, 6, 24 ],
    [ "vi", 9, 3, nil, nil, 9, 3, 3, 27 ],
    [ "vr", 120, nil, 60, nil, 120, 2, 60, 240 ],
    [ "vr", 12, nil, 4, nil, 12, 3, 4, 36 ],
    [ "ir", nil, 0.5, 100, nil, 50, 0.5, 100, 25 ],
    [ "ir", nil, 2, 0, nil, 0, 2, 0, 0 ],
    [ "ip", nil, 2, nil, 24, 12, 2, 6, 24 ],
    [ "vp", 12, nil, nil, 24, 12, 2, 6, 24 ],
    [ "rp", nil, nil, 4, 36, 12, 3, 4, 36 ]
  ].each do |mode, v_in, i_in, r_in, p_in, v_out, i_out, r_out, p_out|
    test "#{mode}: V=#{v_in.inspect} I=#{i_in.inspect} R=#{r_in.inspect} P=#{p_in.inspect} -> V#{v_out} I#{i_out} R#{r_out} P#{p_out}" do
      calc = Calculators::OhmsLaw.new(
        mode: mode, voltage: v_in, current: i_in, resistance: r_in, power: p_in
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal BigDecimal(v_out.to_s), calc.result[:voltage], "voltage"
      assert_equal BigDecimal(i_out.to_s), calc.result[:current], "current"
      assert_equal BigDecimal(r_out.to_s), calc.result[:resistance], "resistance"
      assert_equal BigDecimal(p_out.to_s), calc.result[:power], "power"
    end
  end

  # --- Cross-mode consistency: one circuit (12V, 2A, 6Ω, 24W) entered three
  #     ways (vi, ip, vp) must agree on the full operating point (spec note). ---
  test "vi / ip / vp agree on the same 12V/2A/6R/24P operating point" do
    by_vi = Calculators::OhmsLaw.new(mode: "vi", voltage: 12, current: 2).result
    by_ip = Calculators::OhmsLaw.new(mode: "ip", current: 2, power: 24).result
    by_vp = Calculators::OhmsLaw.new(mode: "vp", voltage: 12, power: 24).result
    [ by_ip, by_vp ].each do |other|
      assert_equal by_vi[:voltage], other[:voltage]
      assert_equal by_vi[:current], other[:current]
      assert_equal by_vi[:resistance], other[:resistance]
      assert_equal by_vi[:power], other[:power]
    end
  end

  # --- The result always carries all four V/I/R/P keys (the §4 result shape). ---
  test "result always carries all four V/I/R/P keys" do
    result = Calculators::OhmsLaw.new(mode: "vi", voltage: 12, current: 2).result
    assert_equal %i[voltage current resistance power].sort, result.keys.sort
  end

  # --- Full BigDecimal precision, including rp's irrational square root. ---
  test "computes the rp square root at full precision (irrational radicand)" do
    # I = √(10 / 3); √3.333… is irrational, so BigDecimal carries many places.
    calc = Calculators::OhmsLaw.new(mode: "rp", resistance: 3, power: 10)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    i = calc.result[:current]
    assert_in_epsilon 10.0 / 3.0, (i * i).to_f, 1e-12 # i² == P/R
    assert_operator i, :>, BigDecimal("1.8257418583")
  end

  test "rp with a perfect-square radicand stays exact" do
    calc = Calculators::OhmsLaw.new(mode: "rp", resistance: 4, power: 36)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("3"), calc.result[:current]
    assert_equal BigDecimal("12"), calc.result[:voltage]
  end

  # --- mode validation ---
  test "mode is required" do
    calc = Calculators::OhmsLaw.new(mode: nil)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "can't be blank"
    assert_nil calc.result
  end

  test "mode must be one of the six known modes" do
    calc = Calculators::OhmsLaw.new(mode: "bogus", voltage: 1, current: 2)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "is not included in the list"
    assert_nil calc.result
  end

  # --- per-mode required inputs (the two quantities the mode names) ---
  {
    "vi" => %i[voltage current],
    "vr" => %i[voltage resistance],
    "vp" => %i[voltage power],
    "ir" => %i[current resistance],
    "ip" => %i[current power],
    "rp" => %i[resistance power]
  }.each do |mode, required|
    test "#{mode} requires #{required.join(' and ')}" do
      calc = Calculators::OhmsLaw.new(mode: mode)
      assert_not calc.valid?
      required.each { |field| assert_includes calc.errors[field], "can't be blank" }
    end
  end

  test "inputs not named by the mode are ignored, not required" do
    # ir needs only current + resistance; voltage/power left blank is fine.
    calc = Calculators::OhmsLaw.new(mode: "ir", current: 2, resistance: 3)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("6"), calc.result[:voltage]
  end

  test "numeric strings are accepted and coerced to exact BigDecimal" do
    calc = Calculators::OhmsLaw.new(mode: "vi", voltage: "12", current: "2")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("6"), calc.result[:resistance]
    assert_equal BigDecimal("24"), calc.result[:power]
  end

  test "a blank-string required input fails as blank" do
    calc = Calculators::OhmsLaw.new(mode: "vi", voltage: "", current: 2)
    assert_not calc.valid?
    assert_includes calc.errors[:voltage], "can't be blank"
  end

  test "a non-numeric required input coerces to 0 (ActiveModel :decimal behavior)" do
    # ActiveModel's :decimal type coerces an unparseable string to BigDecimal(0),
    # not nil — so it passes presence. Here vi's voltage isn't a divisor, so
    # voltage = 0 is a valid circuit (R = 0/2 = 0, P = 0).
    calc = Calculators::OhmsLaw.new(mode: "vi", voltage: "lots", current: 2)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("0"), calc.result[:voltage]
    assert_equal BigDecimal("0"), calc.result[:resistance]
  end

  # --- a valid zero where there is no division ---
  test "ir with resistance = 0 is valid and yields V = 0, P = 0" do
    calc = Calculators::OhmsLaw.new(mode: "ir", current: 2, resistance: 0)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("0"), calc.result[:voltage]
    assert_equal BigDecimal("0"), calc.result[:power]
  end

  # --- division-by-zero guards: reported as validation errors, never raised ---
  [
    [ "vi", { voltage: 12, current: 0 },    :current,    "R = V / 0" ],
    [ "vr", { voltage: 12, resistance: 0 }, :resistance, "I = V / 0" ],
    [ "vp", { voltage: 0, power: 24 },       :voltage,    "I = P / 0" ],
    [ "vp", { voltage: 12, power: 0 },       :power,      "R = V² / 0" ],
    [ "ip", { current: 0, power: 24 },       :current,    "V = P / 0" ],
    [ "rp", { resistance: 0, power: 36 },    :resistance, "P / 0 under the root" ]
  ].each do |mode, inputs, field, why|
    test "#{mode} rejects #{field} = 0 (#{why})" do
      calc = Calculators::OhmsLaw.new(mode: mode, **inputs)
      assert_not calc.valid?
      assert_includes calc.errors[field], "must be other than 0"
      assert_nil calc.result
    end
  end

  # --- rp square-root domain: the radicand P/R must be >= 0 ---
  test "rp rejects a negative radicand (P / R < 0)" do
    calc = Calculators::OhmsLaw.new(mode: "rp", resistance: 4, power: -36)
    assert_not calc.valid?
    assert_includes calc.errors[:power], "must be greater than or equal to 0"
    assert_nil calc.result
  end

  test "rp accepts a zero radicand (P = 0 -> I = 0, V = 0)" do
    calc = Calculators::OhmsLaw.new(mode: "rp", resistance: 4, power: 0)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("0"), calc.result[:current]
    assert_equal BigDecimal("0"), calc.result[:voltage]
  end

  test "rp with negative resistance is reported as a zero/division failure, not a radicand sign" do
    # resistance < 0 isn't zero, so it passes the division guard; the radicand
    # P/R is then negative and is the failure that surfaces.
    calc = Calculators::OhmsLaw.new(mode: "rp", resistance: -4, power: 36)
    assert_not calc.valid?
    assert_includes calc.errors[:power], "must be greater than or equal to 0"
  end

  # --- envelope/contract surface ---
  test "to_calculation records the slug, inputs and the full result set" do
    calc = Calculators::OhmsLaw.new(mode: "vi", voltage: 12, current: 2)
    record = calc.to_calculation
    assert_equal "ohms_law", record.calculator
    assert_equal "vi", record.inputs["mode"]
    # jsonb stringifies hash keys on assignment.
    assert_equal BigDecimal("6"), BigDecimal(record.result["resistance"].to_s)
    assert_equal BigDecimal("24"), BigDecimal(record.result["power"].to_s)
  end
end
