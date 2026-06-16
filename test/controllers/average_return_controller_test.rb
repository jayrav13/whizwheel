require "test_helper"

# Integration test for the Average Return calculator through the dynamic
# CalculatorsController (ARCHITECTURE.md §3–4). Average Return is the first LIST input
# posted as an ARRAY (`inputs[returns][]`), so this exercises the array-aware strong-
# params path (CalculatorsController#calculator_params + Base.array_attribute_names):
# the array survives the permit, the §4 envelope round-trips it, a Calculation row is
# recorded on success, and a non-numeric entry 422s and records nothing.
class AverageReturnControllerTest < ActionDispatch::IntegrationTest
  test "an array list input survives strong params and returns the ok envelope" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/average_return",
        params: { inputs: { returns: %w[100 -50] } }, as: :json
    end

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "average_return", body["calculator"]
    # the array round-tripped through the permit, unflattened
    assert_equal %w[100 -50], body.dig("inputs", "returns")

    result = body["result"]
    assert_equal 2, result["count"]
    assert_equal BigDecimal("25"), BigDecimal(result["arithmetic_average"].to_s)
    assert_equal BigDecimal("0"),  BigDecimal(result["geometric_average"].to_s)
  end

  test "a recorded Calculation persists the returns array" do
    post "/calculators/average_return",
      params: { inputs: { returns: %w[10 20 -5 15] } }, as: :json
    assert_response :success

    record = Calculation.last
    assert_equal "average_return", record.calculator
    assert_equal %w[10 20 -5 15], record.inputs["returns"]
  end

  test "a non-numeric entry returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/average_return",
        params: { inputs: { returns: [ "10", "x", "20" ] } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "returns"), "must be a list of numbers"
  end

  test "an empty list returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/average_return",
        params: { inputs: { returns: [] } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_includes body.dig("errors", "returns"), "can't be blank"
  end

  test "missing inputs degrades to a 422, not a 500" do
    post "/calculators/average_return", params: {}, as: :json
    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
  end
end
