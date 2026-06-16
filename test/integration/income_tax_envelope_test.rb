require "test_helper"

# Integration tests for the Income Tax calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success with the full output contract (including the per-bracket
# tabular-output), 422 on invalid input, and that a row is recorded. (Page/markup
# rendering is the frontend gate, issue #260.)
class IncomeTaxEnvelopeTest < ActionDispatch::IntegrationTest
  test "a direct taxable_income returns the ok envelope with every output key" do
    post "/calculators/income_tax",
      params: { inputs: { taxable_income: "250000" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "income_tax", body["calculator"]
    assert_equal "250000.00", body.dig("result", "taxable_income")
    assert_equal "57063.00", body.dig("result", "total_tax")
    assert_equal "192937.00", body.dig("result", "after_tax_income")
    assert_equal "22.8252", body.dig("result", "effective_rate")
    assert_equal "32", body.dig("result", "marginal_rate")
    assert_equal 5, body.dig("result", "brackets").length
  end

  test "the brackets tabular-output carries the per-row schema and reconciles to total_tax" do
    post "/calculators/income_tax",
      params: { inputs: { taxable_income: "250000" } }, as: :json

    body = JSON.parse(@response.body)
    rows = body.dig("result", "brackets")

    first = rows.first
    assert_equal %w[rate lower upper taxable_in_bracket tax].sort, first.keys.sort
    assert_equal "10", first["rate"]
    assert_equal "0.00", first["lower"]
    assert_equal "11925.00", first["upper"]
    assert_equal "11925.00", first["taxable_in_bracket"]
    assert_equal "1192.50", first["tax"]

    tax_sum = rows.sum { |r| BigDecimal(r["tax"]) }
    assert_equal BigDecimal(body.dig("result", "total_tax")), tax_sum
  end

  test "gross_income and deductions derive the taxable income over the wire" do
    post "/calculators/income_tax",
      params: { inputs: { gross_income: "60000", deductions: "14600" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal "45400.00", body.dig("result", "taxable_income")
    assert_equal "5209.50", body.dig("result", "total_tax")
  end

  test "the result envelope always carries all six output keys" do
    post "/calculators/income_tax",
      params: { inputs: { taxable_income: "100000" } }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[taxable_income total_tax after_tax_income effective_rate marginal_rate brackets].sort,
      body["result"].keys.sort
  end

  test "missing both income inputs returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/income_tax",
        params: { inputs: { deductions: "5000" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "income_tax", body["calculator"]
    assert body.dig("errors", "taxable_income").present?
  end

  test "a negative taxable_income returns 422 and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/income_tax",
        params: { inputs: { taxable_income: "-100" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "taxable_income").present?
  end

  test "a non-numeric taxable_income returns 422 with the Base guard message" do
    assert_no_difference "Calculation.count" do
      post "/calculators/income_tax",
        params: { inputs: { taxable_income: "x" } }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "taxable_income"), "is not a number"
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/income_tax",
        params: { inputs: { taxable_income: "50000" } }, as: :json
    end

    record = Calculation.last
    assert_equal "income_tax", record.calculator
    assert_equal "5914.00", record.result["total_tax"]
    assert_equal "22", record.result["marginal_rate"]
  end
end
