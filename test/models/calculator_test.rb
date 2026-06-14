require "test_helper"

class CalculatorTest < ActiveSupport::TestCase
  test "requires a slug" do
    calc = Calculator.new(name: "No Slug")
    assert_not calc.valid?
    assert_includes calc.errors[:slug], "can't be blank"
  end

  test "requires a name" do
    calc = Calculator.new(slug: "no_name")
    assert_not calc.valid?
    assert_includes calc.errors[:name], "can't be blank"
  end

  test "slug must be unique" do
    dup = Calculator.new(slug: calculators(:percentage).slug, name: "Dup")
    assert_not dup.valid?
    assert_includes dup.errors[:slug], "has already been taken"
  end

  test "active scope excludes deprecated rows" do
    slugs = Calculator.active.pluck(:slug)
    assert_includes slugs, "percentage"
    assert_not_includes slugs, "retired_thing"
  end

  test "deprecated scope returns only deprecated rows" do
    assert_equal [ "retired_thing" ], Calculator.deprecated.pluck(:slug)
  end

  test "deprecate marks but never destroys" do
    calc = calculators(:percentage)
    assert_no_difference -> { Calculator.count } do
      calc.deprecate
    end
    assert calc.reload.deprecated?
  end

  test "deprecate is idempotent and preserves the original timestamp" do
    calc = calculators(:retired_thing)
    original = calc.deprecated_at
    calc.deprecate
    assert_equal original.to_i, calc.reload.deprecated_at.to_i
  end

  test "reinstate clears the deprecation" do
    calc = calculators(:retired_thing)
    calc.reinstate
    assert_not calc.reload.deprecated?
  end

  test "reinstate is a no-op on an active row" do
    calc = calculators(:percentage)
    assert_no_changes -> { calc.reload.deprecated_at } do
      calc.reinstate
    end
  end
end
