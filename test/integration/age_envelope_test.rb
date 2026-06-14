require "test_helper"
require "active_support/testing/time_helpers"

# Integration tests for the Age calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success, 422 on an invalid/out-of-order date, the default-to-today
# behavior, and that a row is recorded. (Page/markup rendering is the frontend
# agent's gate.)
class AgeEnvelopeTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  test "a valid age calculation returns the ok envelope with the seven outputs" do
    post "/calculators/age",
      params: { inputs: { birth_date: "1990-06-15", end_date: "2024-06-14" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "age", body["calculator"]
    assert_equal "1990-06-15", body.dig("inputs", "birth_date")
    assert_equal 33,    body.dig("result", "years")
    assert_equal 11,    body.dig("result", "months")
    assert_equal 30,    body.dig("result", "days")
    assert_equal 407,   body.dig("result", "total_months")
    assert_equal 1774,  body.dig("result", "total_weeks")
    assert_equal 12418, body.dig("result", "total_days")
    assert_equal 298032, body.dig("result", "total_hours")
  end

  test "the result envelope carries exactly the seven output keys" do
    post "/calculators/age",
      params: { inputs: { birth_date: "2000-01-01", end_date: "2024-01-01" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[days months total_days total_hours total_months total_weeks years], body["result"].keys.sort
  end

  test "an omitted end_date defaults to today" do
    travel_to Time.zone.local(2024, 6, 14, 9, 0, 0) do
      post "/calculators/age", params: { inputs: { birth_date: "1990-06-15" } }, as: :json
    end

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal 33, body.dig("result", "years")
    assert_equal 11, body.dig("result", "months")
    assert_equal 30, body.dig("result", "days")
  end

  test "a birth date after the end date returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/age",
        params: { inputs: { birth_date: "2024-06-15", end_date: "2024-06-14" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "age", body["calculator"]
    assert body.dig("errors", "birth_date").present?
  end

  test "an invalid (unparseable) date returns the 422 envelope, never a 500" do
    post "/calculators/age",
      params: { inputs: { birth_date: "2023-02-30", end_date: "2024-01-01" } }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "birth_date"), "is not a valid date"
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/age",
        params: { inputs: { birth_date: "1995-12-31", end_date: "2024-06-14" } }, as: :json
    end

    record = Calculation.last
    assert_equal "age", record.calculator
    assert_equal "1995-12-31", record.inputs["birth_date"].to_s
    assert_equal 28, record.result["years"]
  end
end
