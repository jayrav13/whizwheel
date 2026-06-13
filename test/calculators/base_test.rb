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
end
