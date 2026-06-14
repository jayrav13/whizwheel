require "test_helper"

# Integration tests for the Simple Interest calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success (years + months), 422 on an invalid input, and that a row is
# recorded. (Page/markup rendering is the frontend agent's gate.)
class SimpleInterestEnvelopeTest < ActionDispatch::IntegrationTest
  test "a years-mode calculation returns the ok envelope with interest and total" do
    post "/calculators/simple_interest",
      params: { inputs: { principal: "1000", rate: "5", time: "3", unit: "years" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "simple_interest", body["calculator"]
    assert_equal "years", body.dig("inputs", "unit")
    assert_equal BigDecimal("150.00"),  BigDecimal(body.dig("result", "interest").to_s)
    assert_equal BigDecimal("1150.00"), BigDecimal(body.dig("result", "total").to_s)
  end

  test "a months-mode calculation converts months to years before the formula" do
    post "/calculators/simple_interest",
      params: { inputs: { principal: "2000", rate: "6", time: "18", unit: "months" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "months", body.dig("inputs", "unit")
    assert_equal BigDecimal("180.00"),  BigDecimal(body.dig("result", "interest").to_s)
    assert_equal BigDecimal("2180.00"), BigDecimal(body.dig("result", "total").to_s)
  end

  test "the result envelope carries exactly the interest and total keys" do
    post "/calculators/simple_interest",
      params: { inputs: { principal: "1000", rate: "5", time: "3", unit: "years" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[interest total], body["result"].keys.sort
  end

  test "an invalid (negative) input returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/simple_interest",
        params: { inputs: { principal: "-1", rate: "5", time: "3", unit: "years" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "simple_interest", body["calculator"]
    assert body.dig("errors", "principal").present?
  end

  test "an unknown unit returns the 422 error envelope" do
    post "/calculators/simple_interest",
      params: { inputs: { principal: "1000", rate: "5", time: "3", unit: "days" } }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "unit").present?
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/simple_interest",
        params: { inputs: { principal: "5000", rate: "3.5", time: "2", unit: "years" } }, as: :json
    end

    record = Calculation.last
    assert_equal "simple_interest", record.calculator
    assert_equal "years", record.inputs["unit"]
  end
end
