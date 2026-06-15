require "test_helper"

# Integration test for the Mortgage calculator through the dynamic CalculatorsController
# (ARCHITECTURE.md §3–4): the JSON envelope, the 200 success / 422 validation paths, and
# that a Calculation row is recorded on success but not on failure.
class MortgageControllerTest < ActionDispatch::IntegrationTest
  VALID_INPUTS = {
    home_price: "360000", down_payment: "60000", annual_rate: "7", loan_term_years: "30",
    annual_property_tax: "3500", annual_home_insurance: "1200", monthly_hoa: "50"
  }.freeze

  test "valid input returns the ok envelope with the full mortgage result" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/mortgage", params: { inputs: VALID_INPUTS }, as: :json
    end

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "mortgage", body["calculator"]

    result = body["result"]
    assert_equal "300000.00", result["loan_amount"]
    assert_equal "1995.91",   result["pi_monthly"]
    assert_equal "2437.58",   result["total_monthly"]
    assert_equal "718524.05", result["total_of_pi"]
    assert_equal 360,         result["number_of_payments"]
    assert_equal 360,         result["schedule"].length
    assert_equal "0.00",      result["schedule"].last["balance"]

    # the chart series the FE renders without math
    assert_equal 4, result["chart"]["payment_components"].length
    assert_equal "300000.00", result["chart"]["balance_curve"].first["balance"]
    assert_equal "0.00",      result["chart"]["balance_curve"].last["balance"]
  end

  test "down_payment >= home_price returns the error envelope with 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/mortgage",
        params: { inputs: VALID_INPUTS.merge(down_payment: "360000") }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "mortgage", body["calculator"]
    assert_includes body.dig("errors", "down_payment"), "must be less than the home price"
  end

  test "a non-numeric input returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/mortgage",
        params: { inputs: VALID_INPUTS.merge(home_price: "abc") }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_includes body.dig("errors", "home_price"), "is not a number"
  end
end
