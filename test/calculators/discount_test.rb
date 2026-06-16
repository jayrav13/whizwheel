require "test_helper"

# Reference-value + validation tests for Calculators::Discount (spec issue #244).
# The reference table below is lifted verbatim from the spec's "Reference values"
# section — it pins correctness and must reproduce exactly (ARCHITECTURE.md §11).
class Calculators::DiscountTest < ActiveSupport::TestCase
  # --- Reference values ---
  # | mode    | original_price | percent_off | amount_off | amount_saved | final_price |
  [
    [ "percent", "45.00",  "10", nil,     "4.50",  "40.50"  ],
    [ "percent", "199.99", "25", nil,     "50.00", "149.99" ],
    [ "fixed",   "80.00",  nil,  "15.00", "15.00", "65.00"  ],
    [ "percent", "50.00",  "0",  nil,     "0.00",  "50.00"  ]
  ].each do |mode, original_price, percent_off, amount_off, amount_saved, final_price|
    test "#{mode}: #{original_price} (pct=#{percent_off.inspect} amt=#{amount_off.inspect}) -> saved #{amount_saved}, final #{final_price}" do
      calc = Calculators::Discount.new(
        mode: mode,
        original_price: original_price,
        percent_off: percent_off,
        amount_off: amount_off
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result
      assert_equal mode, result[:mode]
      assert_equal original_price, result[:original_price]
      assert_equal amount_saved, result[:amount_saved]
      assert_equal final_price, result[:final_price]
    end
  end

  # --- Money is always a two-decimal string, half-up to the cent ---
  test "money output is a two-decimal string padded with trailing zeros" do
    calc = Calculators::Discount.new(mode: "percent", original_price: "100", percent_off: "20")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "100.00", calc.result[:original_price]
    assert_equal "20.00", calc.result[:amount_saved]
    assert_equal "80.00", calc.result[:final_price]
  end

  test "money rounds half-up to the cent" do
    # 199.99 × 25% = 49.9975 -> 50.00 (half-up); confirms the rounding direction.
    calc = Calculators::Discount.new(mode: "percent", original_price: "199.99", percent_off: "25")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "50.00", calc.result[:amount_saved]
  end

  test "amount_off equal to original price gives a zero final price (fixed)" do
    calc = Calculators::Discount.new(mode: "fixed", original_price: "80", amount_off: "80")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "0.00", calc.result[:final_price]
    assert_equal "80.00", calc.result[:amount_saved]
  end

  # --- Edge / validation cases (from the spec's table) ---

  test "percent mode with original_price = 0 is invalid (greater than 0)" do
    calc = Calculators::Discount.new(mode: "percent", original_price: "0", percent_off: "10")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :original_price
    assert_nil calc.result
  end

  test "percent mode with percent_off = 120 is invalid (<= 100)" do
    calc = Calculators::Discount.new(mode: "percent", original_price: "45", percent_off: "120")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :percent_off
  end

  test "percent mode with percent_off below zero is invalid" do
    calc = Calculators::Discount.new(mode: "percent", original_price: "45", percent_off: "-5")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :percent_off
  end

  test "percent mode with blank percent_off is invalid (required for percent mode)" do
    calc = Calculators::Discount.new(mode: "percent", original_price: "45", percent_off: "")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :percent_off
  end

  test "fixed mode with amount_off > original_price is invalid (amount off <= original price)" do
    calc = Calculators::Discount.new(mode: "fixed", original_price: "80", amount_off: "100")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :amount_off
  end

  test "fixed mode with negative amount_off is invalid" do
    calc = Calculators::Discount.new(mode: "fixed", original_price: "80", amount_off: "-5")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :amount_off
  end

  test "fixed mode with blank amount_off is invalid (required for fixed mode)" do
    calc = Calculators::Discount.new(mode: "fixed", original_price: "80", amount_off: "")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :amount_off
  end

  test "unknown mode is invalid (not in inclusion list)" do
    calc = Calculators::Discount.new(mode: "zzz", original_price: "80", amount_off: "10")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :mode
  end

  test "blank mode is invalid (presence)" do
    calc = Calculators::Discount.new(mode: "", original_price: "80", amount_off: "10")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :mode
  end

  test "non-numeric original_price is rejected by the Base numeric guard" do
    calc = Calculators::Discount.new(mode: "percent", original_price: "x", percent_off: "10")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :original_price
    assert_includes calc.errors[:original_price], "is not a number"
  end

  test "blank original_price is invalid (presence)" do
    calc = Calculators::Discount.new(mode: "percent", original_price: "", percent_off: "10")
    assert_not calc.valid?
    assert_includes calc.errors.attribute_names, :original_price
  end

  # --- Slug + envelope shape ---

  test "slug is discount" do
    assert_equal "discount", Calculators::Discount.slug
  end

  test "result keys match the spec's output contract" do
    calc = Calculators::Discount.new(mode: "percent", original_price: "45", percent_off: "10")
    assert calc.valid?
    assert_equal %i[mode original_price final_price amount_saved], calc.result.keys
  end
end
