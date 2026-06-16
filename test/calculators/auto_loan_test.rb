require "test_helper"

# Reference-value + validation tests for Calculators::AutoLoan (spec issue #241) — an
# amortized fixed-rate auto loan built on the same amortized-payment core as Loan, with
# the auto-specific adjustments (trade-in, down payment, sales tax, fees) folded into the
# amount financed. The reference table is lifted verbatim from the spec's "Reference
# values" section; it pins correctness and must reproduce exactly (ARCHITECTURE.md §11).
# The suite also asserts the schedule shape (length, the month-1 anchor breakdown, the
# final row clearing to 0.00) and that the schedule reconciles to the summary totals.
class Calculators::AutoLoanTest < ActiveSupport::TestCase
  # ----------------------------------------------------------------------------
  # Reference values (spec §"Reference values").
  # total_paid / total_interest are the SCHEDULE-RECONCILED sums (Σ over the rows,
  # the final row absorbing rounding), not monthly_payment × n.
  # [ auto_price, term_months, annual_rate, down_payment, trade_in, sales_tax_rate, fees,
  #   sales_tax, amount_financed, monthly_payment, total_paid, total_interest ]
  # ----------------------------------------------------------------------------
  #
  # SPEC DISCREPANCY (flagged in the PR): row 2's spec total_paid/total_interest
  # (27618.24 / 3118.24) equal monthly_payment × n (575.38 × 48), NOT the
  # schedule-reconciled Σ — which contradicts the spec's own stated rule
  # ("…the schedule-reconciled sums … NOT monthly_payment × n") and its authoritative
  # row-1 anchor (25453.48 / 2973.48, which IS schedule-reconciled and matches exactly).
  # Row 2's `*`-flagged figures were computed as M×n. We pin the SPEC-AUTHORITATIVE
  # schedule-reconciled values (27618.41 / 3118.41) so the calculator stays consistent
  # with the documented methodology and the row-1 anchor; the M×n figures are a PM
  # computation slip to correct in the spec.
  REFERENCE = [
    [ 30000, 60, 5, 4000, 6000, 7, 800, "1680.00", "22480.00", "424.23", "25453.48", "2973.48" ],
    [ 25000, 48, 6, 3000, 0,    8, 500, "2000.00", "24500.00", "575.38", "27618.41", "3118.41" ],
    [ 20000, 36, 0, 2000, 0,    0, 0,   "0.00",    "18000.00", "500.00", "18000.00", "0.00" ]
  ].freeze

  REFERENCE.each do |price, term, rate, down, trade, tax_rate, fees,
    sales_tax, financed, payment, total, interest|
    test "auto_price #{price} / #{term}mo @ #{rate}% (down #{down}, trade #{trade}, tax #{tax_rate}%, fees #{fees}) -> payment #{payment}" do
      calc = Calculators::AutoLoan.new(
        auto_price: price, term_months: term, annual_rate: rate,
        down_payment: down, trade_in: trade, sales_tax_rate: tax_rate, fees: fees
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result

      assert_equal sales_tax, result[:sales_tax],       "sales_tax"
      assert_equal financed,  result[:amount_financed], "amount_financed"
      assert_equal payment,   result[:monthly_payment], "monthly_payment"
      assert_equal total,     result[:total_paid],      "total_paid"
      assert_equal interest,  result[:total_interest],  "total_interest"
      assert_equal term,      result[:number_of_payments], "number_of_payments"

      # --- schedule shape ---
      schedule = result[:schedule]
      assert_equal term, schedule.length, "schedule length == number_of_payments"
      assert_equal "0.00", schedule.last[:balance], "final-row balance"

      # --- reconciliation: Σ over the rows == the summary totals ---
      sum_interest = schedule.sum { |row| BigDecimal(row[:interest]) }
      sum_payment  = schedule.sum { |row| BigDecimal(row[:payment]) }
      assert_equal BigDecimal(interest), sum_interest, "Σ interest == total_interest"
      assert_equal BigDecimal(total),    sum_payment,  "Σ payment == total_paid"
      # total_paid == amount_financed + total_interest
      assert_equal BigDecimal(financed) + BigDecimal(interest), BigDecimal(total)
    end
  end

  # The spec's row-1 month-1 breakdown anchor (30000 / 60mo @ 5%, down 4000, trade 6000,
  # tax 7%, fees 800 → amount_financed 22480.00, payment 424.23).
  test "row-1 schedule month-1 matches the spec anchor" do
    schedule = Calculators::AutoLoan.new(
      auto_price: 30000, term_months: 60, annual_rate: 5,
      down_payment: 4000, trade_in: 6000, sales_tax_rate: 7, fees: 800
    ).result[:schedule]

    first = schedule.first
    assert_equal 1,          first[:month]
    assert_equal "424.23",   first[:payment],   "month-1 payment (the level payment)"
    assert_equal "93.67",    first[:interest],  "month-1 interest"
    assert_equal "330.56",   first[:principal], "month-1 principal"
    assert_equal "22149.44", first[:balance],   "month-1 balance"
  end

  # ----------------------------------------------------------------------------
  # Optional inputs omitted → treated as 0 (the #213 defaulted-numeric path).
  # amount_financed == auto_price, sales_tax == 0.00.
  # ----------------------------------------------------------------------------
  test "omitted down/trade/tax/fees are treated as 0" do
    calc = Calculators::AutoLoan.new(auto_price: 20000, term_months: 36, annual_rate: 0)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    result = calc.result

    assert_equal "0.00",     result[:sales_tax]
    assert_equal "20000.00", result[:amount_financed]
    # r = 0 → M = 20000 / 36, rounded to the cent.
    assert_equal "555.56",   result[:monthly_payment]
  end

  test "a blank-string optional numeric behaves like the default 0 (#213)" do
    calc = Calculators::AutoLoan.new(
      auto_price: 20000, term_months: 36, annual_rate: 0,
      down_payment: "", trade_in: "", sales_tax_rate: "", fees: ""
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "20000.00", calc.result[:amount_financed]
  end

  # ----------------------------------------------------------------------------
  # Precision: string inputs coerce to exact BigDecimal (no float drift)
  # ----------------------------------------------------------------------------
  test "string inputs are coerced to exact BigDecimal" do
    calc = Calculators::AutoLoan.new(
      auto_price: "30000", term_months: "60", annual_rate: "5",
      down_payment: "4000", trade_in: "6000", sales_tax_rate: "7", fees: "800"
    )
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "424.23", calc.result[:monthly_payment]
  end

  # ----------------------------------------------------------------------------
  # Schedule formatting / shape invariants
  # ----------------------------------------------------------------------------
  test "all schedule money fields are exactly two-decimal strings; month is an Integer" do
    schedule = Calculators::AutoLoan.new(
      auto_price: 30000, term_months: 60, annual_rate: 5,
      down_payment: 4000, trade_in: 6000, sales_tax_rate: 7, fees: 800
    ).result[:schedule]

    schedule.each do |row|
      %i[payment interest principal balance].each do |key|
        assert_match(/\A-?\d+\.\d{2}\z/, row[key], "#{key} = #{row[key].inspect}")
      end
      assert_kind_of Integer, row[:month]
    end
  end

  test "non-final rows all carry the level monthly payment" do
    result = Calculators::AutoLoan.new(
      auto_price: 30000, term_months: 60, annual_rate: 5,
      down_payment: 4000, trade_in: 6000, sales_tax_rate: 7, fees: 800
    ).result
    level = result[:monthly_payment]
    result[:schedule][0..-2].each do |row|
      assert_equal level, row[:payment], "row #{row[:month]} payment"
    end
  end

  test "result carries exactly the spec's output keys" do
    result = Calculators::AutoLoan.new(
      auto_price: 30000, term_months: 60, annual_rate: 5
    ).result
    expected = %i[
      amount_financed sales_tax monthly_payment
      total_paid total_interest number_of_payments schedule
    ]
    assert_equal expected.sort, result.keys.sort
  end

  test "schedule rows carry exactly month/payment/interest/principal/balance" do
    row = Calculators::AutoLoan.new(
      auto_price: 20000, term_months: 36, annual_rate: 0
    ).result[:schedule].first
    assert_equal %i[month payment interest principal balance], row.keys
  end

  # ----------------------------------------------------------------------------
  # Validation — required fields
  # ----------------------------------------------------------------------------
  test "auto_price must be greater than 0" do
    [ 0, -100 ].each do |bad|
      calc = Calculators::AutoLoan.new(auto_price: bad, term_months: 60, annual_rate: 5)
      assert_not calc.valid?, "auto_price=#{bad} should be invalid"
      assert_includes calc.errors[:auto_price], "must be greater than 0"
    end
  end

  test "auto_price is required" do
    calc = Calculators::AutoLoan.new(term_months: 60, annual_rate: 5)
    assert_not calc.valid?
    assert_includes calc.errors[:auto_price], "can't be blank"
    assert_nil calc.result
  end

  test "term_months must be greater than 0" do
    calc = Calculators::AutoLoan.new(auto_price: 20000, term_months: 0, annual_rate: 5)
    assert_not calc.valid?
    assert_includes calc.errors[:term_months], "must be greater than 0"
  end

  test "term_months is required" do
    calc = Calculators::AutoLoan.new(auto_price: 20000, annual_rate: 5)
    assert_not calc.valid?
    assert_includes calc.errors[:term_months], "can't be blank"
  end

  test "annual_rate is required" do
    calc = Calculators::AutoLoan.new(auto_price: 20000, term_months: 60)
    assert_not calc.valid?
    assert_includes calc.errors[:annual_rate], "can't be blank"
  end

  test "annual_rate must be >= 0 (negative rejected, zero accepted)" do
    neg = Calculators::AutoLoan.new(auto_price: 20000, term_months: 36, annual_rate: -1)
    assert_not neg.valid?
    assert_includes neg.errors[:annual_rate], "must be greater than or equal to 0"

    zero = Calculators::AutoLoan.new(auto_price: 20000, term_months: 36, annual_rate: 0)
    assert zero.valid?, zero.errors.full_messages.to_sentence
  end

  test "the optional money inputs must be >= 0" do
    %i[down_payment trade_in sales_tax_rate fees].each do |field|
      calc = Calculators::AutoLoan.new(
        auto_price: 20000, term_months: 36, annual_rate: 5, field => -1
      )
      assert_not calc.valid?, "#{field}=-1 should be invalid"
      assert_includes calc.errors[field], "must be greater than or equal to 0"
    end
  end

  # ----------------------------------------------------------------------------
  # Validation — the amount-financed-positive guard
  # ----------------------------------------------------------------------------
  test "a trade-in + down payment exceeding the taxed price is rejected (amount financed <= 0)" do
    # auto 10000, down 5000, trade 6000, no tax/fees → financed = 10000 − 5000 − 6000 = −1000.
    calc = Calculators::AutoLoan.new(
      auto_price: 10000, term_months: 60, annual_rate: 5,
      down_payment: 5000, trade_in: 6000, sales_tax_rate: 0, fees: 0
    )
    assert_not calc.valid?
    assert_includes calc.errors[:base], "amount financed must be greater than 0"
    assert_nil calc.result
  end

  test "amount financed exactly zero is rejected (must be strictly positive)" do
    # auto 6000, trade 6000 → financed = 0.
    calc = Calculators::AutoLoan.new(
      auto_price: 6000, term_months: 60, annual_rate: 5, trade_in: 6000
    )
    assert_not calc.valid?
    assert_includes calc.errors[:base], "amount financed must be greater than 0"
  end

  test "the amount-financed guard is skipped while a required figure is missing" do
    # auto_price absent → only the presence error fires, no base amount-financed error.
    calc = Calculators::AutoLoan.new(term_months: 60, annual_rate: 5)
    assert_not calc.valid?
    assert_empty calc.errors[:base]
  end

  test "the amount-financed guard is skipped when an optional figure is non-numeric" do
    # trade_in non-numeric → its numeric guard owns it; the amount-financed guard does
    # not run (trade_in casts to nil, so it is not present).
    calc = Calculators::AutoLoan.new(
      auto_price: 20000, term_months: 60, annual_rate: 5, trade_in: "abc"
    )
    assert_not calc.valid?
    assert_includes calc.errors[:trade_in], "is not a number"
    assert_empty calc.errors[:base]
  end

  # ----------------------------------------------------------------------------
  # Validation — Base numeric coercion guard (#109/#110)
  # ----------------------------------------------------------------------------
  test "a fractional term_months is rejected, not silently truncated (#109)" do
    calc = Calculators::AutoLoan.new(
      auto_price: 20000, term_months: "60.5", annual_rate: 5
    )
    assert_not calc.valid?
    assert_includes calc.errors[:term_months], "must be a whole number"
    assert_nil calc.result
  end

  test "a non-numeric annual_rate is rejected as not-a-number (#110)" do
    calc = Calculators::AutoLoan.new(
      auto_price: 20000, term_months: 60, annual_rate: "x"
    )
    assert_not calc.valid?
    assert_includes calc.errors[:annual_rate], "is not a number"
    assert_nil calc.result
  end

  test "a non-numeric auto_price is rejected as not-a-number (#110)" do
    calc = Calculators::AutoLoan.new(
      auto_price: "abc", term_months: 60, annual_rate: 5
    )
    assert_not calc.valid?
    assert_includes calc.errors[:auto_price], "is not a number"
  end

  # ----------------------------------------------------------------------------
  # Envelope/contract surface
  # ----------------------------------------------------------------------------
  test "to_calculation records the slug, inputs and result" do
    calc = Calculators::AutoLoan.new(
      auto_price: 30000, term_months: 60, annual_rate: 5,
      down_payment: 4000, trade_in: 6000, sales_tax_rate: 7, fees: 800
    )
    record = calc.to_calculation
    assert_equal "auto_loan", record.calculator
    assert_equal BigDecimal("30000"), BigDecimal(record.inputs["auto_price"].to_s)
    assert_equal 60, record.result["schedule"].length
    assert_equal "22480.00", record.result["amount_financed"]
  end
end
