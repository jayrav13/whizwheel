require "test_helper"

# Integration tests for the Amortization calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success with the full schedule + chart series, 422 on a degenerate
# input, and that a row is recorded. (Page/markup rendering is the frontend agent's
# gate.) This is the first tabular-output + charts calculator, so the success case
# asserts the row-array schedule and the chart shape come through the envelope.
class AmortizationEnvelopeTest < ActionDispatch::IntegrationTest
  test "a valid loan returns the ok envelope with summary, schedule and chart" do
    post "/calculators/amortization",
      params: { inputs: { principal: "200000", annual_rate: "5", years: "15" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "amortization", body["calculator"]
    # inputs echo the calculator's coerced attributes (a :decimal renders "200000.0").
    assert_equal BigDecimal("200000"), BigDecimal(body.dig("inputs", "principal"))

    result = body["result"]
    assert_equal "1581.59",   result["monthly_payment"]
    assert_equal "284685.48", result["total_paid"]
    assert_equal "84685.48",  result["total_interest"]
    assert_equal 180,         result["number_of_payments"]

    # --- the schedule is a row array, 180 long, last balance 0.00 ---
    schedule = result["schedule"]
    assert_kind_of Array, schedule
    assert_equal 180, schedule.length
    first = schedule.first
    assert_equal 1,          first["month"]
    assert_equal "1581.59",  first["payment"]
    assert_equal "833.33",   first["interest"]
    assert_equal "748.26",   first["principal"]
    assert_equal "199251.74", first["balance"]
    assert_equal "0.00", schedule.last["balance"]

    # --- the chart series: donut slices + balance curve ---
    chart = result["chart"]
    assert_equal "200000.00", chart["principal"]
    assert_equal "84685.48",  chart["total_interest"]
    curve = chart["balance_curve"]
    assert_kind_of Array, curve
    assert_equal({ "month" => 0, "balance" => "200000.00" }, curve.first)
    assert_equal "0.00", curve.last["balance"]
  end

  test "the result envelope carries exactly the spec's output keys" do
    post "/calculators/amortization",
      params: { inputs: { principal: "12000", annual_rate: "0", years: "1" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[chart monthly_payment number_of_payments schedule total_interest total_paid],
      body["result"].keys.sort
  end

  test "a zero-rate loan succeeds with P/n payments and no interest" do
    post "/calculators/amortization",
      params: { inputs: { principal: "12000", annual_rate: "0", years: "1" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "1000.00", body.dig("result", "monthly_payment")
    assert_equal "0.00",    body.dig("result", "total_interest")
  end

  test "a non-positive principal returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/amortization",
        params: { inputs: { principal: "0", annual_rate: "5", years: "15" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "amortization", body["calculator"]
    assert body.dig("errors", "principal").present?
  end

  test "a missing years value returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/amortization",
        params: { inputs: { principal: "100000", annual_rate: "5" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "years").present?
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/amortization",
        params: { inputs: { principal: "10000", annual_rate: "4.5", years: "5" } }, as: :json
    end

    record = Calculation.last
    assert_equal "amortization", record.calculator
    assert_equal BigDecimal("10000"), BigDecimal(record.inputs["principal"].to_s)
    assert_equal 60, record.result["schedule"].length
  end

  test "a fractional years value returns 422 and records nothing (#109)" do
    # Integer-attribute coercion guard over the wire on a SECOND calculator: "2.5"
    # years must not silently truncate to a 2-year term — it is a label-led 422 with
    # no Calculation recorded. (The Tip envelope test covers the integer guard via
    # `people`; this proves it is a Base-level guarantee, not a per-calculator fix.)
    assert_no_difference "Calculation.count" do
      post "/calculators/amortization",
        params: { inputs: { principal: "200000", annual_rate: "5", years: "2.5" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "amortization", body["calculator"]
    assert_includes body.dig("errors", "years"), "must be a whole number"
  end

  test "scientific-notation decimal input is accepted, not rejected as garbage (#109)" do
    # Lock-in: "2e5" principal must compute as 200000, not 422. The earlier regex
    # guard wrongly rejected scientific notation; parse-based validation accepts it.
    post "/calculators/amortization",
      params: { inputs: { principal: "2e5", annual_rate: "5", years: "15" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal BigDecimal("200000"), BigDecimal(body.dig("inputs", "principal"))
    # identical to the principal: "200000" reference case above.
    assert_equal "1581.59", body.dig("result", "monthly_payment")
  end

  test "whole scientific-notation years is accepted and not truncated (#109)" do
    # "1.2e1" == 12 years (144 payments). The stock :integer cast would parse "1.2e1"
    # as 1; the guarded type routes through BigDecimal so the term is the full 12 years.
    post "/calculators/amortization",
      params: { inputs: { principal: "12000", annual_rate: "0", years: "1.2e1" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal 144, body.dig("result", "number_of_payments")
  end
end
