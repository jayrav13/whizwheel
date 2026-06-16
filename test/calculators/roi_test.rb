require "test_helper"

# Reference-value + validation tests for Calculators::Roi (spec issue #248).
# The reference table below is lifted verbatim from the spec's "Reference values"
# section — it pins correctness and must reproduce exactly (ARCHITECTURE.md §11).
# Money is a 2-dp half-up string; percentages are 4-dp half-up strings.
class Calculators::RoiTest < ActiveSupport::TestCase
  # --- Reference values (spec §Reference values) ---
  # invested | returned | years | total_gain | roi_percent | annualized_roi_percent
  [
    [ "50000.00", "70000.00", "5", "20000.00", "40.0000", "6.9610" ],
    [ "1000.00",  "1500.00",  "3", "500.00",   "50.0000", "14.4714" ],
    [ "10000.00", "8000.00",  nil, "-2000.00", "-20.0000", nil ]
  ].each do |invested, returned, years, total_gain, roi_percent, annualized|
    test "ROI: invested #{invested}, returned #{returned}, years #{years.inspect}" do
      calc = Calculators::Roi.new(
        amount_invested: invested, amount_returned: returned, investment_years: years
      )
      assert calc.valid?, calc.errors.full_messages.to_sentence
      result = calc.result
      assert_equal invested, result[:amount_invested]
      assert_equal returned, result[:amount_returned]
      assert_equal total_gain, result[:total_gain]
      assert_equal roi_percent, result[:roi_percent]
      if annualized.nil?
        assert_nil result[:annualized_roi_percent]
      else
        assert_equal annualized, result[:annualized_roi_percent]
      end
    end
  end

  # --- the result carries exactly the spec's five output keys ---
  test "result carries the five spec output keys" do
    result = Calculators::Roi.new(
      amount_invested: "50000", amount_returned: "70000", investment_years: "5"
    ).result
    assert_equal(
      %i[amount_invested amount_returned total_gain roi_percent annualized_roi_percent],
      result.keys
    )
  end

  # --- annualized_roi_percent is null exactly when no period is supplied ---
  test "annualized_roi_percent is null when investment_years is blank" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "1500", investment_years: "")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_nil calc.result[:annualized_roi_percent]
  end

  test "annualized_roi_percent is present when investment_years is supplied" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "1500", investment_years: "3")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "14.4714", calc.result[:annualized_roi_percent]
  end

  # --- fractional years are allowed (decimal investment_years) ---
  test "fractional investment_years are accepted" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "1500", investment_years: "1.5")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    # (1.5 ^ (1/1.5) − 1) × 100
    expected = ((BigDecimal("1.5")**(BigDecimal(1) / BigDecimal("1.5"))) - 1) * 100
    assert_equal expected.round(4, BigDecimal::ROUND_HALF_UP).to_s("F"),
                 calc.result[:annualized_roi_percent]
  end

  # --- a loss: amount_returned < amount_invested → negative gain + ROI ---
  test "a loss yields negative total_gain and roi_percent with a rendered sign" do
    calc = Calculators::Roi.new(amount_invested: "10000", amount_returned: "8000")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "-2000.00", calc.result[:total_gain]
    assert_equal "-20.0000", calc.result[:roi_percent]
  end

  test "annualized ROI is negative for a loss over a period" do
    calc = Calculators::Roi.new(amount_invested: "10000", amount_returned: "8000", investment_years: "2")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    # (0.8 ^ 0.5 − 1) × 100 ≈ −10.5573%
    assert_equal "-10.5573", calc.result[:annualized_roi_percent]
  end

  # --- a total loss (returned == 0) → −100% annualized, no ln(0) ---
  test "a total loss (returned 0) annualizes to -100% without raising" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "0", investment_years: "2")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "-1000.00", calc.result[:total_gain]
    assert_equal "-100.0000", calc.result[:roi_percent]
    assert_equal "-100.0000", calc.result[:annualized_roi_percent]
  end

  # --- break-even: returned == invested → zero gain and ROI ---
  test "break-even yields zero gain and ROI" do
    calc = Calculators::Roi.new(amount_invested: "5000", amount_returned: "5000", investment_years: "4")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "0.00", calc.result[:total_gain]
    assert_equal "0.0000", calc.result[:roi_percent]
    assert_equal "0.0000", calc.result[:annualized_roi_percent]
  end

  # --- full-precision compute (no float drift) ---
  test "computes the CAGR at BigDecimal precision (no float 33.33 truncation)" do
    # invested 1000 → returned 1500 over 3 years = 14.4714% to 4dp, exact half-up.
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "1500", investment_years: "3")
    assert_equal "14.4714", calc.result[:annualized_roi_percent]
  end

  # --- Edge / validation cases (spec §Edge / validation cases) ---
  test "amount_invested = 0 is invalid (greater than 0 — division by zero)" do
    calc = Calculators::Roi.new(amount_invested: "0", amount_returned: "100")
    assert_not calc.valid?
    assert_includes calc.errors[:amount_invested], "must be greater than 0"
    assert_nil calc.result
  end

  test "amount_invested negative is invalid (greater than 0)" do
    calc = Calculators::Roi.new(amount_invested: "-5", amount_returned: "100")
    assert_not calc.valid?
    assert_includes calc.errors[:amount_invested], "must be greater than 0"
  end

  test "amount_invested blank is invalid (presence)" do
    calc = Calculators::Roi.new(amount_invested: "", amount_returned: "100")
    assert_not calc.valid?
    assert_includes calc.errors[:amount_invested], "can't be blank"
  end

  test "amount_returned blank is invalid (presence)" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "")
    assert_not calc.valid?
    assert_includes calc.errors[:amount_returned], "can't be blank"
  end

  test "amount_returned = 0 is valid (a total loss, not invalid)" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "0")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "-1000.00", calc.result[:total_gain]
  end

  test "amount_returned negative is invalid (greater than or equal to 0)" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "-1")
    assert_not calc.valid?
    assert_includes calc.errors[:amount_returned], "must be greater than or equal to 0"
  end

  test "investment_years = 0 is invalid (greater than 0 when supplied)" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "1500", investment_years: "0")
    assert_not calc.valid?
    assert_includes calc.errors[:investment_years], "must be greater than 0"
    assert_nil calc.result
  end

  test "investment_years negative is invalid (greater than 0)" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "1500", investment_years: "-2")
    assert_not calc.valid?
    assert_includes calc.errors[:investment_years], "must be greater than 0"
  end

  test "investment_years blank is valid → annualized_roi_percent is null" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "1500", investment_years: "")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_nil calc.result[:annualized_roi_percent]
  end

  # --- Base numeric guard rejects non-numeric input (#109/#110) ---
  test "non-numeric amount_invested is rejected by the Base numeric guard" do
    calc = Calculators::Roi.new(amount_invested: "x", amount_returned: "100")
    assert_not calc.valid?
    assert_includes calc.errors[:amount_invested], "is not a number"
    assert_nil calc.result
  end

  test "non-numeric amount_returned is rejected by the Base numeric guard" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "abc")
    assert_not calc.valid?
    assert_includes calc.errors[:amount_returned], "is not a number"
  end

  test "non-numeric investment_years is rejected by the Base numeric guard" do
    calc = Calculators::Roi.new(amount_invested: "1000", amount_returned: "1500", investment_years: "soon")
    assert_not calc.valid?
    assert_includes calc.errors[:investment_years], "is not a number"
  end

  # --- scientific notation is accepted (Base guard parses, not regex) ---
  test "scientific-notation input is accepted" do
    calc = Calculators::Roi.new(amount_invested: "1e4", amount_returned: "1.5e4")
    assert calc.valid?, calc.errors.full_messages.to_sentence
    assert_equal "5000.00", calc.result[:total_gain]
    assert_equal "50.0000", calc.result[:roi_percent]
  end

  # --- envelope/contract surface ---
  test "to_calculation records the slug, inputs and result" do
    calc = Calculators::Roi.new(amount_invested: "50000", amount_returned: "70000", investment_years: "5")
    record = calc.to_calculation
    assert_equal "roi", record.calculator
    # inputs echo the cast BigDecimal attributes ("50000" → "50000.0").
    assert_equal "50000.0", record.inputs["amount_invested"]
    # jsonb stringifies hash keys on assignment.
    assert_equal "20000.00", record.result["total_gain"]
    assert_equal "6.9610", record.result["annualized_roi_percent"]
  end
end
