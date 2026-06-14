require "test_helper"
require_relative "../support/calculators"

# Unit tests for the calculator contract (Calculators::Base). The concrete-calculator
# behaviour is driven through Calculators::TestDouble (test/support/calculators.rb).
class Calculators::BaseTest < ActiveSupport::TestCase
  test "slug demodulizes and underscores the class name" do
    assert_equal "test_double", Calculators::TestDouble.slug
  end

  test "lookup resolves a known slug to its class" do
    assert_equal Calculators::TestDouble, Calculators::Base.lookup("test_double")
  end

  test "lookup returns nil for an unknown slug" do
    assert_nil Calculators::Base.lookup("no_such_calculator")
  end

  test "result computes when valid and is memoized" do
    calc = Calculators::TestDouble.new(x: 3)
    assert_equal({ doubled: 6 }, calc.result)
    assert_same calc.result, calc.result
  end

  test "result is nil when invalid (compute is skipped)" do
    assert_nil Calculators::TestDouble.new(x: nil).result
  end

  test "to_calculation builds an unsaved Calculation with slug, inputs, and result" do
    calc = Calculators::TestDouble.new(x: 4)
    record = calc.to_calculation

    assert_not record.persisted?
    assert_equal "test_double", record.calculator
    assert_equal BigDecimal("4"), BigDecimal(record.inputs["x"].to_s)
    assert_equal BigDecimal("8"), BigDecimal(record.result["doubled"].to_s)
    assert_nil record.user
  end

  test "compute is abstract on Base itself" do
    assert_raises(NotImplementedError) { Calculators::Base.new.result }
  end

  # --- numeric coercion guard (#109, #110) -----------------------------------
  # The :decimal cast turns "abc" into BigDecimal(0) and the :integer cast
  # truncates "2.5" to 2 — both BEFORE validation — so a plain numericality check
  # is defeated. Base captures the RAW value and rejects bad input itself.

  test "a non-numeric decimal raw value is rejected (not coerced to 0)" do
    calc = Calculators::NumericGuardDouble.new(amount: "abc", count: 1)
    assert_not calc.valid?
    assert_includes calc.errors[:amount], "is not a number"
    assert_nil calc.result
  end

  test "a non-numeric integer raw value is rejected (not coerced to 0)" do
    calc = Calculators::NumericGuardDouble.new(amount: 1, count: "abc")
    assert_not calc.valid?
    assert_includes calc.errors[:count], "is not a number"
  end

  test "a fractional integer raw value is rejected (not truncated)" do
    calc = Calculators::NumericGuardDouble.new(amount: 1, count: "2.5")
    assert_not calc.valid?
    assert_includes calc.errors[:count], "must be a whole number"
  end

  test "a whole-number integer raw value passes the guard" do
    # "2", "2.0" and "2." are all whole numbers — accepted; the cast yields 2.
    %w[2 2.0 2.].each do |whole|
      calc = Calculators::NumericGuardDouble.new(amount: 1, count: whole)
      assert calc.valid?, "expected count=#{whole.inspect} to pass: #{calc.errors.full_messages}"
      assert_equal 2, calc.count
    end
  end

  test "valid numeric strings (including signed and bare-fractional) pass the guard" do
    calc = Calculators::NumericGuardDouble.new(amount: "-.5", count: "-3")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("-0.5"), calc.amount
    assert_equal(-3, calc.count)
  end

  test "blank or omitted numeric input is left to the calculator's own presence rules" do
    # The guard skips nil, an empty string, and an all-whitespace string — it never
    # reports those as "not a number" (presence validations own missing input).
    [ nil, "", "   " ].each do |blank|
      calc = Calculators::NumericGuardDouble.new(amount: blank, count: blank)
      assert calc.valid?, "expected blank #{blank.inspect} to raise no guard error: #{calc.errors.full_messages}"
    end
  end

  test "a non-numeric value in a non-numeric (string) attribute is untouched" do
    # The guard only inspects :decimal / :integer attributes — a :string attribute
    # carries arbitrary text, exercising the non-numeric branch of raw capture.
    calc = Calculators::NumericGuardDouble.new(amount: 1, count: 1, label: "hello")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "hello", calc.label
  end
end
