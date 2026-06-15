require "test_helper"

# Integration tests for the Standard Deviation calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success for both modes, 422 on invalid input, and that a row is
# recorded (and not recorded on a 422). Page/markup rendering is the FE gate.
class StandardDeviationEnvelopeTest < ActionDispatch::IntegrationTest
  test "a valid population calculation returns the ok envelope with the six outputs" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "10,12,23,23,16,23,21,16", mode: "population" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "standard_deviation", body["calculator"]
    assert_equal "10,12,23,23,16,23,21,16", body.dig("inputs", "values")
    assert_equal "population", body.dig("inputs", "mode")
    assert_equal "population", body.dig("result", "mode")
    assert_equal 8, body.dig("result", "count")
    assert_equal BigDecimal("144"),      BigDecimal(body.dig("result", "sum").to_s)
    assert_equal BigDecimal("18.000000"), BigDecimal(body.dig("result", "mean").to_s)
    assert_equal BigDecimal("24.000000"), BigDecimal(body.dig("result", "variance").to_s)
    assert_equal BigDecimal("4.898979"),  BigDecimal(body.dig("result", "standard_deviation").to_s)
  end

  test "sample mode selects the n−1 denominator over the wire" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "10,12,23,23,16,23,21,16", mode: "sample" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal "sample", body.dig("result", "mode")
    assert_equal BigDecimal("27.428571"), BigDecimal(body.dig("result", "variance").to_s)
    assert_equal BigDecimal("5.237229"),  BigDecimal(body.dig("result", "standard_deviation").to_s)
  end

  test "the result envelope carries exactly the six output keys" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "2,4,6,8", mode: "population" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[count mean mode standard_deviation sum variance], body["result"].keys.sort
  end

  test "a non-numeric token returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/standard_deviation",
        params: { inputs: { values: "1, two, 3", mode: "population" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "standard_deviation", body["calculator"]
    assert_includes body.dig("errors", "values"), "must be a list of numbers"
  end

  test "sample mode with a single value returns the 422 envelope" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "5", mode: "sample" } }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "values"), "need at least 2 values for sample mode"
  end

  test "an unknown mode returns the 422 envelope" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "1, 2, 3", mode: "pop" } }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "mode").present?
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/standard_deviation",
        params: { inputs: { values: "2,4,6,8", mode: "sample" } }, as: :json
    end

    record = Calculation.last
    assert_equal "standard_deviation", record.calculator
    assert_equal "2,4,6,8", record.inputs["values"]
    assert_equal "sample", record.inputs["mode"]
    assert_equal 4, record.result["count"]
    assert_equal "2.581989", record.result["standard_deviation"].to_s
  end
end
