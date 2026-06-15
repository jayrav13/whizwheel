require "test_helper"

# Integration tests for the Compound Interest calculator through the dynamic
# CalculatorsController and the JSON envelope (§4) — the real calculator over the
# wire: 200 success with the summary figures + growth series, 422 on bad input, and
# that a row is recorded. (Page/markup rendering is the frontend agent's gate.) This
# is a multi-mode (compounding picker) calculator, so the success case exercises the
# mode posted as inputs[compounding] and asserts the growth series comes through.
class CompoundInterestEnvelopeTest < ActionDispatch::IntegrationTest
  test "a valid input returns the ok envelope with summary and growth series" do
    post "/calculators/compound_interest",
      params: { inputs: { principal: "20000", annual_rate: "5", years: "10", compounding: "monthly" } },
      as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "compound_interest", body["calculator"]
    # inputs echo the calculator's coerced attributes.
    assert_equal BigDecimal("20000"), BigDecimal(body.dig("inputs", "principal"))
    assert_equal "monthly", body.dig("inputs", "compounding")

    result = body["result"]
    assert_equal "32940.19", result["future_value"]
    assert_equal "12940.19", result["total_interest"]
    assert_equal "20000.00", result["principal"]
    assert_equal 12,         result["periods_per_year"]
    assert_equal "monthly",  result["compounding"]

    # --- the growth series is a row array, 11 long, anchored at principal and FV ---
    series = result["growth_series"]
    assert_kind_of Array, series
    assert_equal 11, series.length
    assert_equal({ "year" => 0, "balance" => "20000.00" }, series.first)
    assert_equal "32940.19", series.last["balance"]
    assert_equal 10, series.last["year"]
  end

  test "the result envelope carries exactly the spec's output keys" do
    post "/calculators/compound_interest",
      params: { inputs: { principal: "10000", annual_rate: "6", years: "5", compounding: "annually" } },
      as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal %w[compounding future_value growth_series periods_per_year principal total_interest],
      body["result"].keys.sort
  end

  test "the compounding mode selects the periods per year (daily)" do
    post "/calculators/compound_interest",
      params: { inputs: { principal: "15000", annual_rate: "4.5", years: "2", compounding: "daily" } },
      as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal 365,        body.dig("result", "periods_per_year")
    assert_equal "16412.52", body.dig("result", "future_value")
    assert_equal "1412.52",  body.dig("result", "total_interest")
  end

  test "a zero-rate input succeeds with future value equal to principal" do
    post "/calculators/compound_interest",
      params: { inputs: { principal: "1000", annual_rate: "0", years: "5", compounding: "monthly" } },
      as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal "1000.00", body.dig("result", "future_value")
    assert_equal "0.00",    body.dig("result", "total_interest")
  end

  test "a non-positive principal returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/compound_interest",
        params: { inputs: { principal: "0", annual_rate: "5", years: "10", compounding: "monthly" } },
        as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_equal "compound_interest", body["calculator"]
    assert body.dig("errors", "principal").present?
  end

  test "an unknown compounding mode returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/compound_interest",
        params: { inputs: { principal: "20000", annual_rate: "5", years: "10", compounding: "weekly" } },
        as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "compounding"), "is not included in the list"
  end

  test "a missing years value returns the 422 error envelope and records nothing" do
    assert_no_difference "Calculation.count" do
      post "/calculators/compound_interest",
        params: { inputs: { principal: "20000", annual_rate: "5", compounding: "monthly" } },
        as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert body.dig("errors", "years").present?
  end

  test "a non-numeric annual_rate returns 422 and records nothing (Base numeric guard)" do
    assert_no_difference "Calculation.count" do
      post "/calculators/compound_interest",
        params: { inputs: { principal: "20000", annual_rate: "abc", years: "10", compounding: "monthly" } },
        as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_not body["ok"]
    assert_includes body.dig("errors", "annual_rate"), "is not a number"
  end

  test "a successful calculation records a Calculation row" do
    assert_difference "Calculation.count", 1 do
      post "/calculators/compound_interest",
        params: { inputs: { principal: "5000", annual_rate: "8", years: "3", compounding: "quarterly" } },
        as: :json
    end

    record = Calculation.last
    assert_equal "compound_interest", record.calculator
    assert_equal "quarterly", record.inputs["compounding"]
    assert_equal "6341.21", record.result["future_value"]
  end

  test "scientific-notation principal is accepted, not rejected as garbage" do
    # "2e4" principal must compute as 20000, identical to the "20000" reference case.
    post "/calculators/compound_interest",
      params: { inputs: { principal: "2e4", annual_rate: "5", years: "10", compounding: "monthly" } },
      as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["ok"]
    assert_equal BigDecimal("20000"), BigDecimal(body.dig("inputs", "principal"))
    assert_equal "32940.19", body.dig("result", "future_value")
  end
end
