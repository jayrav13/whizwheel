require "test_helper"

# Reference-value + validation tests for Calculators::SalesTax (spec issue #242).
# The reference and edge tables below are lifted verbatim from the spec — they pin
# correctness and must reproduce exactly (ARCHITECTURE.md §11).
class Calculators::SalesTaxTest < ActiveSupport::TestCase
  # ── Reference values ──────────────────────────────────────────────────────
  # Each row supplies the two figures its mode is given and solves for the third.
  # Money rounds to the cent half-up; rate to 4 dp half-up. The blank (solved-for)
  # field is passed as nil.
  #
  # [ mode, before_in, after_in, rate_in => before_out, after_out, rate_out, tax_out ]
  [
    [ "after",  100.00, nil,    6,    "100.00", "106.00", "6.0000", "6.00" ],
    [ "after",  49.99,  nil,    7.25, "49.99",  "53.61",  "7.2500", "3.62" ],
    [ "before", nil,    106.00, 6,    "100.00", "106.00", "6.0000", "6.00" ],
    [ "rate",   100.00, 106.00, nil,  "100.00", "106.00", "6.0000", "6.00" ]
  ].each do |mode, before_in, after_in, rate_in, before_out, after_out, rate_out, tax_out|
    test "#{mode}: B=#{before_in.inspect} A=#{after_in.inspect} rate=#{rate_in.inspect} -> B#{before_out} A#{after_out} r#{rate_out} tax#{tax_out}" do
      calc = Calculators::SalesTax.new(
        mode: mode, before_tax_price: before_in, after_tax_price: after_in, rate: rate_in
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal mode, calc.result[:mode]
      assert_equal BigDecimal(before_out), calc.result[:before_tax_price], "before_tax_price"
      assert_equal BigDecimal(after_out),  calc.result[:after_tax_price],  "after_tax_price"
      assert_equal BigDecimal(rate_out),   calc.result[:rate],             "rate"
      assert_equal BigDecimal(tax_out),    calc.result[:tax_amount],       "tax_amount"
    end
  end

  # ── The same problem entered three ways agrees on the operating point ──────
  test "after / before / rate agree on the same B=100 / A=106 / rate=6 problem" do
    by_after  = Calculators::SalesTax.new(mode: "after",  before_tax_price: 100, rate: 6).result
    by_before = Calculators::SalesTax.new(mode: "before", after_tax_price: 106, rate: 6).result
    by_rate   = Calculators::SalesTax.new(mode: "rate",   before_tax_price: 100, after_tax_price: 106).result

    [ by_before, by_rate ].each do |other|
      assert_equal by_after[:before_tax_price], other[:before_tax_price]
      assert_equal by_after[:after_tax_price],  other[:after_tax_price]
      assert_equal by_after[:rate],             other[:rate]
      assert_equal by_after[:tax_amount],       other[:tax_amount]
    end
  end

  # ── The result always carries all five keys (the §4 result shape) ──────────
  test "result always carries all five keys" do
    result = Calculators::SalesTax.new(mode: "after", before_tax_price: 100, rate: 6).result
    assert_equal %i[mode before_tax_price after_tax_price rate tax_amount].sort, result.keys.sort
  end

  # ── Full-precision compute, displayed rounding ─────────────────────────────
  test "the after-tax price derives from the raw (unrounded) tax, then rounds for display" do
    # B=49.99, rate=7.25: raw tax = 3.624275 -> 3.62; after = 53.614275 -> 53.61.
    calc = Calculators::SalesTax.new(mode: "after", before_tax_price: "49.99", rate: "7.25")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("3.62"),  calc.result[:tax_amount]
    assert_equal BigDecimal("53.61"), calc.result[:after_tax_price]
  end

  test "rate is reported to four decimal places" do
    # B=80, A=86: rate = 6/80 * 100 = 7.5 -> 7.5000.
    calc = Calculators::SalesTax.new(mode: "rate", before_tax_price: 80, after_tax_price: 86)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("7.5000"), calc.result[:rate]
    assert_equal BigDecimal("6.00"),   calc.result[:tax_amount]
  end

  test "before mode solves the before-tax price exactly from a clean after/rate" do
    # A=215, rate=7.5: B = 215 / 1.075 = 200; tax = 15.
    calc = Calculators::SalesTax.new(mode: "before", after_tax_price: 215, rate: 7.5)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("200.00"), calc.result[:before_tax_price]
    assert_equal BigDecimal("15.00"),  calc.result[:tax_amount]
  end

  # ── mode validation ───────────────────────────────────────────────────────
  test "mode is required" do
    calc = Calculators::SalesTax.new(mode: nil)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "can't be blank"
    assert_nil calc.result
  end

  test "mode must be one of the three known modes" do
    calc = Calculators::SalesTax.new(mode: "zzz", before_tax_price: 100, rate: 6)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "is not included in the list"
    assert_nil calc.result
  end

  # ── per-mode required inputs (the two figures the mode is given) ───────────
  {
    "after"  => %i[before_tax_price rate],
    "before" => %i[after_tax_price rate],
    "rate"   => %i[before_tax_price after_tax_price]
  }.each do |mode, required|
    test "#{mode} requires #{required.join(' and ')}" do
      calc = Calculators::SalesTax.new(mode: mode)
      assert_not calc.valid?
      required.each { |field| assert_includes calc.errors[field], "can't be blank" }
    end
  end

  test "a figure the mode does not name is ignored, not required" do
    # after needs only before_tax_price + rate; a blank after_tax_price is fine.
    calc = Calculators::SalesTax.new(mode: "after", before_tax_price: 100, rate: 6)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("106.00"), calc.result[:after_tax_price]
  end

  # ── numericality / range rules ────────────────────────────────────────────
  test "before mode accepts a zero rate (tax = 0, before = after)" do
    # Spec edge: mode=before, after=50, rate=0 -> before = 50.00, tax = 0.00.
    calc = Calculators::SalesTax.new(mode: "before", after_tax_price: 50, rate: 0)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("50.00"), calc.result[:before_tax_price]
    assert_equal BigDecimal("0.00"),  calc.result[:tax_amount]
  end

  test "after mode rejects a zero before-tax price (must be > 0)" do
    calc = Calculators::SalesTax.new(mode: "after", before_tax_price: 0, rate: 6)
    assert_not calc.valid?
    assert_includes calc.errors[:before_tax_price], "must be greater than 0"
    assert_nil calc.result
  end

  test "after mode rejects a blank rate (required for this mode)" do
    calc = Calculators::SalesTax.new(mode: "after", before_tax_price: 100, rate: nil)
    assert_not calc.valid?
    assert_includes calc.errors[:rate], "can't be blank"
    assert_nil calc.result
  end

  test "after mode rejects a negative rate" do
    calc = Calculators::SalesTax.new(mode: "after", before_tax_price: 100, rate: -1)
    assert_not calc.valid?
    assert_includes calc.errors[:rate], "must be greater than or equal to 0"
  end

  test "rate mode rejects an after-tax price below the before-tax price (negative tax)" do
    # Spec edge: mode=rate, before=100, after=90 -> invalid (negative tax).
    calc = Calculators::SalesTax.new(mode: "rate", before_tax_price: 100, after_tax_price: 90)
    assert_not calc.valid?
    assert_includes calc.errors[:after_tax_price], "must be greater than or equal to 100.0"
    assert_nil calc.result
  end

  test "rate mode rejects a blank after-tax price (required for rate mode)" do
    calc = Calculators::SalesTax.new(mode: "rate", before_tax_price: 100, after_tax_price: nil)
    assert_not calc.valid?
    assert_includes calc.errors[:after_tax_price], "can't be blank"
    assert_nil calc.result
  end

  test "rate mode accepts an after equal to before (zero tax, zero rate)" do
    calc = Calculators::SalesTax.new(mode: "rate", before_tax_price: 100, after_tax_price: 100)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("0.0000"), calc.result[:rate]
    assert_equal BigDecimal("0.00"),   calc.result[:tax_amount]
  end

  # ── Base coercion guard (#110) ────────────────────────────────────────────
  test "a non-numeric figure is rejected by the Base coercion guard" do
    # Spec edge: mode=after, before = "x" -> invalid (not a number). The :decimal
    # cast would turn "x" into BigDecimal(0); Base inspects the RAW value first.
    calc = Calculators::SalesTax.new(mode: "after", before_tax_price: "x", rate: 6)
    assert_not calc.valid?
    assert_includes calc.errors[:before_tax_price], "is not a number"
    assert_nil calc.result
  end

  test "numeric strings are accepted and coerced to exact BigDecimal" do
    calc = Calculators::SalesTax.new(mode: "after", before_tax_price: "100.00", rate: "6")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal BigDecimal("106.00"), calc.result[:after_tax_price]
    assert_equal BigDecimal("6.00"),   calc.result[:tax_amount]
  end

  # ── envelope/contract surface ─────────────────────────────────────────────
  test "to_calculation records the slug, inputs and the full result set" do
    calc = Calculators::SalesTax.new(mode: "after", before_tax_price: 100, rate: 6)
    record = calc.to_calculation
    assert_equal "sales_tax", record.calculator
    assert_equal "after", record.inputs["mode"]
    # jsonb stringifies hash keys/values on assignment.
    assert_equal BigDecimal("106.00"), BigDecimal(record.result["after_tax_price"].to_s)
    assert_equal BigDecimal("6.00"),   BigDecimal(record.result["tax_amount"].to_s)
  end
end
