require "test_helper"

# Integration tests for the Sales Tax calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real solve-for-X
# calculator over the wire: 200 success carrying all five outputs per mode, the
# 422 error envelope on invalid input, and that a row is (and is not) recorded.
# (Page/markup rendering is the frontend gate, #252.)
class SalesTaxEnvelopeTest < ActionDispatch::IntegrationTest
  test "after mode returns the ok envelope with the solved after-tax price and tax" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "after", before_tax_price: "100.00", rate: "6" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "sales_tax", body["calculator"]
    assert_equal "after", body.dig("result", "mode")
    assert_equal BigDecimal("100.00"), BigDecimal(body.dig("result", "before_tax_price").to_s)
    assert_equal BigDecimal("106.00"), BigDecimal(body.dig("result", "after_tax_price").to_s)
    assert_equal BigDecimal("6.0000"), BigDecimal(body.dig("result", "rate").to_s)
    assert_equal BigDecimal("6.00"),   BigDecimal(body.dig("result", "tax_amount").to_s)
  end

  test "before mode solves the before-tax price over the wire" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "before", after_tax_price: "106.00", rate: "6" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal BigDecimal("100.00"), BigDecimal(body.dig("result", "before_tax_price").to_s)
    assert_equal BigDecimal("6.00"),   BigDecimal(body.dig("result", "tax_amount").to_s)
  end

  test "rate mode solves the rate over the wire (4 dp)" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "rate", before_tax_price: "100.00", after_tax_price: "106.00" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal BigDecimal("6.0000"), BigDecimal(body.dig("result", "rate").to_s)
    assert_equal BigDecimal("6.00"),   BigDecimal(body.dig("result", "tax_amount").to_s)
  end

  test "the result envelope always carries all five output keys" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "after", before_tax_price: "100", rate: "6" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[mode before_tax_price after_tax_price rate tax_amount].sort,
      body["result"].keys.sort
  end

  test "an unknown mode returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/sales_tax",
        params: { inputs: { mode: "zzz", before_tax_price: "100", rate: "6" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "sales_tax", body["calculator"]
    assert body.dig("errors", "mode").present?
  end

  test "rate mode with after below before returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/sales_tax",
        params: { inputs: { mode: "rate", before_tax_price: "100", after_tax_price: "90" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "after_tax_price").present?
  end

  test "a non-numeric figure returns 422 and records nothing (#110)" do
    assert_no_difference "Calculation.count" do
      post "/calculators/sales_tax",
        params: { inputs: { mode: "after", before_tax_price: "x", rate: "6" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "before_tax_price"), "is not a number"
  end

  test "a missing required figure returns the 422 error envelope" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "after", before_tax_price: "100" } }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "rate").present?
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/sales_tax",
        params: { inputs: { mode: "after", before_tax_price: "49.99", rate: "7.25" } }, as: :json
    end

    record = Calculation.last
    assert_equal "sales_tax", record.calculator
    assert_equal "after", record.inputs["mode"]
    assert_equal BigDecimal("53.61"), BigDecimal(record.result["after_tax_price"].to_s)
    assert_equal BigDecimal("3.62"),  BigDecimal(record.result["tax_amount"].to_s)
  end
end
