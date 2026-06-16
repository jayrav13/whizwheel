require "test_helper"

# Integration tests for the VAT calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success across the three solve-for modes, a 422 on an invalid input,
# and that a Calculation row is recorded. (Page/markup rendering is the frontend
# agent's gate.)
class VatEnvelopeTest < ActionDispatch::IntegrationTest
  test "a gross-mode calculation returns the ok envelope with the solved gross and VAT" do
    post "/calculators/vat",
      params: { inputs: { mode: "gross", net_price: "10.00", rate: "10" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "vat", body["calculator"]
    assert_equal "gross", body.dig("inputs", "mode")
    assert_equal "10.00", body.dig("result", "net_price")
    assert_equal "11.00", body.dig("result", "gross_price")
    assert_equal "10.0000", body.dig("result", "rate")
    assert_equal "1.00", body.dig("result", "vat_amount")
  end

  test "a net-mode calculation solves the net price from gross and rate" do
    post "/calculators/vat",
      params: { inputs: { mode: "net", gross_price: "11.00", rate: "10" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "10.00", body.dig("result", "net_price")
    assert_equal "1.00", body.dig("result", "vat_amount")
  end

  test "a rate-mode calculation solves the rate from net and gross" do
    post "/calculators/vat",
      params: { inputs: { mode: "rate", net_price: "10.00", gross_price: "11.00" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "10.0000", body.dig("result", "rate")
    assert_equal "1.00", body.dig("result", "vat_amount")
  end

  test "the result envelope always carries all five keys" do
    post "/calculators/vat",
      params: { inputs: { mode: "gross", net_price: "10", rate: "10" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[gross_price mode net_price rate vat_amount], body["result"].keys.sort
  end

  test "an invalid input (rate-mode gross < net) returns the 422 envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/vat",
        params: { inputs: { mode: "rate", net_price: "10", gross_price: "9" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "vat", body["calculator"]
    assert body.dig("errors", "gross_price").present?
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/vat",
        params: { inputs: { mode: "net", gross_price: "11.00", rate: "10" } }, as: :json
    end

    record = Calculation.last
    assert_equal "vat", record.calculator
    assert_equal "net", record.inputs["mode"]
  end
end
