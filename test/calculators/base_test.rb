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

  # --- scientific notation is ACCEPTED and casts losslessly (#109 over-narrowing) ---
  # The earlier regex-based guard wrongly rejected "1e6"/"2.5e2"/"1E3" — valid forms
  # BigDecimal parses and ActiveModel accepted before the guard existed. Parse-based
  # validation accepts exactly what casting accepts losslessly.

  test "scientific-notation decimal input is accepted and cast exactly" do
    {
      "1e6" => BigDecimal("1000000"),
      "2.5e2" => BigDecimal("250"),
      "1E3" => BigDecimal("1000"),
      "-1.5e-2" => BigDecimal("-0.015")
    }.each do |raw, expected|
      calc = Calculators::NumericGuardDouble.new(amount: raw, count: 1)
      assert calc.valid?, "expected amount=#{raw.inspect} to pass: #{calc.errors.full_messages}"
      assert_equal expected, calc.amount, "amount=#{raw.inspect} cast wrong"
    end
  end

  test "whole scientific-notation integer input is accepted and cast losslessly (not truncated)" do
    # The stock :integer cast turns "2e3" into 2 (String#to_i stops at the "e"); the
    # guarded type routes through BigDecimal so "2e3" → 2000 and "2.5e2" → 250.
    { "2e3" => 2000, "2.5e2" => 250, "1E3" => 1000 }.each do |raw, expected|
      calc = Calculators::NumericGuardDouble.new(amount: 1, count: raw)
      assert calc.valid?, "expected count=#{raw.inspect} to pass: #{calc.errors.full_messages}"
      assert_equal expected, calc.count, "count=#{raw.inspect} cast wrong"
    end
  end

  test "a fractional scientific-notation integer is still rejected as not whole" do
    # "2.55e1" == 25.5 — a number, but not a whole one → the whole-number error.
    calc = Calculators::NumericGuardDouble.new(amount: 1, count: "2.55e1")
    assert_not calc.valid?
    assert_includes calc.errors[:count], "must be a whole number"
  end

  test "garbage that looks number-ish is still rejected" do
    %w[Infinity NaN 0x10 1.2.3].each do |garbage|
      calc = Calculators::NumericGuardDouble.new(amount: garbage, count: 1)
      assert_not calc.valid?, "expected amount=#{garbage.inspect} to be rejected"
      assert_includes calc.errors[:amount], "is not a number"
    end
  end

  test "a non-blank raw value that is neither String nor Numeric is rejected" do
    # A Symbol/Array assigned to a numeric attribute is not blank, not a number, and
    # not a string — the guard rejects it as "is not a number" rather than coercing.
    [ :foo, [ 1, 2 ] ].each do |weird|
      calc = Calculators::NumericGuardDouble.new(amount: weird, count: 1)
      assert_not calc.valid?, "expected amount=#{weird.inspect} to be rejected"
      assert_includes calc.errors[:amount], "is not a number"
    end
  end

  # --- already-Numeric / BigDecimal raw values are valid by construction (#low) ---

  test "a raw value that is already Numeric or BigDecimal passes the guard" do
    calc = Calculators::NumericGuardDouble.new(amount: BigDecimal("2.5"), count: 7)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("2.5"), calc.amount
    assert_equal 7, calc.count

    # A Float decimal raw, and an Integer integer raw, both valid by construction.
    calc2 = Calculators::NumericGuardDouble.new(amount: 1.5, count: 4)
    assert calc2.valid?, calc2.errors.full_messages.to_sentence
  end

  test "a non-whole Numeric raw value for an integer attribute is rejected" do
    # BigDecimal("2.5") is a number but not whole — rejected by the integer guard,
    # exercising the Numeric-raw path of the whole-number check.
    calc = Calculators::NumericGuardDouble.new(amount: 1, count: BigDecimal("2.5"))
    assert_not calc.valid?
    assert_includes calc.errors[:count], "must be a whole number"
  end

  # --- the guard is assignment-path-independent (#medium: writer-bypass) ----------
  # Raw capture happens at the cast seam (#_write_attribute), not in assign_attributes,
  # so the per-attribute writer path is guarded too — and a corrective writer clears
  # the captured raw rather than leaving a stale false 422.

  test "the per-attribute writer path is guarded (not just .new / assign_attributes)" do
    calc = Calculators::NumericGuardDouble.new(amount: 1, count: 1)
    assert calc.valid?

    calc.amount = "abc"
    assert_not calc.valid?, "writer-assigned garbage must be guarded"
    assert_includes calc.errors[:amount], "is not a number"

    calc.count = "2.5"
    assert_not calc.valid?
    assert_includes calc.errors[:count], "must be a whole number"
  end

  test "a corrective writer assignment clears a stale raw (no false 422)" do
    calc = Calculators::NumericGuardDouble.new(amount: "abc", count: 1)
    assert_not calc.valid?

    calc.amount = "10"
    assert calc.valid?, "a corrective writer must clear the prior bad raw: #{calc.errors.full_messages}"
    assert_equal BigDecimal("10"), calc.amount
  end

  test "update assigns through the guard too" do
    calc = Calculators::NumericGuardDouble.new(amount: 1, count: 1)
    calc.assign_attributes(amount: "xyz")
    assert_not calc.valid?
    assert_includes calc.errors[:amount], "is not a number"
  end

  # --- a blank string defeats `default:` (#213) ----------------------------------
  # ActiveModel applies a `default:` only when the key is ABSENT; a submitted empty
  # string casts to nil instead, so an optional defaulted numeric reaches #compute as
  # nil and crashes (nil * 12 → 500). Base coerces a blank value on a DEFAULTED numeric
  # to its declared default at the cast seam, so #compute never sees nil.

  test "an absent defaulted numeric attribute keeps ActiveModel's native default" do
    # The baseline: when the key is omitted entirely, the default still applies.
    calc = Calculators::DefaultedNumericDouble.new(required_amount: 5)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 3, calc.offset
    assert_equal BigDecimal("2"), calc.factor
    assert_equal BigDecimal("46"), calc.result[:total] # 5*2 + 3*12
  end

  test "a blank string on a defaulted numeric is coerced to the default (no 500)" do
    # The bug: each blank optional field would cast to nil and crash #compute. Each
    # blank form (empty string, whitespace, explicit nil) must yield the default.
    [ "", "   ", nil ].each do |blank|
      calc = Calculators::DefaultedNumericDouble.new(required_amount: 5, offset: blank, factor: blank)
      assert calc.valid?, "blank #{blank.inspect} must be valid: #{calc.errors.full_messages}"
      assert_equal 3, calc.offset, "offset blank #{blank.inspect} should default"
      assert_equal BigDecimal("2"), calc.factor, "factor blank #{blank.inspect} should default"
      assert_nothing_raised { calc.result }
      assert_equal BigDecimal("46"), calc.result[:total]
    end
  end

  test "a blank string on a defaulted numeric is coerced through every assignment path" do
    # The coercion lives at the cast seam, so the per-attribute writer and
    # assign_attributes get it too — not just .new.
    calc = Calculators::DefaultedNumericDouble.new(required_amount: 5, offset: 9)
    assert_equal 9, calc.offset

    calc.offset = ""
    assert_equal 3, calc.offset, "writer-assigned blank must coerce to default"

    calc.assign_attributes(offset: "   ")
    assert_equal 3, calc.offset, "assign_attributes blank must coerce to default"
  end

  test "a non-blank value on a defaulted numeric is used as-is (not the default)" do
    calc = Calculators::DefaultedNumericDouble.new(required_amount: 5, offset: 10, factor: "4")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 10, calc.offset
    assert_equal BigDecimal("4"), calc.factor
  end

  test "garbage on a defaulted numeric is still rejected (coercion is blank-only)" do
    # The coercion replaces only BLANK values; real garbage still hits the guard.
    calc = Calculators::DefaultedNumericDouble.new(required_amount: 5, offset: "abc")
    assert_not calc.valid?
    assert_includes calc.errors[:offset], "is not a number"
  end

  test "a blank required numeric WITHOUT a default still triggers its presence rule" do
    # The coercion is scoped to defaulted attributes — a defaultless required numeric's
    # blank stays nil so its own presence validation owns the missing-input message.
    calc = Calculators::DefaultedNumericDouble.new(required_amount: "")
    assert_not calc.valid?
    assert_includes calc.errors[:required_amount], "can't be blank"
  end

  # --- array (list) attribute declaration ----------------------------------

  test "Base itself declares no array attributes" do
    # The top of the hierarchy: superclass (Object) does not respond to
    # array_attribute_names, so the empty-list fallback is used.
    assert_equal [], Calculators::Base.array_attribute_names
  end

  test "a scalar-only calculator declares no array attributes" do
    # TestDouble declares no list input — its array set is empty (inherited from Base).
    assert_equal [], Calculators::TestDouble.array_attribute_names
  end

  test "::array_attribute records a list input the controller permits as an array" do
    # ArrayAttributeDouble declares a `values` list — it appears in array_attribute_names
    # so CalculatorsController permits `inputs[values][]` as an array, not a scalar.
    assert_equal %w[values], Calculators::ArrayAttributeDouble.array_attribute_names
  end

  test "array attribute declarations do not leak across sibling subclasses" do
    # A subclass owns its own copy seeded from its parent, so declaring an array
    # attribute on one calculator never bleeds into a sibling.
    assert_equal [], Calculators::TestDouble.array_attribute_names
    assert_equal %w[values], Calculators::ArrayAttributeDouble.array_attribute_names
  end
end
