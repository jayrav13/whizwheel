require "test_helper"

# Reference-value + validation tests for Calculators::Vat (spec issue #245).
# The reference table is lifted verbatim from the spec's "Reference values"
# section — it pins correctness and must reproduce exactly (ARCHITECTURE.md §11).
class Calculators::VatTest < ActiveSupport::TestCase
  # --- Reference values (spec §"Reference values"). Money to the cent, rate to
  #     4 dp, both as fixed-width strings. Each row supplies the two figures its
  #     mode is GIVEN and leaves the solved-for figure blank. ---
  # [ mode, net_price, gross_price, rate => expected net, gross, rate, vat ]
  [
    [ "gross", 10.00, nil,   10,    "10.00", "11.00", "10.0000", "1.00" ],
    [ "gross", 49.99, nil,   7.25,  "49.99", "53.61", "7.2500",  "3.62" ],
    [ "net",   nil,   11.00, 10,    "10.00", "11.00", "10.0000", "1.00" ],
    [ "rate",  10.00, 11.00, nil,   "10.00", "11.00", "10.0000", "1.00" ]
  ].each do |mode, net_in, gross_in, rate_in, net_out, gross_out, rate_out, vat_out|
    test "#{mode}: net=#{net_in.inspect} gross=#{gross_in.inspect} rate=#{rate_in.inspect} -> net #{net_out} gross #{gross_out} rate #{rate_out} vat #{vat_out}" do
      calc = Calculators::Vat.new(
        mode: mode, net_price: net_in, gross_price: gross_in, rate: rate_in
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      assert_equal mode,      calc.result[:mode]
      assert_equal net_out,   calc.result[:net_price], "net_price"
      assert_equal gross_out, calc.result[:gross_price], "gross_price"
      assert_equal rate_out,  calc.result[:rate], "rate"
      assert_equal vat_out,   calc.result[:vat_amount], "vat_amount"
    end
  end

  # --- The result always carries all five contract keys (the §4 result shape). ---
  test "result always carries all five keys" do
    result = Calculators::Vat.new(mode: "gross", net_price: 10, rate: 10).result
    assert_equal %i[mode net_price gross_price rate vat_amount].sort, result.keys.sort
  end

  # --- Cross-mode consistency: the same triple (net 10, gross 11, rate 10)
  #     entered three ways must agree on every figure. ---
  test "gross / net / rate modes agree on the same 10/11/10% figure" do
    by_gross = Calculators::Vat.new(mode: "gross", net_price: 10, rate: 10).result
    by_net   = Calculators::Vat.new(mode: "net", gross_price: 11, rate: 10).result
    by_rate  = Calculators::Vat.new(mode: "rate", net_price: 10, gross_price: 11).result
    [ by_net, by_rate ].each do |other|
      assert_equal by_gross[:net_price], other[:net_price]
      assert_equal by_gross[:gross_price], other[:gross_price]
      assert_equal by_gross[:rate], other[:rate]
      assert_equal by_gross[:vat_amount], other[:vat_amount]
    end
  end

  # --- Full-precision compute, rounded only for display. ---
  test "money is computed at full precision and rounded half-up to the cent" do
    # net 49.99 × 7.25% = 3.624275 → 3.62 (rounds down); gross 49.99 + 3.62 = 53.61.
    calc = Calculators::Vat.new(mode: "gross", net_price: 49.99, rate: 7.25)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "3.62", calc.result[:vat_amount]
    assert_equal "53.61", calc.result[:gross_price]
  end

  test "rate is rounded half-up to four decimal places" do
    # net 12, gross 14 → vat 2; rate = 2/12 × 100 = 16.6666…% → 16.6667.
    calc = Calculators::Vat.new(mode: "rate", net_price: 12, gross_price: 14)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "16.6667", calc.result[:rate]
    assert_equal "2.00", calc.result[:vat_amount]
  end

  test "money strings always carry exactly two decimal places" do
    # A whole-dollar result must still render N.00, not N.0 or N.
    calc = Calculators::Vat.new(mode: "gross", net_price: 100, rate: 0)
    assert_equal "100.00", calc.result[:net_price]
    assert_equal "100.00", calc.result[:gross_price]
    assert_equal "0.00",   calc.result[:vat_amount]
    assert_equal "0.0000", calc.result[:rate]
  end

  # --- mode validation ---
  test "mode is required" do
    calc = Calculators::Vat.new(mode: nil, net_price: 10, rate: 10)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "can't be blank"
    assert_nil calc.result
  end

  test "mode must be one of the three known modes (mode=zzz)" do
    calc = Calculators::Vat.new(mode: "zzz", net_price: 10, gross_price: 11)
    assert_not calc.valid?
    assert_includes calc.errors[:mode], "is not included in the list"
    assert_nil calc.result
  end

  # --- per-mode required inputs (the two figures the mode is GIVEN) ---
  {
    "gross" => %i[net_price rate],
    "net"   => %i[gross_price rate],
    "rate"  => %i[net_price gross_price]
  }.each do |mode, required|
    test "#{mode} mode requires #{required.join(' and ')}" do
      calc = Calculators::Vat.new(mode: mode)
      assert_not calc.valid?
      required.each { |field| assert_includes calc.errors[field], "can't be blank" }
      assert_nil calc.result
    end
  end

  test "fields not named by the mode are not required" do
    # gross mode needs only net_price + rate; gross_price left blank is fine.
    calc = Calculators::Vat.new(mode: "gross", net_price: 10, rate: 10)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "11.00", calc.result[:gross_price]
  end

  # --- numericality bounds ---
  test "gross mode rejects net_price = 0 (must be greater than 0)" do
    calc = Calculators::Vat.new(mode: "gross", net_price: 0, rate: 10)
    assert_not calc.valid?
    assert_includes calc.errors[:net_price], "must be greater than 0"
    assert_nil calc.result
  end

  test "gross mode requires rate (rate blank is invalid)" do
    calc = Calculators::Vat.new(mode: "gross", net_price: 10, rate: nil)
    assert_not calc.valid?
    assert_includes calc.errors[:rate], "can't be blank"
    assert_nil calc.result
  end

  test "rate mode requires gross_price (gross blank is invalid)" do
    calc = Calculators::Vat.new(mode: "rate", net_price: 10, gross_price: nil)
    assert_not calc.valid?
    assert_includes calc.errors[:gross_price], "can't be blank"
    assert_nil calc.result
  end

  test "net mode accepts rate = 0 (valid: net = gross, vat = 0.00)" do
    calc = Calculators::Vat.new(mode: "net", gross_price: 50, rate: 0)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "50.00", calc.result[:net_price]
    assert_equal "50.00", calc.result[:gross_price]
    assert_equal "0.00",  calc.result[:vat_amount]
    assert_equal "0.0000", calc.result[:rate]
  end

  # --- rate mode: gross must be ≥ net (non-negative VAT) ---
  test "rate mode rejects gross < net (negative VAT)" do
    calc = Calculators::Vat.new(mode: "rate", net_price: 10, gross_price: 9)
    assert_not calc.valid?
    assert_includes calc.errors[:gross_price], "must be greater than or equal to the net price"
    assert_nil calc.result
  end

  test "rate mode accepts gross == net (zero VAT, rate 0)" do
    calc = Calculators::Vat.new(mode: "rate", net_price: 10, gross_price: 10)
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "0.00",   calc.result[:vat_amount]
    assert_equal "0.0000", calc.result[:rate]
  end

  # --- the negative-VAT guard is scoped to rate mode only ---
  test "non-rate modes are unaffected by the gross >= net guard" do
    # A net mode with a small gross is fine — net is solved below it, not checked.
    calc = Calculators::Vat.new(mode: "net", gross_price: 5, rate: 20)
    assert calc.valid?, calc.errors.full_messages.to_sentence
  end

  # --- Base coercion guard (#110): a non-numeric input is rejected, not coerced. ---
  test "a non-numeric input is rejected by the Base numeric guard (net = 'x')" do
    calc = Calculators::Vat.new(mode: "gross", net_price: "x", rate: 10)
    assert_not calc.valid?
    assert_includes calc.errors[:net_price], "is not a number"
    assert_nil calc.result
  end

  test "numeric strings are accepted and coerced to exact BigDecimal" do
    calc = Calculators::Vat.new(mode: "gross", net_price: "10.00", rate: "10")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "11.00", calc.result[:gross_price]
    assert_equal "1.00",  calc.result[:vat_amount]
  end

  # --- envelope/contract surface ---
  test "to_calculation records the slug, inputs and the full result set" do
    calc = Calculators::Vat.new(mode: "gross", net_price: 10, rate: 10)
    record = calc.to_calculation
    assert_equal "vat", record.calculator
    assert_equal "gross", record.inputs["mode"]
    assert_equal "11.00", record.result["gross_price"]
    assert_equal "1.00",  record.result["vat_amount"]
  end
end
