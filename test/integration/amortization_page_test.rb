require "test_helper"

# Integration tests for the Amortization calculator page (issue #84) — the project's
# first tabular-output + charts page. The GET page renders its three inputs; the POST
# Turbo Stream response renders the right result fragment for each state (the hero
# monthly payment, the totals stat grid, the donut + balance-curve charts, the schedule
# table, and 422 errors). These assert the markup the system test then verifies visually;
# together they are the §11 frontend gate. Math correctness is the backend's gate; here
# we assert the page surfaces the envelope's result keys.
class AmortizationPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/amortization ───────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/amortization"
    assert_response :success
    assert_select "h1", text: "Amortization Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders the three labeled inputs" do
    get "/calculators/amortization"
    assert_select "label[for=inputs_principal]", text: /Loan amount/
    assert_select "input#inputs_principal[name='inputs[principal]']"
    assert_select "label[for=inputs_annual_rate]", text: /Annual interest rate/
    assert_select "input#inputs_annual_rate[name='inputs[annual_rate]']"
    assert_select "label[for=inputs_years]", text: /Loan term/
    assert_select "input#inputs_years[name='inputs[years]']"
  end

  test "the term field steps by whole years" do
    get "/calculators/amortization"
    assert_select "input#inputs_years[step='1']"
  end

  test "the form is a plain single-mode form with no mode picker" do
    get "/calculators/amortization"
    # No mode/variant picker — the inputs don't depend on a chosen mode (DESIGN.md §4).
    assert_select "input[name='inputs[mode]']", count: 0
    assert_select "fieldset legend", count: 0
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/amortization"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/amortization — Turbo Stream success ────────────────

  test "a calculation renders the hero monthly payment and totals" do
    post "/calculators/amortization", params: { inputs: { principal: "100000", annual_rate: "6", years: "30" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    assert_select "section#result", text: /Monthly payment/i
    assert_select "section#result", text: /599\.55/      # level payment
    assert_select "section#result", text: /215,838\.45/  # total of payments (delimited)
    assert_select "section#result", text: /115,838\.45/  # total interest
    assert_select "section#result", text: /360/          # number of payments
  end

  test "the result renders the donut and balance-curve charts" do
    post "/calculators/amortization", params: { inputs: { principal: "100000", annual_rate: "6", years: "30" } }, headers: TURBO
    assert_response :success
    # Donut: a labelled image with the principal-vs-interest breakdown.
    assert_select "section#result [role=img][aria-label*='Principal']"
    assert_select "section#result svg polyline" # the balance curve line
    assert_select "section#result", text: /Where your money goes/i
    assert_select "section#result", text: /Balance over time/i
  end

  test "the result renders the schedule table with month-1 and the paid-off final row" do
    post "/calculators/amortization", params: { inputs: { principal: "100000", annual_rate: "6", years: "30" } }, headers: TURBO
    assert_response :success
    assert_select "section#result table thead th", text: "Month"
    # Month-1 breakdown from the spec: interest 500.00, principal 99.55, balance 99,900.45.
    assert_select "section#result table tbody tr", count: 360
    assert_select "section#result table tbody tr:first-child", text: /500\.00/
    assert_select "section#result table tbody tr:first-child", text: /99\.55/
    assert_select "section#result table tbody tr:first-child", text: /99,900\.45/
    # The final row's balance is 0.00 → rendered as "Paid off" (not a money string).
    assert_select "section#result table tbody tr:last-child", text: /Paid off/
  end

  test "the schedule has a hard total row" do
    post "/calculators/amortization", params: { inputs: { principal: "100000", annual_rate: "6", years: "30" } }, headers: TURBO
    assert_response :success
    assert_select "section#result table tfoot tr", text: /Total/
    assert_select "section#result table tfoot tr", text: /215,838\.45/
  end

  test "the result wires the Stimulus amortization controller with a show-all toggle" do
    post "/calculators/amortization", params: { inputs: { principal: "100000", annual_rate: "6", years: "30" } }, headers: TURBO
    assert_response :success
    assert_select "section#result [data-controller=amortization]"
    assert_select "section#result button[data-action='amortization#showAll']"
  end

  test "the zero-rate loan computes without interest" do
    post "/calculators/amortization", params: { inputs: { principal: "12000", annual_rate: "0", years: "1" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /1,000\.00/ # monthly payment 12000/12
    assert_select "section#result table tbody tr", count: 12
  end

  # ── POST /calculators/amortization — Turbo Stream 422 (invalid) ──────────

  test "missing required inputs render the error fragment with 422" do
    post "/calculators/amortization", params: { inputs: { principal: "", annual_rate: "", years: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/amortization", params: { inputs: { principal: "", annual_rate: "", years: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Loan amount can't be blank"
    assert_select "section#result [role=alert] li", text: /Loan term/
  end

  test "a non-positive principal surfaces as a validation error, not a 500" do
    post "/calculators/amortization", params: { inputs: { principal: "0", annual_rate: "5", years: "10" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
  end
end
