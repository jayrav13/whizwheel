require "test_helper"

# Reference-value + validation tests for Calculators::Loan (spec issue #184) — a
# fixed-rate amortizing loan with a solve-for **mode picker** (payment / amount /
# term), generalizing Amortization. The reference tables are lifted verbatim from the
# spec's "Reference values" section; they pin correctness and must reproduce exactly
# (ARCHITECTURE.md §11). The suite also asserts the schedule shape (length, month-1
# breakdown, final row clearing to 0.00) and that the schedule reconciles to the
# summary totals.
class Calculators::LoanTest < ActiveSupport::TestCase
  # ----------------------------------------------------------------------------
  # Mode `payment` — solve for the monthly payment
  # total_paid / total_interest are the SCHEDULE-RECONCILED sums (Σ over the rows,
  # the final row absorbing rounding), not monthly_payment × n.
  # [ loan_amount, annual_rate, term_months, payment, total_paid, total_interest ]
  # ----------------------------------------------------------------------------
  PAYMENT_REFERENCE = [
    [ 200000, 6, 360, "1199.10", "431677.04", "231677.04" ],
    [ 25000,  5, 60,  "471.78",  "28306.88",  "3306.88" ],
    [ 10000,  0, 24,  "416.67",  "10000.00",  "0.00" ]
  ].freeze

  PAYMENT_REFERENCE.each do |amount, rate, months, payment, total, interest|
    test "payment mode: #{amount} @ #{rate}% / #{months}mo -> payment #{payment}" do
      calc = Calculators::Loan.new(
        mode: "payment", loan_amount: amount, annual_rate: rate, term_months: months
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result

      assert_equal "payment", result[:mode]
      assert_equal payment,  result[:monthly_payment], "monthly_payment"
      assert_equal total,    result[:total_paid],      "total_paid"
      assert_equal interest, result[:total_interest],  "total_interest"
      assert_equal months,   result[:term_months],     "term_months"
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

  # The spec's month-1 breakdown anchor for the 25000 @ 5% / 60 case.
  test "payment mode: 25000 @ 5% / 60mo schedule month-1 matches the spec anchor" do
    schedule = Calculators::Loan.new(
      mode: "payment", loan_amount: 25000, annual_rate: 5, term_months: 60
    ).result[:schedule]

    first = schedule.first
    assert_equal 1,          first[:month]
    assert_equal "471.78",   first[:payment],   "month-1 payment (the level payment)"
    assert_equal "104.17",   first[:interest],  "month-1 interest"
    assert_equal "367.61",   first[:principal], "month-1 principal"
    assert_equal "24632.39", first[:balance],   "month-1 balance"
  end

  # ----------------------------------------------------------------------------
  # Mode `amount` — solve for the affordable loan amount
  # Pinned by the solved loan_amount (the exact inverse of the payment identity).
  # [ monthly_payment, annual_rate, term_months, loan_amount (solved) ]
  # ----------------------------------------------------------------------------
  AMOUNT_REFERENCE = [
    [ "1199.10", 6, 360, "199999.82" ],
    [ "471.78",  5, 60,  "24999.96" ]
  ].freeze

  AMOUNT_REFERENCE.each do |payment, rate, months, amount|
    test "amount mode: #{payment} @ #{rate}% / #{months}mo -> loan_amount #{amount}" do
      calc = Calculators::Loan.new(
        mode: "amount", monthly_payment: payment, annual_rate: rate, term_months: months
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result

      assert_equal "amount", result[:mode]
      assert_equal amount,   result[:loan_amount],     "loan_amount (solved)"
      # monthly_payment echoes the given figure.
      assert_equal payment,  result[:monthly_payment], "monthly_payment"
      assert_equal months,   result[:term_months],     "term_months"

      # the schedule reconciles to the solved amount + total interest.
      schedule = result[:schedule]
      assert_equal months, schedule.length
      assert_equal "0.00", schedule.last[:balance]
      sum_payment = schedule.sum { |row| BigDecimal(row[:payment]) }
      assert_equal BigDecimal(result[:total_paid]), sum_payment
      assert_equal BigDecimal(amount) + BigDecimal(result[:total_interest]),
        BigDecimal(result[:total_paid])
    end
  end

  # The r = 0 amount edge (P = M · n) — exercises the zero-rate branch of #raw_amount.
  test "amount mode: zero rate solves loan_amount as M × n" do
    result = Calculators::Loan.new(
      mode: "amount", monthly_payment: "500.00", annual_rate: 0, term_months: 24
    ).result
    assert_equal "12000.00", result[:loan_amount]
    assert_equal "0.00",     result[:total_interest]
  end

  # ----------------------------------------------------------------------------
  # Mode `term` — solve for the term in whole months (rounded UP)
  # [ loan_amount, monthly_payment, annual_rate, term_months, total_paid, total_interest ]
  # ----------------------------------------------------------------------------
  TERM_REFERENCE = [
    [ 25000, "600.00", 5, 46, "27516.64", "2516.64" ], # raw n ≈ 45.8608 → ceil 46
    [ 10000, "500.00", 0, 20, "10000.00", "0.00" ]     # r = 0 → n = P/M = 20
  ].freeze

  TERM_REFERENCE.each do |amount, payment, rate, months, total, interest|
    test "term mode: #{amount} / #{payment} @ #{rate}% -> term #{months}mo" do
      calc = Calculators::Loan.new(
        mode: "term", loan_amount: amount, monthly_payment: payment, annual_rate: rate
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result

      assert_equal "term",   result[:mode]
      assert_equal months,   result[:term_months],       "term_months (ceil'd)"
      assert_equal months,   result[:number_of_payments], "number_of_payments"
      assert_equal total,    result[:total_paid],         "total_paid"
      assert_equal interest, result[:total_interest],     "total_interest"
      # loan_amount + monthly_payment echo the given figures.
      assert_equal BigDecimal(amount),  BigDecimal(result[:loan_amount])
      assert_equal payment,             result[:monthly_payment]

      # --- schedule shape + reconciliation ---
      schedule = result[:schedule]
      assert_equal months, schedule.length, "schedule length == term_months"
      assert_equal "0.00", schedule.last[:balance], "final-row balance"
      sum_interest = schedule.sum { |row| BigDecimal(row[:interest]) }
      sum_payment  = schedule.sum { |row| BigDecimal(row[:payment]) }
      assert_equal BigDecimal(interest), sum_interest, "Σ interest == total_interest"
      assert_equal BigDecimal(total),    sum_payment,  "Σ payment == total_paid"
    end
  end

  # The term-mode month-1 breakdown anchor (25000, 600.00 @ 5%).
  test "term mode: 25000 / 600.00 @ 5% schedule month-1 matches the spec anchor" do
    schedule = Calculators::Loan.new(
      mode: "term", loan_amount: 25000, monthly_payment: "600.00", annual_rate: 5
    ).result[:schedule]

    first = schedule.first
    assert_equal 1,          first[:month]
    assert_equal "600.00",   first[:payment],   "month-1 payment (the given payment)"
    assert_equal "104.17",   first[:interest],  "month-1 interest"
    assert_equal "495.83",   first[:principal], "month-1 principal"
    assert_equal "24504.17", first[:balance],   "month-1 balance"
  end

  # ----------------------------------------------------------------------------
  # Schedule formatting / shape invariants
  # ----------------------------------------------------------------------------
  test "all schedule money fields are exactly two-decimal strings; month is an Integer" do
    schedule = Calculators::Loan.new(
      mode: "payment", loan_amount: 200000, annual_rate: 6, term_months: 360
    ).result[:schedule]

    schedule.each do |row|
      %i[payment interest principal balance].each do |key|
        assert_match(/\A-?\d+\.\d{2}\z/, row[key], "#{key} = #{row[key].inspect}")
      end
      assert_kind_of Integer, row[:month]
    end
  end

  test "non-final rows all carry the level monthly payment" do
    result = Calculators::Loan.new(
      mode: "payment", loan_amount: 25000, annual_rate: 5, term_months: 60
    ).result
    level = result[:monthly_payment]
    result[:schedule][0..-2].each do |row|
      assert_equal level, row[:payment], "row #{row[:month]} payment"
    end
  end

  test "result carries exactly the spec's output keys" do
    result = Calculators::Loan.new(
      mode: "payment", loan_amount: 25000, annual_rate: 5, term_months: 60
    ).result
    expected = %i[
      mode monthly_payment loan_amount term_months
      total_paid total_interest number_of_payments schedule
    ]
    assert_equal expected.sort, result.keys.sort
  end

  test "schedule rows carry exactly month/payment/interest/principal/balance" do
    row = Calculators::Loan.new(
      mode: "payment", loan_amount: 10000, annual_rate: 0, term_months: 24
    ).result[:schedule].first
    assert_equal %i[month payment interest principal balance], row.keys
  end

  # ----------------------------------------------------------------------------
  # Precision: string inputs coerce to exact BigDecimal (no float drift)
  # ----------------------------------------------------------------------------
  test "string inputs are coerced to exact BigDecimal" do
    calc = Calculators::Loan.new(
      mode: "payment", loan_amount: "25000", annual_rate: "5", term_months: "60"
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "471.78", calc.result[:monthly_payment]
  end

  # ----------------------------------------------------------------------------
  # Validation — mode
  # ----------------------------------------------------------------------------
  test "mode is required" do
    calc = Calculators::Loan.new(loan_amount: 25000, annual_rate: 5, term_months: 60)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "can't be blank"
    assert_nil calc.result
  end

  test "mode must be one of payment/amount/term" do
    calc = Calculators::Loan.new(
      mode: "zzz", loan_amount: 25000, annual_rate: 5, term_months: 60
    )
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "is not included in the list"
    assert_nil calc.result
  end

  # ----------------------------------------------------------------------------
  # Validation — annual_rate (always required, >= 0)
  # ----------------------------------------------------------------------------
  test "annual_rate is required" do
    calc = Calculators::Loan.new(mode: "payment", loan_amount: 25000, term_months: 60)
    assert_not calc.valid?
    assert_includes calc.errors[:annual_rate], "can't be blank"
  end

  test "annual_rate must be >= 0 (negative rejected, zero accepted)" do
    neg = Calculators::Loan.new(
      mode: "payment", loan_amount: 25000, annual_rate: -1, term_months: 60
    )
    assert_not neg.valid?
    assert_includes neg.errors[:annual_rate], "must be greater than or equal to 0"

    zero = Calculators::Loan.new(
      mode: "payment", loan_amount: 10000, annual_rate: 0, term_months: 24
    )
    assert zero.valid?, zero.errors.full_messages.to_sentence
  end

  # ----------------------------------------------------------------------------
  # Validation — per-mode required fields
  # ----------------------------------------------------------------------------
  test "payment mode requires loan_amount and term_months" do
    missing_amount = Calculators::Loan.new(mode: "payment", annual_rate: 5, term_months: 60)
    assert_not missing_amount.valid?
    assert_includes missing_amount.errors[:loan_amount], "can't be blank"

    missing_term = Calculators::Loan.new(mode: "payment", loan_amount: 25000, annual_rate: 5)
    assert_not missing_term.valid?
    assert_includes missing_term.errors[:term_months], "can't be blank"
    assert_nil missing_term.result
  end

  test "amount mode requires monthly_payment and term_months" do
    missing_payment = Calculators::Loan.new(mode: "amount", annual_rate: 5, term_months: 60)
    assert_not missing_payment.valid?
    assert_includes missing_payment.errors[:monthly_payment], "can't be blank"

    missing_term = Calculators::Loan.new(mode: "amount", monthly_payment: "471.78", annual_rate: 5)
    assert_not missing_term.valid?
    assert_includes missing_term.errors[:term_months], "can't be blank"
  end

  test "term mode requires loan_amount and monthly_payment" do
    missing_amount = Calculators::Loan.new(mode: "term", monthly_payment: "600.00", annual_rate: 5)
    assert_not missing_amount.valid?
    assert_includes missing_amount.errors[:loan_amount], "can't be blank"

    missing_payment = Calculators::Loan.new(mode: "term", loan_amount: 25000, annual_rate: 5)
    assert_not missing_payment.valid?
    assert_includes missing_payment.errors[:monthly_payment], "can't be blank"
  end

  # ----------------------------------------------------------------------------
  # Validation — positivity of the three loan figures
  # ----------------------------------------------------------------------------
  test "loan_amount must be greater than 0" do
    [ 0, -100 ].each do |bad|
      calc = Calculators::Loan.new(
        mode: "payment", loan_amount: bad, annual_rate: 5, term_months: 60
      )
      assert_not calc.valid?, "loan_amount=#{bad} should be invalid"
      assert_includes calc.errors[:loan_amount], "must be greater than 0"
    end
  end

  test "monthly_payment must be greater than 0" do
    calc = Calculators::Loan.new(
      mode: "amount", monthly_payment: 0, annual_rate: 5, term_months: 60
    )
    assert_not calc.valid?
    assert_includes calc.errors[:monthly_payment], "must be greater than 0"
  end

  test "term_months must be greater than 0" do
    calc = Calculators::Loan.new(
      mode: "payment", loan_amount: 25000, annual_rate: 5, term_months: 0
    )
    assert_not calc.valid?
    assert_includes calc.errors[:term_months], "must be greater than 0"
  end

  # ----------------------------------------------------------------------------
  # Validation — term mode: payment too small to amortize
  # ----------------------------------------------------------------------------
  test "term mode rejects a payment that never amortizes the loan (M <= P·r)" do
    # 100000 @ 6% → P·r = 100000 × 0.005 = 500; a 400 payment never repays.
    calc = Calculators::Loan.new(
      mode: "term", loan_amount: 100000, monthly_payment: 400, annual_rate: 6
    )
    assert_not calc.valid?
    assert_includes calc.errors[:monthly_payment],
      "is too small to ever repay the loan at this rate"
    assert_nil calc.result
  end

  test "term mode accepts a payment exactly above the first month's interest" do
    # P·r = 500; a 501 payment does (barely) amortize, so it must be valid.
    calc = Calculators::Loan.new(
      mode: "term", loan_amount: 100000, monthly_payment: 501, annual_rate: 6
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_operator calc.result[:term_months], :>, 0
  end

  test "the amortize guard does not fire at zero rate (every payment is pure principal)" do
    calc = Calculators::Loan.new(
      mode: "term", loan_amount: 10000, monthly_payment: "500.00", annual_rate: 0
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal 20, calc.result[:term_months]
  end

  test "the amortize guard is skipped when the required term-mode figures are missing" do
    # Both required figures absent → only the presence errors fire, no amortize error.
    calc = Calculators::Loan.new(mode: "term", annual_rate: 5)
    assert_not calc.valid?
    assert_empty calc.errors[:monthly_payment].grep(/too small/)
  end

  # ----------------------------------------------------------------------------
  # Validation — Base numeric coercion guard (#109/#110)
  # ----------------------------------------------------------------------------
  test "a fractional term_months is rejected, not silently truncated (#109)" do
    calc = Calculators::Loan.new(
      mode: "payment", loan_amount: 25000, annual_rate: 5, term_months: "3.5"
    )
    assert_not calc.valid?
    assert_includes calc.errors[:term_months], "must be a whole number"
    assert_nil calc.result
  end

  test "a non-numeric loan_amount is rejected as not-a-number (#110)" do
    calc = Calculators::Loan.new(
      mode: "payment", loan_amount: "abc", annual_rate: 5, term_months: 60
    )
    assert_not calc.valid?
    assert_includes calc.errors[:loan_amount], "is not a number"
    assert_nil calc.result
  end

  test "scientific-notation decimal input is accepted (#109)" do
    calc = Calculators::Loan.new(
      mode: "payment", loan_amount: "2.5e4", annual_rate: 5, term_months: 60
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    # 2.5e4 == 25000 → the reference payment.
    assert_equal "471.78", calc.result[:monthly_payment]
  end

  # ----------------------------------------------------------------------------
  # Envelope/contract surface
  # ----------------------------------------------------------------------------
  test "to_calculation records the slug, inputs and result" do
    calc = Calculators::Loan.new(
      mode: "payment", loan_amount: 25000, annual_rate: 5, term_months: 60
    )
    record = calc.to_calculation
    assert_equal "loan", record.calculator
    assert_equal "payment", record.inputs["mode"]
    assert_equal BigDecimal("25000"), BigDecimal(record.inputs["loan_amount"].to_s)
    assert_equal 60, record.result["schedule"].length
  end
end
