require "test_helper"
require "active_support/testing/time_helpers"

# Reference-value + validation tests for Calculators::Age (spec issue #81), the
# project's first date-math calculator. The reference table is lifted verbatim
# from the spec's "Reference values" section — it pins correctness and must
# reproduce exactly (ARCHITECTURE.md §11). All reference rows pass an EXPLICIT
# end_date for determinism; the default-to-today behavior gets its own clock-
# stubbed test (the spec forbids a today-dependent row in the reference table).
class Calculators::AgeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  # --- Reference values: {birth_date, end_date} -> the seven integer outputs ---
  # birth | end | years months days | total_months total_weeks total_days total_hours
  [
    [ "1990-06-15", "2024-06-14", 33, 11, 30, 407, 1774, 12418, 298032 ],
    [ "2000-01-01", "2024-01-01", 24,  0,  0, 288, 1252,  8766, 210384 ],
    [ "1995-12-31", "2024-06-14", 28,  5, 14, 341, 1484, 10393, 249432 ],
    [ "2020-02-29", "2024-02-28",  3, 11, 30,  47,  208,  1460,  35040 ],
    [ "2023-03-01", "2023-03-01",  0,  0,  0,   0,    0,     0,      0 ]
  ].each do |birth, finish, years, months, days, total_months, total_weeks, total_days, total_hours|
    test "#{birth} -> #{finish} is #{years}y #{months}m #{days}d" do
      calc = Calculators::Age.new(birth_date: birth, end_date: finish)
      assert calc.valid?, calc.errors.full_messages.to_sentence

      result = calc.result
      assert_equal years,        result[:years]
      assert_equal months,       result[:months]
      assert_equal days,         result[:days]
      assert_equal total_months, result[:total_months]
      assert_equal total_weeks,  result[:total_weeks]
      assert_equal total_days,   result[:total_days]
      assert_equal total_hours,  result[:total_hours]
    end
  end

  # --- The leap-aware borrow: the guard row from the spec, called out ---
  test "a leap-day birthday measured to a non-leap Feb 28 borrows correctly" do
    # 2020-02-29 -> 2024-02-28: days go negative (28 - 29), so we borrow the
    # day-count of the month preceding the END month (Jan, 31 days), landing on
    # 3y 11m 30d — NOT what borrowing the birth month (Feb) would give.
    result = Calculators::Age.new(birth_date: "2020-02-29", end_date: "2024-02-28").result
    assert_equal [ 3, 11, 30 ], [ result[:years], result[:months], result[:days] ]
  end

  test "the month borrow is leap-aware: borrowing a leap February uses 29 days" do
    # 2024-01-30 -> 2024-03-01: months 3-1=2, days 1-30=-29 < 0, so borrow the
    # month preceding March — February 2024, a LEAP February (29 days): months
    # -= 1 → 1, days += 29 → 0. Result 0y 1m 0d; total_days = 31 (Feb has 29).
    result = Calculators::Age.new(birth_date: "2024-01-30", end_date: "2024-03-01").result
    assert_equal [ 0, 1, 0 ], [ result[:years], result[:months], result[:days] ]
    assert_equal 31, result[:total_days]
  end

  test "the year boundary borrow uses December when the end month is January" do
    # 2023-12-15 -> 2024-01-10: days 10-15=-5<0 → borrow the month before Jan,
    # i.e. December (31 days): months 1-12=-11 → -12 after the day-borrow → +12
    # → 0, years 2024-2023=1 → 0. days = -5 + 31 = 26. So 0y 0m 26d.
    result = Calculators::Age.new(birth_date: "2023-12-15", end_date: "2024-01-10").result
    assert_equal [ 0, 0, 26 ], [ result[:years], result[:months], result[:days] ]
  end

  test "same-day is all zeros across every output" do
    result = Calculators::Age.new(birth_date: "2010-07-04", end_date: "2010-07-04").result
    assert_equal({ years: 0, months: 0, days: 0, total_months: 0, total_weeks: 0, total_days: 0, total_hours: 0 }, result)
  end

  test "total_weeks floors (integer division) the day count" do
    # 2024-01-01 -> 2024-01-10 is 9 days → 1 week (9 / 7 = 1, floored).
    result = Calculators::Age.new(birth_date: "2024-01-01", end_date: "2024-01-10").result
    assert_equal 9, result[:total_days]
    assert_equal 1, result[:total_weeks]
  end

  # --- default-to-today (clock stubbed; never a reference-table row) ---
  test "end_date defaults to today when omitted" do
    travel_to Time.zone.local(2024, 6, 14, 12, 0, 0) do
      calc = Calculators::Age.new(birth_date: "1990-06-15")
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal Date.new(2024, 6, 14), calc.effective_end_date
      result = calc.result
      assert_equal [ 33, 11, 30 ], [ result[:years], result[:months], result[:days] ]
    end
  end

  test "a blank-string end_date is treated as omitted and defaults to today" do
    travel_to Time.zone.local(2024, 1, 1) do
      calc = Calculators::Age.new(birth_date: "2000-01-01", end_date: "")
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal Date.new(2024, 1, 1), calc.effective_end_date
      assert_equal [ 24, 0, 0 ], [ calc.result[:years], calc.result[:months], calc.result[:days] ]
    end
  end

  # --- Validation cases (from the spec) ---
  test "birth_date after end_date is rejected (no negative ages)" do
    calc = Calculators::Age.new(birth_date: "2024-06-15", end_date: "2024-06-14")
    assert_not calc.valid?
    assert_includes calc.errors[:birth_date], "must be on or before the end date"
    assert_nil calc.result
  end

  test "an invalid birth_date (Feb 30) is rejected as not a real date" do
    calc = Calculators::Age.new(birth_date: "2023-02-30", end_date: "2024-01-01")
    assert_not calc.valid?
    assert_includes calc.errors[:birth_date], "is not a valid date"
    assert_nil calc.result
  end

  test "an invalid birth_date (month 13) is rejected" do
    calc = Calculators::Age.new(birth_date: "2023-13-01")
    assert_not calc.valid?
    assert_includes calc.errors[:birth_date], "is not a valid date"
  end

  test "an invalid end_date is rejected, not silently defaulted to today" do
    calc = Calculators::Age.new(birth_date: "1990-01-01", end_date: "2023-13-01")
    assert_not calc.valid?
    assert_includes calc.errors[:end_date], "is not a valid date"
    assert_nil calc.effective_end_date
    assert_nil calc.result
  end

  test "birth_date is required" do
    calc = Calculators::Age.new(end_date: "2024-01-01")
    assert_not calc.valid?
    assert_includes calc.errors[:birth_date], "can't be blank"
  end

  test "a blank-string birth_date fails as blank" do
    calc = Calculators::Age.new(birth_date: "", end_date: "2024-01-01")
    assert_not calc.valid?
    assert_includes calc.errors[:birth_date], "can't be blank"
  end

  test "with everything omitted, only birth_date is faulted (end defaults to today)" do
    calc = Calculators::Age.new
    assert_not calc.valid?
    assert_includes calc.errors[:birth_date], "can't be blank"
    assert_empty calc.errors[:end_date]
  end

  # --- coercion + envelope/contract surface ---
  test "date strings are accepted and coerced to Date" do
    calc = Calculators::Age.new(birth_date: "1990-06-15", end_date: "2024-06-14")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal Date.new(1990, 6, 15), calc.birth_date
    assert_equal Date.new(2024, 6, 14), calc.end_date
  end

  test "the result carries exactly the seven spec output keys" do
    result = Calculators::Age.new(birth_date: "1990-06-15", end_date: "2024-06-14").result
    assert_equal %i[years months days total_months total_weeks total_days total_hours].sort, result.keys.sort
  end

  test "to_calculation records the slug, inputs and result keys" do
    calc = Calculators::Age.new(birth_date: "1990-06-15", end_date: "2024-06-14")
    record = calc.to_calculation
    assert_equal "age", record.calculator
    # :date attributes serialize to ISO-8601 strings in the inputs hash.
    assert_equal "1990-06-15", record.inputs["birth_date"].to_s
    assert_equal 33, record.result["years"]
    assert_equal 12418, record.result["total_days"]
  end
end
