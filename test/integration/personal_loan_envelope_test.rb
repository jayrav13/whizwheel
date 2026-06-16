require "test_helper"

# Integration tests for the Personal Loan calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the wire:
# 200 success with the summary + schedule, 422 on degenerate input, and that a
# Calculation row is recorded only on success. (Page/markup rendering is the frontend
# agent's gate — this is backend-before-frontend, so the GET page falls back to
# "coming soon" until #256 lands; only the POST envelope is exercised here.)
class PersonalLoanEnvelopeTest < ActionDispatch::IntegrationTest
  test "returns the ok envelope with summary + schedule" do
    post "/calculators/personal_loan",
      params: { inputs: {
        loan_amount: "15000", annual_rate: "7", term_months: "36"
      } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "personal_loan", body["calculator"]
    assert_equal BigDecimal("15000"), BigDecimal(body.dig("inputs", "loan_amount"))

    result = body["result"]
    assert_equal "15000.00", result["loan_amount"]
    assert_equal "463.16",   result["monthly_payment"]
    assert_equal "16673.61", result["total_paid"]
    assert_equal "1673.61",  result["total_interest"]
    assert_equal 36,         result["number_of_payments"]

    schedule = result["schedule"]
    assert_kind_of Array, schedule
    assert_equal 36, schedule.length
    first = schedule.first
    assert_equal 1,          first["month"]
    assert_equal "463.16",   first["payment"]
    assert_equal "87.50",    first["interest"]
    assert_equal "375.66",   first["principal"]
    assert_equal "14624.34", first["balance"]
    assert_equal "0.00", schedule.last["balance"]
  end

  test "the result envelope carries exactly the spec's output keys" do
    post "/calculators/personal_loan",
      params: { inputs: {
        loan_amount: "5000", annual_rate: "0", term_months: "12"
      } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[loan_amount monthly_payment number_of_payments schedule total_interest total_paid],
      body["result"].keys.sort
  end

  test "a zero-rate loan succeeds with P/n payments and no interest" do
    post "/calculators/personal_loan",
      params: { inputs: {
        loan_amount: "5000", annual_rate: "0", term_months: "12"
      } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "416.67",  body.dig("result", "monthly_payment")
    assert_equal "0.00",    body.dig("result", "total_interest")
    assert_equal "5000.00", body.dig("result", "total_paid")
  end

  test "a non-positive loan_amount returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/personal_loan",
        params: { inputs: {
          loan_amount: "0", annual_rate: "7", term_months: "36"
        } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "personal_loan", body["calculator"]
    assert body.dig("errors", "loan_amount").present?
  end

  test "a non-positive term_months returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/personal_loan",
        params: { inputs: {
          loan_amount: "15000", annual_rate: "7", term_months: "0"
        } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "term_months").present?
  end

  test "a missing required field returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/personal_loan",
        params: { inputs: {
          annual_rate: "7", term_months: "36"
        } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "loan_amount").present?
  end

  test "a fractional term_months returns 422 and records nothing (#109)" do
    assert_no_difference "Calculation.count" do
      post "/calculators/personal_loan",
        params: { inputs: {
          loan_amount: "15000", annual_rate: "7", term_months: "36.5"
        } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "term_months"), "must be a whole number"
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/personal_loan",
        params: { inputs: {
          loan_amount: "15000", annual_rate: "7", term_months: "36"
        } }, as: :json
    end

    record = Calculation.last
    assert_equal "personal_loan", record.calculator
    assert_equal BigDecimal("15000"), BigDecimal(record.inputs["loan_amount"].to_s)
    assert_equal 36, record.result["schedule"].length
  end
end
