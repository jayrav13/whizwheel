require "test_helper"

# Integration tests for the Tip calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success with all four outputs, the people=1 default, 422 on invalid
# input, and that a row is recorded. (Page/markup rendering is the frontend gate.)
class TipEnvelopeTest < ActionDispatch::IntegrationTest
  test "a split calculation returns the ok envelope with all four figures" do
    post "/calculators/tip",
      params: { inputs: { bill: "50.00", tip_percent: "15", people: "2" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "tip", body["calculator"]
    assert_equal "2", body.dig("inputs", "people").to_s
    assert_equal BigDecimal("7.50"),  BigDecimal(body.dig("result", "tip_amount").to_s)
    assert_equal BigDecimal("57.50"), BigDecimal(body.dig("result", "total").to_s)
    assert_equal BigDecimal("3.75"),  BigDecimal(body.dig("result", "tip_per_person").to_s)
    assert_equal BigDecimal("28.75"), BigDecimal(body.dig("result", "total_per_person").to_s)
  end

  test "the result envelope always carries all four output keys" do
    post "/calculators/tip",
      params: { inputs: { bill: "100.00", tip_percent: "20", people: "3" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[tip_amount total tip_per_person total_per_person].sort,
      body["result"].keys.sort
  end

  test "people defaults to 1 when omitted (per-person equals whole-party)" do
    post "/calculators/tip",
      params: { inputs: { bill: "50.00", tip_percent: "15" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal BigDecimal("7.50"),  BigDecimal(body.dig("result", "tip_per_person").to_s)
    assert_equal BigDecimal("57.50"), BigDecimal(body.dig("result", "total_per_person").to_s)
  end

  test "an invalid people count returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/tip",
        params: { inputs: { bill: "50.00", tip_percent: "15", people: "0" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "tip", body["calculator"]
    assert body.dig("errors", "people").present?
  end

  test "a fractional people count returns 422 and records nothing (#109)" do
    # Integer-attribute coercion guard over the wire: "2.5" must not silently
    # truncate to a 2-person split — it is a label-led 422, no Calculation recorded.
    assert_no_difference "Calculation.count" do
      post "/calculators/tip",
        params: { inputs: { bill: "50.00", tip_percent: "15", people: "2.5" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "people"), "must be a whole number"
  end

  test "a non-numeric bill returns 422 and records nothing (#110)" do
    # Decimal-attribute coercion guard over the wire: "abc" must not become a
    # silent zero-cost bill — it is a label-led 422, no Calculation recorded.
    assert_no_difference "Calculation.count" do
      post "/calculators/tip",
        params: { inputs: { bill: "abc", tip_percent: "15", people: "1" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "bill"), "is not a number"
  end

  test "a missing bill returns the 422 error envelope" do
    post "/calculators/tip",
      params: { inputs: { tip_percent: "15", people: "1" } }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "bill").present?
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/tip",
        params: { inputs: { bill: "128.57", tip_percent: "18", people: "4" } }, as: :json
    end

    record = Calculation.last
    assert_equal "tip", record.calculator
    assert_equal "4", record.inputs["people"].to_s
    assert_equal BigDecimal("23.14"), BigDecimal(record.result["tip_amount"].to_s)
  end
end
