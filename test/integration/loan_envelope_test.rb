require "test_helper"

# Integration tests for the Loan calculator through the dynamic CalculatorsController
# and the JSON envelope (§4) — the real calculator over the wire across all three
# solve-for modes: 200 success with the schedule + summary, 422 on degenerate input,
# and that a Calculation row is recorded only on success. (Page/markup rendering is
# the frontend agent's gate.)
class LoanEnvelopeTest < ActionDispatch::IntegrationTest
  test "payment mode returns the ok envelope with summary + schedule" do
    post "/calculators/loan",
      params: { inputs: {
        mode: "payment", loan_amount: "25000", annual_rate: "5", term_months: "60"
      } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "loan", body["calculator"]
    assert_equal "payment", body.dig("inputs", "mode")
    assert_equal BigDecimal("25000"), BigDecimal(body.dig("inputs", "loan_amount"))

    result = body["result"]
    assert_equal "payment",  result["mode"]
    assert_equal "471.78",   result["monthly_payment"]
    assert_equal "28306.88", result["total_paid"]
    assert_equal "3306.88",  result["total_interest"]
    assert_equal 60,         result["number_of_payments"]

    schedule = result["schedule"]
    assert_kind_of Array, schedule
    assert_equal 60, schedule.length
    first = schedule.first
    assert_equal 1,          first["month"]
    assert_equal "471.78",   first["payment"]
    assert_equal "104.17",   first["interest"]
    assert_equal "367.61",   first["principal"]
    assert_equal "24632.39", first["balance"]
    assert_equal "0.00", schedule.last["balance"]
  end

  test "amount mode solves the affordable loan amount over the wire" do
    post "/calculators/loan",
      params: { inputs: {
        mode: "amount", monthly_payment: "1199.10", annual_rate: "6", term_months: "360"
      } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "amount", body.dig("result", "mode")
    assert_equal "199999.82", body.dig("result", "loan_amount")
    assert_equal "1199.10", body.dig("result", "monthly_payment")
  end

  test "term mode solves the ceil'd term over the wire" do
    post "/calculators/loan",
      params: { inputs: {
        mode: "term", loan_amount: "25000", monthly_payment: "600.00", annual_rate: "5"
      } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "term", body.dig("result", "mode")
    assert_equal 46,         body.dig("result", "term_months")
    assert_equal "27516.64", body.dig("result", "total_paid")
    assert_equal "2516.64",  body.dig("result", "total_interest")
  end

  test "the result envelope carries exactly the spec's output keys" do
    post "/calculators/loan",
      params: { inputs: {
        mode: "payment", loan_amount: "10000", annual_rate: "0", term_months: "24"
      } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[loan_amount mode monthly_payment number_of_payments schedule term_months total_interest total_paid],
      body["result"].keys.sort
  end

  test "a zero-rate loan succeeds with P/n payments and no interest" do
    post "/calculators/loan",
      params: { inputs: {
        mode: "payment", loan_amount: "10000", annual_rate: "0", term_months: "24"
      } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "416.67", body.dig("result", "monthly_payment")
    assert_equal "0.00",   body.dig("result", "total_interest")
  end

  test "an invalid mode returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/loan",
        params: { inputs: {
          mode: "zzz", loan_amount: "25000", annual_rate: "5", term_months: "60"
        } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "loan", body["calculator"]
    assert body.dig("errors", "mode").present?
  end

  test "a missing required-for-mode field returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/loan",
        params: { inputs: {
          mode: "payment", loan_amount: "25000", annual_rate: "5"
        } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "term_months").present?
  end

  test "a non-positive loan_amount returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/loan",
        params: { inputs: {
          mode: "payment", loan_amount: "0", annual_rate: "5", term_months: "60"
        } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "loan_amount").present?
  end

  test "a term-mode payment too small to amortize returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/loan",
        params: { inputs: {
          mode: "term", loan_amount: "100000", monthly_payment: "400", annual_rate: "6"
        } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "monthly_payment"),
      "is too small to ever repay the loan at this rate"
  end

  test "a fractional term_months returns 422 and records nothing (#109)" do
    assert_no_difference "Calculation.count" do
      post "/calculators/loan",
        params: { inputs: {
          mode: "payment", loan_amount: "25000", annual_rate: "5", term_months: "3.5"
        } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "term_months"), "must be a whole number"
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/loan",
        params: { inputs: {
          mode: "payment", loan_amount: "25000", annual_rate: "5", term_months: "60"
        } }, as: :json
    end

    record = Calculation.last
    assert_equal "loan", record.calculator
    assert_equal "payment", record.inputs["mode"]
    assert_equal BigDecimal("25000"), BigDecimal(record.inputs["loan_amount"].to_s)
    assert_equal 60, record.result["schedule"].length
  end
end
