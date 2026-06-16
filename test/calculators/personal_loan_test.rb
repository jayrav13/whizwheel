require "test_helper"

# Reference-value + validation tests for Calculators::PersonalLoan (spec issue #246) —
# the single-mode, plain loan-core skin of the loan cluster: solve the level monthly
# payment + the full repayment schedule for a fixed-rate amortizing personal loan. The
# reference table is lifted verbatim from the spec's "Reference values" section; it pins
# correctness and must reproduce exactly (ARCHITECTURE.md §11). The suite also asserts the
# schedule shape (length, the month-1 breakdown anchor, the final row clearing to 0.00)
# and that the schedule reconciles to the summary totals.
class Calculators::PersonalLoanTest < ActiveSupport::TestCase
  # ----------------------------------------------------------------------------
  # Reference values — total_paid / total_interest are the SCHEDULE-RECONCILED sums
  # (Σ over the rows, the final row absorbing rounding), not monthly_payment × n.
  # [ loan_amount, annual_rate, term_months, monthly_payment, total_paid, total_interest ]
  # ----------------------------------------------------------------------------
  REFERENCE = [
    [ 15000, 7,  36, "463.16", "16673.61", "1673.61" ],
    [ 8000,  11, 24, "372.86", "8948.73",  "948.73" ],
    [ 5000,  0,  12, "416.67", "5000.00",  "0.00" ]
  ].freeze

  REFERENCE.each do |amount, rate, months, payment, total, interest|
    test "#{amount} @ #{rate}% / #{months}mo -> payment #{payment}" do
      calc = Calculators::PersonalLoan.new(
        loan_amount: amount, annual_rate: rate, term_months: months
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result

      assert_equal payment,  result[:monthly_payment], "monthly_payment"
      assert_equal total,    result[:total_paid],      "total_paid"
      assert_equal interest, result[:total_interest],  "total_interest"
      assert_equal months,   result[:number_of_payments], "number_of_payments"
      # loan_amount echoes the given figure (formatted to the cent).
      assert_equal BigDecimal(amount), BigDecimal(result[:loan_amount])

      # --- schedule shape ---
      schedule = result[:schedule]
      assert_equal months, schedule.length, "schedule length == number_of_payments"
      assert_equal "0.00", schedule.last[:balance], "final-row balance"

      # --- reconciliation: Σ over the rows == the summary totals ---
      sum_interest = schedule.sum { |row| BigDecimal(row[:interest]) }
      sum_payment  = schedule.sum { |row| BigDecimal(row[:payment]) }
      assert_equal BigDecimal(interest), sum_interest, "Σ interest == total_interest"
      assert_equal BigDecimal(total),    sum_payment,  "Σ payment == total_paid"
      # total_paid == loan_amount + total_interest
      assert_equal BigDecimal(amount) + BigDecimal(interest), BigDecimal(total)
    end
  end

  # ----------------------------------------------------------------------------
  # The spec's worked month-1 breakdown anchor for the 15000 @ 7% / 36 case.
  # ----------------------------------------------------------------------------
  test "15000 @ 7% / 36mo schedule month-1 matches the spec anchor" do
    schedule = Calculators::PersonalLoan.new(
      loan_amount: 15000, annual_rate: 7, term_months: 36
    ).result[:schedule]

    first = schedule.first
    assert_equal 1,          first[:month]
    assert_equal "463.16",   first[:payment],   "month-1 payment (the level payment)"
    assert_equal "87.50",    first[:interest],  "month-1 interest"
    assert_equal "375.66",   first[:principal], "month-1 principal"
    assert_equal "14624.34", first[:balance],   "month-1 balance"
  end

  # ----------------------------------------------------------------------------
  # Schedule formatting / shape invariants
  # ----------------------------------------------------------------------------
  test "all schedule money fields are exactly two-decimal strings; month is an Integer" do
    schedule = Calculators::PersonalLoan.new(
      loan_amount: 15000, annual_rate: 7, term_months: 36
    ).result[:schedule]

    schedule.each do |row|
      %i[payment interest principal balance].each do |key|
        assert_match(/\A-?\d+\.\d{2}\z/, row[key], "#{key} = #{row[key].inspect}")
      end
      assert_kind_of Integer, row[:month]
    end
  end

  test "non-final rows all carry the level monthly payment" do
    result = Calculators::PersonalLoan.new(
      loan_amount: 15000, annual_rate: 7, term_months: 36
    ).result
    level = result[:monthly_payment]
    result[:schedule][0..-2].each do |row|
      assert_equal level, row[:payment], "row #{row[:month]} payment"
    end
  end

  test "the zero-rate final payment absorbs rounding so the balance clears to 0.00" do
    # 5000 / 12 = 416.666… → 416.67; the final payment absorbs the over-collection.
    result = Calculators::PersonalLoan.new(
      loan_amount: 5000, annual_rate: 0, term_months: 12
    ).result
    assert_equal "416.67",  result[:monthly_payment]
    assert_equal "0.00",    result[:total_interest]
    assert_equal "5000.00", result[:total_paid]
    assert_equal "0.00",    result[:schedule].last[:balance]
  end

  test "result carries exactly the spec's output keys" do
    result = Calculators::PersonalLoan.new(
      loan_amount: 15000, annual_rate: 7, term_months: 36
    ).result
    expected = %i[
      loan_amount monthly_payment total_paid total_interest
      number_of_payments schedule
    ]
    assert_equal expected.sort, result.keys.sort
  end

  test "schedule rows carry exactly month/payment/interest/principal/balance" do
    row = Calculators::PersonalLoan.new(
      loan_amount: 5000, annual_rate: 0, term_months: 12
    ).result[:schedule].first
    assert_equal %i[month payment interest principal balance], row.keys
  end

  # ----------------------------------------------------------------------------
  # Precision: string inputs coerce to exact BigDecimal (no float drift)
  # ----------------------------------------------------------------------------
  test "string inputs are coerced to exact BigDecimal" do
    calc = Calculators::PersonalLoan.new(
      loan_amount: "15000", annual_rate: "7", term_months: "36"
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "463.16", calc.result[:monthly_payment]
  end

  # ----------------------------------------------------------------------------
  # Validation — presence + positivity (spec's edge/validation cases)
  # ----------------------------------------------------------------------------
  test "loan_amount must be greater than 0" do
    [ 0, -100 ].each do |bad|
      calc = Calculators::PersonalLoan.new(
        loan_amount: bad, annual_rate: 7, term_months: 36
      )
      assert_not calc.valid?, "loan_amount=#{bad} should be invalid"
      assert_includes calc.errors[:loan_amount], "must be greater than 0"
      assert_nil calc.result
    end
  end

  test "loan_amount is required" do
    calc = Calculators::PersonalLoan.new(annual_rate: 7, term_months: 36)
    assert_not calc.valid?
    assert_includes calc.errors[:loan_amount], "can't be blank"
    assert_nil calc.result
  end

  test "term_months must be greater than 0" do
    calc = Calculators::PersonalLoan.new(
      loan_amount: 15000, annual_rate: 7, term_months: 0
    )
    assert_not calc.valid?
    assert_includes calc.errors[:term_months], "must be greater than 0"
    assert_nil calc.result
  end

  test "term_months is required" do
    calc = Calculators::PersonalLoan.new(loan_amount: 15000, annual_rate: 7)
    assert_not calc.valid?
    assert_includes calc.errors[:term_months], "can't be blank"
  end

  test "annual_rate is required" do
    calc = Calculators::PersonalLoan.new(loan_amount: 15000, term_months: 36)
    assert_not calc.valid?
    assert_includes calc.errors[:annual_rate], "can't be blank"
  end

  test "annual_rate must be >= 0 (negative rejected, zero accepted)" do
    neg = Calculators::PersonalLoan.new(
      loan_amount: 15000, annual_rate: -1, term_months: 36
    )
    assert_not neg.valid?
    assert_includes neg.errors[:annual_rate], "must be greater than or equal to 0"

    zero = Calculators::PersonalLoan.new(
      loan_amount: 5000, annual_rate: 0, term_months: 12
    )
    assert zero.valid?, zero.errors.full_messages.to_sentence
  end

  # ----------------------------------------------------------------------------
  # Validation — Base numeric coercion guard (#109/#110)
  # ----------------------------------------------------------------------------
  test "a fractional term_months is rejected, not silently truncated (#109)" do
    calc = Calculators::PersonalLoan.new(
      loan_amount: 15000, annual_rate: 7, term_months: "36.5"
    )
    assert_not calc.valid?
    assert_includes calc.errors[:term_months], "must be a whole number"
    assert_nil calc.result
  end

  test "a non-numeric annual_rate is rejected as not-a-number (#110)" do
    calc = Calculators::PersonalLoan.new(
      loan_amount: 15000, annual_rate: "x", term_months: 36
    )
    assert_not calc.valid?
    assert_includes calc.errors[:annual_rate], "is not a number"
    assert_nil calc.result
  end

  test "scientific-notation decimal input is accepted (#109)" do
    calc = Calculators::PersonalLoan.new(
      loan_amount: "1.5e4", annual_rate: 7, term_months: 36
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    # 1.5e4 == 15000 → the reference payment.
    assert_equal "463.16", calc.result[:monthly_payment]
  end

  # ----------------------------------------------------------------------------
  # Envelope/contract surface
  # ----------------------------------------------------------------------------
  test "to_calculation records the slug, inputs and result" do
    calc = Calculators::PersonalLoan.new(
      loan_amount: 15000, annual_rate: 7, term_months: 36
    )
    record = calc.to_calculation
    assert_equal "personal_loan", record.calculator
    assert_equal BigDecimal("15000"), BigDecimal(record.inputs["loan_amount"].to_s)
    assert_equal 36, record.result["schedule"].length # jsonb stringifies keys
  end
end
