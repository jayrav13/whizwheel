require "test_helper"

# Integration tests for the House Affordability calculator page (issue #259) — the mortgage
# math run IN REVERSE: from income, debts, down payment, rate/term and the DTI ratios it
# derives the max monthly housing payment, then inverts amortization to the max loan amount
# and max home price (the hero). The GET page renders its ten inputs (single-mode form, no
# mode picker); the POST Turbo Stream response renders the right result fragment for each
# state (the hero max home price, the budget stat grid, the housing-budget donut, and 422
# errors). These assert the markup the system test then verifies visually; together they are
# the §11 frontend gate. Math correctness is the backend's gate; here we assert the page
# surfaces the envelope's result keys.
#
# Reference values are the spec's row 1: income 120000, debts 500, down 60000, 6%/30y, 28/36
# DTI, tax 250, insurance 100, hoa 0 → gross 10000.00, max_monthly_housing 2800.00, max_pi
# 2450.00, max_loan 408639.46, max_home_price 468639.46.
class HouseAffordabilityPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # The spec's row-1 inputs — used across the success-state tests.
  ROW1 = {
    annual_income: "120000", monthly_debts: "500", down_payment: "60000",
    annual_rate: "6", loan_term_years: "30", front_dti: "28", back_dti: "36",
    monthly_property_tax: "250", monthly_home_insurance: "100", monthly_hoa: "0"
  }.freeze

  # ── GET /calculators/house_affordability ─────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/house_affordability"
    assert_response :success
    assert_select "h1", text: "House Affordability Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders all ten labeled inputs" do
    get "/calculators/house_affordability"
    assert_select "label[for=inputs_annual_income]", text: /Annual income/
    assert_select "input#inputs_annual_income[name='inputs[annual_income]']"
    assert_select "label[for=inputs_monthly_debts]", text: /Monthly debts/
    assert_select "input#inputs_monthly_debts[name='inputs[monthly_debts]']"
    assert_select "label[for=inputs_down_payment]", text: /Down payment/
    assert_select "input#inputs_down_payment[name='inputs[down_payment]']"
    assert_select "label[for=inputs_annual_rate]", text: /Annual interest rate/
    assert_select "input#inputs_annual_rate[name='inputs[annual_rate]']"
    assert_select "label[for=inputs_loan_term_years]", text: /Loan term/
    assert_select "input#inputs_loan_term_years[name='inputs[loan_term_years]']"
    assert_select "label[for=inputs_front_dti]", text: /Front-end DTI/
    assert_select "input#inputs_front_dti[name='inputs[front_dti]']"
    assert_select "label[for=inputs_back_dti]", text: /Back-end DTI/
    assert_select "input#inputs_back_dti[name='inputs[back_dti]']"
    assert_select "label[for=inputs_monthly_property_tax]", text: /Monthly property tax/
    assert_select "input#inputs_monthly_property_tax[name='inputs[monthly_property_tax]']"
    assert_select "label[for=inputs_monthly_home_insurance]", text: /Monthly home insurance/
    assert_select "input#inputs_monthly_home_insurance[name='inputs[monthly_home_insurance]']"
    assert_select "label[for=inputs_monthly_hoa]", text: /Monthly HOA fee/
    assert_select "input#inputs_monthly_hoa[name='inputs[monthly_hoa]']"
  end

  test "the term field steps by whole years" do
    get "/calculators/house_affordability"
    assert_select "input#inputs_loan_term_years[step='1']"
  end

  test "the form is a plain single-mode form with no mode picker" do
    get "/calculators/house_affordability"
    # No mode/variant picker — the inputs don't depend on a chosen mode (spec Notes, DESIGN.md §4).
    assert_select "input[name='inputs[mode]']", count: 0
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/house_affordability"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST — Turbo Stream success ──────────────────────────────────────────

  test "a calculation renders the hero maximum home price with the loan + down payment" do
    post "/calculators/house_affordability", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    assert_select "section#result", text: /Maximum home price/i
    assert_select "section#result", text: /468,639\.46/  # max home price (hero)
    assert_select "section#result", text: /408,639\.46/  # max loan amount called out
    assert_select "section#result", text: /60,000\.00/   # down payment called out
  end

  test "a calculation renders the budget stat grid figures" do
    post "/calculators/house_affordability", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /10,000\.00/  # gross monthly income
    assert_select "section#result", text: /2,800\.00/   # max monthly housing
    assert_select "section#result", text: /2,450\.00/   # principal & interest room
  end

  test "the stat grid is the shared wide-track component sitting on the page background" do
    post "/calculators/house_affordability", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    # The shared responsive stat grid (DESIGN.md §4 "Stat grid", issue #143): a `.stat-grid`
    # of four `.stat-card`s. The max loan/price run high-magnitude → the `--wide` track. The
    # grid sits on the page bg, so the cards use the `.stat-card--surface` variant.
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card.stat-card--surface", count: 4
  end

  test "the result renders the housing-budget donut with its no-JS fallback and legend" do
    post "/calculators/house_affordability", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    # The no-JS fallback is always rendered server-side (DESIGN.md §4 / §6): a labelled
    # conic-gradient donut image + a text legend naming every present component.
    assert_select "section#result [role=img][aria-label*='Monthly housing budget']"
    assert_select "section#result", text: /Monthly housing budget/i
    assert_select "section#result", text: /Principal & interest/
    assert_select "section#result", text: /Property tax/
    assert_select "section#result", text: /Home insurance/
    # HOA is 0 in row 1, so its slice is dropped (no legend row).
    assert_select "section#result", text: /HOA/, count: 0
  end

  test "the result wires the interactive JS donut canvas and its data" do
    post "/calculators/house_affordability", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    # The hover-capable JS donut (DESIGN.md §4): a Chart.js canvas hidden until the controller
    # draws it, with its fallback alongside; the controller reads the slices from the
    # data-*-value attribute.
    assert_select "section#result [data-controller=house-affordability]"
    assert_select "section#result [data-house-affordability-target=donutCanvas] canvas"
    assert_select "section#result [data-house-affordability-target=donutFallback]"
    assert_select "section#result [data-house-affordability-donut-value]"
  end

  test "the zero-rate case computes the loan as max_pi times the term" do
    # r = 0 edge: max_loan = max_pi × n. income 120000, 28% front → housing 2800, no fixed
    # costs → max_pi 2800; 10-year (120-month) term → loan 336000.00; + 0 down → price 336000.00.
    post "/calculators/house_affordability", params: {
      inputs: {
        annual_income: "120000", monthly_debts: "0", down_payment: "0",
        annual_rate: "0", loan_term_years: "10", front_dti: "28", back_dti: "36",
        monthly_property_tax: "0", monthly_home_insurance: "0", monthly_hoa: "0"
      }
    }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /336,000\.00/
  end

  test "the responsive stat grid renders a large 7-digit loan without clipping" do
    # Worst-case stat-grid test (frontend agent: "test the worst case"): a high income with a
    # large down payment pushes the max loan amount past seven figures. The auto-fit grid sizes
    # each card to a min width and flows, so a large value must render in full (no
    # truncation/overflow) — we assert the comma-grouped 7-digit figure reached the card.
    post "/calculators/house_affordability", params: {
      inputs: {
        annual_income: "600000", monthly_debts: "0", down_payment: "0",
        annual_rate: "5", loan_term_years: "30", front_dti: "28", back_dti: "36",
        monthly_property_tax: "0", monthly_home_insurance: "0", monthly_hoa: "0"
      }
    }, headers: TURBO
    assert_response :success
    # The max loan amount clears $2M ($2,6xx,xxx.xx) — a 7-figure comma-grouped value present
    # in a stat-card dd proves the big number reached the card intact.
    assert_select "section#result dl dd", text: /\A\$2,\d{3},\d{3}\.\d{2}\z/
  end

  # ── POST — Turbo Stream 422 (invalid) ────────────────────────────────────

  test "missing required inputs render the error fragment with 422" do
    post "/calculators/house_affordability", params: {
      inputs: { annual_income: "", annual_rate: "", loan_term_years: "", front_dti: "", back_dti: "" }
    }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/house_affordability", params: {
      inputs: { annual_income: "", annual_rate: "", loan_term_years: "", front_dti: "", back_dti: "" }
    }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Annual income can't be blank"
    assert_select "section#result [role=alert] li", text: /Front-end DTI/
  end

  test "constraints that leave no P&I room surface as a validation error, not a 500" do
    # Debts + tax/insurance exhaust the DTI ceiling → max_pi ≤ 0 → no home affordable (spec
    # edge case). The :base error is a full sentence with no label prefix (DESIGN.md §4).
    post "/calculators/house_affordability", params: {
      inputs: {
        annual_income: "30000", monthly_debts: "2000", down_payment: "0",
        annual_rate: "6", loan_term_years: "30", front_dti: "28", back_dti: "36",
        monthly_property_tax: "800", monthly_home_insurance: "200", monthly_hoa: "0"
      }
    }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result [role=alert] li", text: /No home is affordable/
  end
end
