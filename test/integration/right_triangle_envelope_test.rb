require "test_helper"

# Integration tests for the Right Triangle calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success with the full solved triangle, 422s on the spec's edge cases,
# and that a row is recorded. (Page/markup rendering is the frontend agent's gate.)
class RightTriangleEnvelopeTest < ActionDispatch::IntegrationTest
  test "legs mode returns the ok envelope with the full solved triangle" do
    post "/calculators/right_triangle",
      params: { inputs: { mode: "legs", a: "3", b: "4" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "right_triangle", body["calculator"]
    assert_equal "legs", body.dig("inputs", "mode")

    result = body["result"]
    assert_equal "legs",      result["mode"]
    assert_equal "3.000000",  result["a"]
    assert_equal "4.000000",  result["b"]
    assert_equal "5.000000",  result["c"]
    assert_equal "36.869898", result["alpha"]
    assert_equal "53.130102", result["beta"]
    assert_equal "6.000000",  result["area"]
    assert_equal "12.000000", result["perimeter"]
    assert_equal "2.400000",  result["altitude"]
  end

  test "leg_hyp mode solves the missing leg" do
    post "/calculators/right_triangle",
      params: { inputs: { mode: "leg_hyp", a: "6", c: "10" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "8.000000", body.dig("result", "b")
    assert_equal "4.800000", body.dig("result", "altitude")
  end

  test "the result envelope carries exactly the spec's output keys" do
    post "/calculators/right_triangle",
      params: { inputs: { mode: "legs", a: "3", b: "4" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[a alpha altitude area b beta c mode perimeter],
      body["result"].keys.sort
  end

  test "a non-positive leg returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/right_triangle",
        params: { inputs: { mode: "legs", a: "0", b: "4" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "right_triangle", body["calculator"]
    assert body.dig("errors", "a").present?
  end

  test "a missing second side returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/right_triangle",
        params: { inputs: { mode: "legs", a: "3" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "b").present?
  end

  test "a hypotenuse not exceeding the leg returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/right_triangle",
        params: { inputs: { mode: "leg_hyp", a: "8", c: "6" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "c"), "must be greater than leg a"
  end

  test "an unknown mode returns the 422 error envelope" do
    post "/calculators/right_triangle",
      params: { inputs: { mode: "xyz", a: "3", b: "4" } }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "mode").present?
  end

  test "a non-numeric side returns 422 via the Base coercion guard and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/right_triangle",
        params: { inputs: { mode: "legs", a: "x", b: "4" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "a"), "is not a number"
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/right_triangle",
        params: { inputs: { mode: "legs", a: "5", b: "12" } }, as: :json
    end

    record = Calculation.last
    assert_equal "right_triangle", record.calculator
    assert_equal "legs", record.inputs["mode"]
    assert_equal "13.000000", record.result["c"]
  end
end
