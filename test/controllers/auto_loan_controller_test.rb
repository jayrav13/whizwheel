require "test_helper"

# Integration test for the Auto Loan calculator through the dynamic CalculatorsController
# (ARCHITECTURE.md §3–4): the JSON envelope, the 200 success / 422 validation paths, and
# that a Calculation row is recorded on success but not on failure.
class AutoLoanControllerTest < ActionDispatch::IntegrationTest
  VALID_INPUTS = {
    auto_price: "30000", term_months: "60", annual_rate: "5",
    down_payment: "4000", trade_in: "6000", sales_tax_rate: "7", fees: "800"
  }.freeze

  test "valid input returns the ok envelope with the full auto-loan result" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/auto_loan", params: { inputs: VALID_INPUTS }, as: :json
    end

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "auto_loan", body["calculator"]

    result = body["result"]
    assert_equal "1680.00",  result["sales_tax"]
    assert_equal "22480.00", result["amount_financed"]
    assert_equal "424.23",   result["monthly_payment"]
    assert_equal "25453.48", result["total_paid"]
    assert_equal "2973.48",  result["total_interest"]
    assert_equal 60,         result["number_of_payments"]
    assert_equal 60,         result["schedule"].length
    assert_equal "0.00",     result["schedule"].last["balance"]
  end

  test "amount financed <= 0 returns the error envelope with 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/auto_loan",
        params: { inputs: VALID_INPUTS.merge(auto_price: "10000", trade_in: "6000", down_payment: "5000", sales_tax_rate: "0", fees: "0") },
        as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "auto_loan", body["calculator"]
    assert_includes body.dig("errors", "base"), "amount financed must be greater than 0"
  end

  test "a non-numeric input returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/auto_loan",
        params: { inputs: VALID_INPUTS.merge(auto_price: "abc") }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_includes body.dig("errors", "auto_price"), "is not a number"
  end
end
