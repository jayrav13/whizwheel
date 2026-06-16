require "test_helper"

# Reference-value + validation tests for Calculators::Date (spec issue #194), a
# two-mode date-math calculator. The reference tables are lifted verbatim from the
# spec's "Reference values" section — they pin correctness and must reproduce
# exactly (ARCHITECTURE.md §11). Note the class shadows stdlib Date inside the
# Calculators namespace; the test references the calculator by its full path.
class Calculators::DateTest < ActiveSupport::TestCase
  # --- difference mode: reference values --------------------------------------
  # start | end | total_days years months days total_weeks remainder_days
  [
    [ "2023-01-15", "2025-03-20", 795, 2,  2,  5, 113, 4 ],
    [ "2024-01-01", "2024-12-31", 365, 0, 11, 30,  52, 1 ],
    [ "2020-02-28", "2020-03-01",   2, 0,  0,  2,   0, 2 ]
  ].each do |start, finish, total_days, years, months, days, total_weeks, remainder_days|
    test "difference #{start} -> #{finish} is #{total_days} days / #{years}y #{months}m #{days}d" do
      calc = Calculators::Date.new(mode: "difference", start_date: start, end_date: finish)
      assert calc.valid?, calc.errors.full_messages.to_sentence

      result = calc.result
      assert_equal "difference", result[:mode]
      assert_equal total_days,     result[:total_days]
      assert_equal years,          result[:years]
      assert_equal months,         result[:months]
      assert_equal days,           result[:days]
      assert_equal total_weeks,    result[:total_weeks]
      assert_equal remainder_days, result[:remainder_days]
    end
  end

  test "difference is order-independent: reversed dates report the same magnitude" do
    forward = Calculators::Date.new(mode: "difference", start_date: "2023-01-15", end_date: "2025-03-20").result
    reverse = Calculators::Date.new(mode: "difference", start_date: "2025-03-20", end_date: "2023-01-15").result
    assert_equal forward, reverse
    assert_equal 795, reverse[:total_days]
    assert_equal [ 2, 2, 5 ], [ reverse[:years], reverse[:months], reverse[:days] ]
  end

  test "difference between identical dates is all zeros" do
    result = Calculators::Date.new(mode: "difference", start_date: "2024-05-10", end_date: "2024-05-10").result
    assert_equal 0, result[:total_days]
    assert_equal [ 0, 0, 0 ], [ result[:years], result[:months], result[:days] ]
    assert_equal 0, result[:total_weeks]
    assert_equal 0, result[:remainder_days]
  end

  test "the leap-spanning Feb 28 -> Mar 1 in 2020 is 2 days (Feb 29 exists)" do
    result = Calculators::Date.new(mode: "difference", start_date: "2020-02-28", end_date: "2020-03-01").result
    assert_equal 2, result[:total_days]
  end

  test "difference borrow is leap-aware across a January boundary" do
    # 2023-12-15 -> 2024-01-10: days 10-15 = -5 < 0, borrow December (31): months
    # 1-12=-11, then -=1 from the day-borrow → -12 → +12 → 0, years 1 → 0. days 26.
    result = Calculators::Date.new(mode: "difference", start_date: "2023-12-15", end_date: "2024-01-10").result
    assert_equal [ 0, 0, 26 ], [ result[:years], result[:months], result[:days] ]
  end

  test "difference result carries exactly the seven output keys" do
    result = Calculators::Date.new(mode: "difference", start_date: "2023-01-15", end_date: "2025-03-20").result
    assert_equal %i[days mode months remainder_days total_days total_weeks years].sort, result.keys.sort
  end

  # --- add_subtract mode: reference values ------------------------------------
  # start | operation | years months weeks days | result_date
  [
    [ "2024-01-01", "add",      0, 0, 0, 30, "2024-01-31" ],
    [ "2024-02-28", "add",      0, 0, 0,  1, "2024-02-29" ],
    [ "2024-01-01", "subtract", 0, 0, 0,  1, "2023-12-31" ],
    [ "2023-01-31", "add",      0, 1, 0,  0, "2023-02-28" ],
    [ "2020-02-29", "add",      1, 0, 0,  0, "2021-02-28" ]
  ].each do |start, operation, years, months, weeks, days, expected|
    test "add_subtract #{start} #{operation} #{years}y #{months}m #{weeks}w #{days}d -> #{expected}" do
      calc = Calculators::Date.new(
        mode: "add_subtract", start_date: start, operation: operation,
        years: years, months: months, weeks: weeks, days: days
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence

      result = calc.result
      assert_equal "add_subtract", result[:mode]
      assert_equal expected, result[:result_date]
      assert_equal start, result[:start_date]
      assert_equal operation, result[:operation]
    end
  end

  test "add_subtract with all offsets zero returns the start date unchanged" do
    calc = Calculators::Date.new(mode: "add_subtract", start_date: "2024-06-14", operation: "add")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "2024-06-14", calc.result[:result_date]
  end

  test "add_subtract with blank offset fields uses the default 0 (no 500) — #213" do
    # An API client (or a form without client-side value="0") submits the offset keys
    # as empty strings. Without Base's blank-defaults-the-default coercion these cast
    # to nil and `nil * 12` in #compute would 500. Each must default to 0.
    calc = Calculators::Date.new(
      mode: "add_subtract", start_date: "2024-06-14", operation: "add",
      years: "", months: "", weeks: "", days: ""
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 0, calc.years
    assert_equal 0, calc.months
    assert_equal 0, calc.weeks
    assert_equal 0, calc.days
    assert_nothing_raised { calc.result }
    assert_equal "2024-06-14", calc.result[:result_date]
  end

  test "add_subtract applies years and months together with end-of-month clamping" do
    # 2020-02-29 + 1 year 0 months → 2021-02-28 (clamped); + 1 more day via days field.
    calc = Calculators::Date.new(
      mode: "add_subtract", start_date: "2020-02-29", operation: "add", years: 1, days: 1
    )
    assert_equal "2021-03-01", calc.result[:result_date]
  end

  test "add_subtract weeks are exact day arithmetic (x7)" do
    calc = Calculators::Date.new(mode: "add_subtract", start_date: "2024-01-01", operation: "add", weeks: 2)
    assert_equal "2024-01-15", calc.result[:result_date]
  end

  test "add_subtract subtract crosses a month boundary by exact days" do
    calc = Calculators::Date.new(mode: "add_subtract", start_date: "2024-03-01", operation: "subtract", days: 2)
    # 2024 is a leap year: Mar 1 - 2 days = Feb 28.
    assert_equal "2024-02-28", calc.result[:result_date]
  end

  test "add_subtract subtract of months clamps end-of-month" do
    # 2024-03-31 - 1 month → February 2024 (29 days, leap) → 2024-02-29.
    calc = Calculators::Date.new(mode: "add_subtract", start_date: "2024-03-31", operation: "subtract", months: 1)
    assert_equal "2024-02-29", calc.result[:result_date]
  end

  test "add_subtract result carries exactly the four output keys" do
    result = Calculators::Date.new(
      mode: "add_subtract", start_date: "2024-01-01", operation: "add", days: 30
    ).result
    assert_equal %i[mode operation result_date start_date].sort, result.keys.sort
  end

  # --- validation cases (from the spec) ---------------------------------------
  test "difference mode requires end_date" do
    calc = Calculators::Date.new(mode: "difference", start_date: "2024-01-01")
    assert_not calc.valid?
    assert_includes calc.errors[:end_date], "can't be blank"
    assert_nil calc.result
  end

  test "difference mode with start after end is valid (magnitude reported)" do
    calc = Calculators::Date.new(mode: "difference", start_date: "2025-03-20", end_date: "2023-01-15")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 795, calc.result[:total_days]
  end

  test "add_subtract mode requires operation" do
    calc = Calculators::Date.new(mode: "add_subtract", start_date: "2024-01-01", days: 5)
    assert_not calc.valid?
    assert_includes calc.errors[:operation], "can't be blank"
    assert_nil calc.result
  end

  test "add_subtract mode rejects an operation not in add/subtract" do
    calc = Calculators::Date.new(mode: "add_subtract", start_date: "2024-01-01", operation: "multiply")
    assert_not calc.valid?
    assert_includes calc.errors[:operation], "is not included in the list"
  end

  test "start_date is always required" do
    calc = Calculators::Date.new(mode: "difference", end_date: "2024-01-01")
    assert_not calc.valid?
    assert_includes calc.errors[:start_date], "can't be blank"
  end

  test "an unparseable start_date (Feb 30) is rejected as not a valid date" do
    calc = Calculators::Date.new(mode: "difference", start_date: "2023-02-30", end_date: "2024-01-01")
    assert_not calc.valid?
    assert_includes calc.errors[:start_date], "is not a valid date"
    assert_nil calc.result
  end

  test "an unparseable end_date is rejected in difference mode" do
    calc = Calculators::Date.new(mode: "difference", start_date: "2024-01-01", end_date: "2023-13-01")
    assert_not calc.valid?
    assert_includes calc.errors[:end_date], "is not a valid date"
  end

  test "a fractional integer offset is rejected by the Base numeric guard" do
    calc = Calculators::Date.new(
      mode: "add_subtract", start_date: "2024-01-01", operation: "add", months: "1.5"
    )
    assert_not calc.valid?
    assert_includes calc.errors[:months], "must be a whole number"
    assert_nil calc.result
  end

  test "a non-numeric integer offset is rejected by the Base numeric guard" do
    calc = Calculators::Date.new(
      mode: "add_subtract", start_date: "2024-01-01", operation: "add", days: "abc"
    )
    assert_not calc.valid?
    assert_includes calc.errors[:days], "is not a number"
  end

  test "a negative offset is rejected (offsets are unsigned magnitudes)" do
    calc = Calculators::Date.new(
      mode: "add_subtract", start_date: "2024-01-01", operation: "add", days: "-3"
    )
    assert_not calc.valid?
    assert_includes calc.errors[:days], "must be greater than or equal to 0"
  end

  test "mode is required" do
    calc = Calculators::Date.new(start_date: "2024-01-01")
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "can't be blank"
  end

  test "an unknown mode is rejected by inclusion" do
    calc = Calculators::Date.new(mode: "zzz", start_date: "2024-01-01")
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "is not included in the list"
  end

  # --- contract surface -------------------------------------------------------
  test "to_calculation records the slug, inputs and difference result keys" do
    calc = Calculators::Date.new(mode: "difference", start_date: "2023-01-15", end_date: "2025-03-20")
    record = calc.to_calculation
    assert_equal "date", record.calculator
    assert_equal "difference", record.inputs["mode"]
    assert_equal 795, record.result["total_days"]
  end

  test "to_calculation records the add_subtract result_date string" do
    calc = Calculators::Date.new(mode: "add_subtract", start_date: "2024-01-01", operation: "add", days: 30)
    record = calc.to_calculation
    assert_equal "date", record.calculator
    assert_equal "2024-01-31", record.result["result_date"]
  end
end
