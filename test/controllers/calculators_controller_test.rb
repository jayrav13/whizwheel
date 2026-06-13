require "test_helper"
require_relative "../support/calculators"

# Integration tests for the dynamic CalculatorsController — the JSON envelope (§4),
# the 404/422/200 paths, anonymous vs. attributed recording. Driven through the
# test-only Calculators::TestDouble so the first real calculator stays the agent's job.
class CalculatorsControllerTest < ActionDispatch::IntegrationTest
  test "valid input returns the ok envelope" do
    post "/calculators/test_double", params: { inputs: { x: 3 } }

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "test_double", body["calculator"]
    assert_equal BigDecimal("3"), BigDecimal(body.dig("inputs", "x").to_s)
    assert_equal BigDecimal("6"), BigDecimal(body.dig("result", "doubled").to_s)
  end

  test "invalid input returns the error envelope with 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/test_double", params: { inputs: { x: "" } }
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "test_double", body["calculator"]
    assert body.dig("errors", "x").present?
  end

  test "unknown input keys are dropped, not 500s" do
    post "/calculators/test_double", params: { inputs: { x: 3, sneaky: "haxor" } }

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_not_includes body["inputs"].keys, "sneaky"
  end

  test "unknown slug is 404" do
    post "/calculators/no_such_calculator", params: { inputs: {} }
    assert_response :not_found
  end

  test "an anonymous calculation is recorded with no user" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/test_double", params: { inputs: { x: 3 } }
    end

    record = Calculation.last
    assert_nil record.user
    assert_equal "test_double", record.calculator
  end

  test "a signed-in calculation is attributed to the user" do
    post session_path, params: { username: "alice", password: "password" }

    post "/calculators/test_double", params: { inputs: { x: 5 } }
    assert_response :success
    assert_equal users(:alice), Calculation.last.user
  end
end
