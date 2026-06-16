require "test_helper"

# Integration tests for the House Affordability calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the wire:
# 200 success (reference row 1), 422 on an unaffordable / invalid input, and that a row
# is recorded. (Page/markup rendering is the frontend agent's gate.)
class HouseAffordabilityEnvelopeTest < ActionDispatch::IntegrationTest
  REFERENCE_INPUTS = {
    annual_income: "120000", monthly_debts: "500", down_payment: "60000",
    annual_rate: "6", loan_term_years: "30", front_dti: "28", back_dti: "36",
    monthly_property_tax: "250", monthly_home_insurance: "100", monthly_hoa: "0"
  }.freeze

  test "a valid calculation returns the ok envelope with the five affordability figures" do
    post "/calculators/house_affordability", params: { inputs: REFERENCE_INPUTS }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "house_affordability", body["calculator"]
    assert_equal "10000.00",  body.dig("result", "gross_monthly_income")
    assert_equal "2800.00",   body.dig("result", "max_monthly_housing")
    assert_equal "2450.00",   body.dig("result", "max_pi")
    assert_equal "408639.46", body.dig("result", "max_loan_amount")
    assert_equal "468639.46", body.dig("result", "max_home_price")
  end

  test "the result envelope carries exactly the five output keys" do
    post "/calculators/house_affordability", params: { inputs: REFERENCE_INPUTS }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[gross_monthly_income max_home_price max_loan_amount max_monthly_housing max_pi],
      body["result"].keys.sort
  end

  test "constraints with no affordable home return the 422 error envelope and record nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/house_affordability", params: { inputs: REFERENCE_INPUTS.merge(
        annual_income: "30000", monthly_debts: "2000",
        monthly_property_tax: "800", monthly_home_insurance: "200"
      ) }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "house_affordability", body["calculator"]
    assert body.dig("errors", "base").present?
  end

  test "an invalid DTI returns the 422 error envelope" do
    post "/calculators/house_affordability",
      params: { inputs: REFERENCE_INPUTS.merge(back_dti: "150") }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "back_dti").present?
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/house_affordability", params: { inputs: REFERENCE_INPUTS }, as: :json
    end

    record = Calculation.last
    assert_equal "house_affordability", record.calculator
    assert_equal "468639.46", record.result["max_home_price"]
  end
end
