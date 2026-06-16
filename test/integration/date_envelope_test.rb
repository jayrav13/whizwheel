require "test_helper"

# Integration tests for the Date calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success in both modes, 422 on invalid input, and that a row is
# recorded. (Page/markup rendering is the frontend agent's gate.)
class DateEnvelopeTest < ActionDispatch::IntegrationTest
  test "a valid difference calculation returns the ok envelope" do
    post "/calculators/date",
      params: { inputs: { mode: "difference", start_date: "2023-01-15", end_date: "2025-03-20" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "date", body["calculator"]
    assert_equal "difference", body.dig("inputs", "mode")
    assert_equal "difference", body.dig("result", "mode")
    assert_equal 795, body.dig("result", "total_days")
    assert_equal 2,   body.dig("result", "years")
    assert_equal 2,   body.dig("result", "months")
    assert_equal 5,   body.dig("result", "days")
    assert_equal 113, body.dig("result", "total_weeks")
    assert_equal 4,   body.dig("result", "remainder_days")
  end

  test "the difference result carries exactly the seven output keys" do
    post "/calculators/date",
      params: { inputs: { mode: "difference", start_date: "2024-01-01", end_date: "2024-12-31" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[days mode months remainder_days total_days total_weeks years], body["result"].keys.sort
  end

  test "a valid add_subtract calculation returns the resulting date" do
    post "/calculators/date",
      params: { inputs: { mode: "add_subtract", start_date: "2024-01-01", operation: "add",
                          years: "0", months: "0", weeks: "0", days: "30" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "add_subtract", body.dig("result", "mode")
    assert_equal "2024-01-31", body.dig("result", "result_date")
    assert_equal "2024-01-01", body.dig("result", "start_date")
    assert_equal "add", body.dig("result", "operation")
  end

  test "the add_subtract result carries exactly the four output keys" do
    post "/calculators/date",
      params: { inputs: { mode: "add_subtract", start_date: "2024-01-01", operation: "add", days: "30" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[mode operation result_date start_date], body["result"].keys.sort
  end

  test "difference mode without an end_date returns the 422 envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/date",
        params: { inputs: { mode: "difference", start_date: "2024-01-01" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "date", body["calculator"]
    assert body.dig("errors", "end_date").present?
  end

  test "add_subtract without an operation returns the 422 envelope" do
    post "/calculators/date",
      params: { inputs: { mode: "add_subtract", start_date: "2024-01-01", days: "5" } }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "operation").present?
  end

  test "an unparseable date returns the 422 envelope, never a 500" do
    post "/calculators/date",
      params: { inputs: { mode: "difference", start_date: "2023-02-30", end_date: "2024-01-01" } }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "start_date"), "is not a valid date"
  end

  test "a fractional integer offset returns the 422 envelope" do
    post "/calculators/date",
      params: { inputs: { mode: "add_subtract", start_date: "2024-01-01", operation: "add", months: "1.5" } }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "months"), "must be a whole number"
  end

  test "blank offset fields submitted directly to the route return 200, not 500 — #213" do
    # The authentic reproduction of #213: a direct API client (bypassing any client-
    # side value="0") posts the offset keys as empty strings. They must coerce to the
    # default 0 — a 200 with the start date unchanged — never a 500 from `nil * 12`.
    assert_difference "Calculation.count", 1 do
      post "/calculators/date",
        params: { inputs: { mode: "add_subtract", start_date: "2024-06-14", operation: "add",
                            years: "", months: "", weeks: "", days: "" } }, as: :json
    end

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "2024-06-14", body.dig("result", "result_date")
  end

  test "a successful difference calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/date",
        params: { inputs: { mode: "difference", start_date: "2020-02-28", end_date: "2020-03-01" } }, as: :json
    end

    record = Calculation.last
    assert_equal "date", record.calculator
    assert_equal "difference", record.inputs["mode"]
    assert_equal 2, record.result["total_days"]
  end

  test "a successful add_subtract calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/date",
        params: { inputs: { mode: "add_subtract", start_date: "2024-02-28", operation: "add", days: "1" } }, as: :json
    end

    record = Calculation.last
    assert_equal "date", record.calculator
    assert_equal "2024-02-29", record.result["result_date"]
  end
end
