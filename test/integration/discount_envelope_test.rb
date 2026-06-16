require "test_helper"

# Integration tests for the Discount calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success with the four outputs in both modes, 422 on invalid input, and
# that a row is recorded. (Page/markup rendering is the frontend gate.)
class DiscountEnvelopeTest < ActionDispatch::IntegrationTest
  test "a percent-mode discount returns the ok envelope with all four figures" do
    post "/calculators/discount",
      params: { inputs: { mode: "percent", original_price: "45.00", percent_off: "10" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "discount", body["calculator"]
    assert_equal "percent", body.dig("result", "mode")
    assert_equal "45.00", body.dig("result", "original_price")
    assert_equal "4.50", body.dig("result", "amount_saved")
    assert_equal "40.50", body.dig("result", "final_price")
  end

  test "a fixed-mode discount returns the ok envelope with all four figures" do
    post "/calculators/discount",
      params: { inputs: { mode: "fixed", original_price: "80.00", amount_off: "15.00" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "fixed", body.dig("result", "mode")
    assert_equal "80.00", body.dig("result", "original_price")
    assert_equal "15.00", body.dig("result", "amount_saved")
    assert_equal "65.00", body.dig("result", "final_price")
  end

  test "the result envelope always carries all four output keys" do
    post "/calculators/discount",
      params: { inputs: { mode: "percent", original_price: "199.99", percent_off: "25" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[mode original_price final_price amount_saved].sort,
      body["result"].keys.sort
  end

  test "an out-of-range percent returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/discount",
        params: { inputs: { mode: "percent", original_price: "45.00", percent_off: "120" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "discount", body["calculator"]
    assert body.dig("errors", "percent_off").present?
  end

  test "a fixed discount exceeding the original price returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/discount",
        params: { inputs: { mode: "fixed", original_price: "80.00", amount_off: "100" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "amount_off").present?
  end

  test "an unknown mode returns the 422 error envelope" do
    post "/calculators/discount",
      params: { inputs: { mode: "zzz", original_price: "80.00", amount_off: "10" } }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "mode").present?
  end

  test "a non-numeric original_price returns 422 and records nothing (#110)" do
    assert_no_difference "Calculation.count" do
      post "/calculators/discount",
        params: { inputs: { mode: "percent", original_price: "abc", percent_off: "10" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "original_price"), "is not a number"
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/discount",
        params: { inputs: { mode: "percent", original_price: "199.99", percent_off: "25" } }, as: :json
    end

    record = Calculation.last
    assert_equal "discount", record.calculator
    assert_equal "percent", record.inputs["mode"]
    assert_equal "149.99", record.result["final_price"]
    assert_equal "50.00", record.result["amount_saved"]
  end
end
