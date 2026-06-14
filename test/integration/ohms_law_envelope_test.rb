require "test_helper"

# Integration tests for the Ohm's Law calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success across modes, 422 on a division-by-zero input, and that a row
# is recorded. (Page/markup rendering is the frontend agent's gate.)
class OhmsLawEnvelopeTest < ActionDispatch::IntegrationTest
  test "a vi-mode calculation returns the ok envelope with all four solved quantities" do
    post "/calculators/ohms_law",
      params: { inputs: { mode: "vi", voltage: "12", current: "2" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "ohms_law", body["calculator"]
    assert_equal "vi", body.dig("inputs", "mode")
    assert_equal BigDecimal("12"), BigDecimal(body.dig("result", "voltage").to_s)
    assert_equal BigDecimal("2"),  BigDecimal(body.dig("result", "current").to_s)
    assert_equal BigDecimal("6"),  BigDecimal(body.dig("result", "resistance").to_s)
    assert_equal BigDecimal("24"), BigDecimal(body.dig("result", "power").to_s)
  end

  test "the result envelope always carries all four V/I/R/P keys" do
    post "/calculators/ohms_law",
      params: { inputs: { mode: "rp", resistance: "4", power: "36" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[current power resistance voltage], body["result"].keys.sort
  end

  test "a valid-zero input (ir, resistance = 0) succeeds with V = 0, P = 0" do
    post "/calculators/ohms_law",
      params: { inputs: { mode: "ir", current: "2", resistance: "0" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal BigDecimal("0"), BigDecimal(body.dig("result", "voltage").to_s)
    assert_equal BigDecimal("0"), BigDecimal(body.dig("result", "power").to_s)
  end

  test "a division-by-zero input returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/ohms_law",
        params: { inputs: { mode: "vi", voltage: "12", current: "0" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "ohms_law", body["calculator"]
    assert body.dig("errors", "current").present?
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/ohms_law",
        params: { inputs: { mode: "vp", voltage: "12", power: "24" } }, as: :json
    end

    record = Calculation.last
    assert_equal "ohms_law", record.calculator
    assert_equal "vp", record.inputs["mode"]
  end
end
