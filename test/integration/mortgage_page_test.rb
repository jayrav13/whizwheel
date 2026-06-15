require "test_helper"

# Integration tests for the Mortgage calculator page (issue #187) — a tabular-output +
# charts page built on the Amortization components, extended for the multi-component monthly
# payment (P&I + property tax + home insurance + HOA). The GET page renders its seven inputs
# (the required loan basis + the optional recurring costs); the POST Turbo Stream response
# renders the right result fragment for each state (the hero total monthly payment, the totals
# stat grid, the payment-component donut + balance-curve charts, the P&I schedule table, and
# 422 errors). These assert the markup the system test then verifies visually; together they
# are the §11 frontend gate. Math correctness is the backend's gate; here we assert the page
# surfaces the envelope's result keys.
#
# Reference values are the spec's row 1: home_price 360000, down_payment 60000, rate 7%, 30y,
# tax 3500/yr, insurance 1200/yr, HOA 50/mo → loan 300000.00, P&I 1995.91, tax 291.67,
# insurance 100.00, HOA 50.00, total monthly 2437.58, total interest 418524.05, total of P&I
# 718524.05, 360 payments.
class MortgagePageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # The spec's row-1 inputs — used across the success-state tests.
  ROW1 = {
    home_price: "360000", down_payment: "60000", annual_rate: "7", loan_term_years: "30",
    annual_property_tax: "3500", annual_home_insurance: "1200", monthly_hoa: "50"
  }.freeze

  # ── GET /calculators/mortgage ───────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/mortgage"
    assert_response :success
    assert_select "h1", text: "Mortgage Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders all seven labeled inputs" do
    get "/calculators/mortgage"
    assert_select "label[for=inputs_home_price]", text: /Home price/
    assert_select "input#inputs_home_price[name='inputs[home_price]']"
    assert_select "label[for=inputs_down_payment]", text: /Down payment/
    assert_select "input#inputs_down_payment[name='inputs[down_payment]']"
    assert_select "label[for=inputs_annual_rate]", text: /Annual interest rate/
    assert_select "input#inputs_annual_rate[name='inputs[annual_rate]']"
    assert_select "label[for=inputs_loan_term_years]", text: /Loan term/
    assert_select "input#inputs_loan_term_years[name='inputs[loan_term_years]']"
    assert_select "label[for=inputs_annual_property_tax]", text: /Annual property tax/
    assert_select "input#inputs_annual_property_tax[name='inputs[annual_property_tax]']"
    assert_select "label[for=inputs_annual_home_insurance]", text: /Annual home insurance/
    assert_select "input#inputs_annual_home_insurance[name='inputs[annual_home_insurance]']"
    assert_select "label[for=inputs_monthly_hoa]", text: /Monthly HOA fee/
    assert_select "input#inputs_monthly_hoa[name='inputs[monthly_hoa]']"
  end

  test "the term field steps by whole years" do
    get "/calculators/mortgage"
    assert_select "input#inputs_loan_term_years[step='1']"
  end

  test "the form is a plain single-mode form with no mode picker" do
    get "/calculators/mortgage"
    # No mode/variant picker — the inputs don't depend on a chosen mode (DESIGN.md §4).
    assert_select "input[name='inputs[mode]']", count: 0
    assert_select "fieldset legend", count: 0
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/mortgage"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/mortgage — Turbo Stream success ────────────────────

  test "a calculation renders the hero total monthly payment with the P&I portion" do
    post "/calculators/mortgage", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    assert_select "section#result", text: /Monthly payment/i
    assert_select "section#result", text: /2,437\.58/  # total monthly payment (hero)
    assert_select "section#result", text: /1,995\.91/  # P&I portion called out
    assert_select "section#result", text: /360/        # number of payments
  end

  test "a calculation renders the loan totals stat grid" do
    post "/calculators/mortgage", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /300,000\.00/  # loan amount
    assert_select "section#result", text: /718,524\.05/  # total of P&I
    assert_select "section#result", text: /418,524\.05/  # total interest
  end

  test "the result renders the payment-component donut and balance curve (with no-JS fallbacks)" do
    post "/calculators/mortgage", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    # The no-JS fallbacks are always rendered server-side (DESIGN.md §4 / §6): a labelled
    # donut image with the four-component breakdown + the SVG balance curve line.
    assert_select "section#result [role=img][aria-label*='Principal & interest']"
    assert_select "section#result svg polyline" # the balance curve line
    assert_select "section#result", text: /Monthly payment breakdown/i
    assert_select "section#result", text: /Balance over time/i
    # The legend names every payment component (the four-slice breakdown).
    assert_select "section#result", text: /Property tax/
    assert_select "section#result", text: /Home insurance/
    assert_select "section#result", text: /HOA/
  end

  test "the result wires the interactive JS chart canvases and their data" do
    post "/calculators/mortgage", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    # The hover-capable JS charts (DESIGN.md §4): a Chart.js donut canvas and a
    # lightweight-charts curve container, each hidden until the controller draws it, with its
    # fallback alongside. The controller reads the series from data-*-value attributes.
    assert_select "section#result [data-mortgage-target=donutCanvas] canvas"
    assert_select "section#result [data-mortgage-target=donutFallback]"
    assert_select "section#result [data-mortgage-target=curveCanvas]"
    assert_select "section#result [data-mortgage-target=curveFallback]"
    assert_select "section#result [data-mortgage-donut-value]"
    assert_select "section#result [data-mortgage-curve-value]"
  end

  test "the result renders the P&I schedule table with month-1 and the paid-off final row" do
    post "/calculators/mortgage", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    assert_select "section#result table thead th", text: "Month"
    assert_select "section#result table tbody tr", count: 360
    # Month-1 breakdown from the spec: interest 1750.00, principal 245.91, balance 299754.09.
    assert_select "section#result table tbody tr:first-child", text: /1,750\.00/
    assert_select "section#result table tbody tr:first-child", text: /245\.91/
    assert_select "section#result table tbody tr:first-child", text: /299,754\.09/
    # The final row's balance is 0.00 → rendered as "Paid off" (not a money string).
    assert_select "section#result table tbody tr:last-child", text: /Paid off/
  end

  test "the schedule has a hard total row totalling the P&I payments" do
    post "/calculators/mortgage", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    assert_select "section#result table tfoot tr", text: /Total/
    assert_select "section#result table tfoot tr", text: /718,524\.05/  # total of P&I
  end

  test "the result wires the Stimulus mortgage controller with a show-all toggle" do
    post "/calculators/mortgage", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    assert_select "section#result [data-controller=mortgage]"
    assert_select "section#result button[data-action='mortgage#showAll']"
  end

  test "the stat grid is the shared wide-track component sitting on the page background" do
    post "/calculators/mortgage", params: { inputs: ROW1 }, headers: TURBO
    assert_response :success
    # The shared responsive stat grid (DESIGN.md §4 "Stat grid", issue #143): a `.stat-grid`
    # of four `.stat-card`s. High-magnitude money totals → the `--wide` track. The grid sits
    # on the page bg, so the cards use the `.stat-card--surface` variant (solid white).
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card.stat-card--surface", count: 4
  end

  test "the responsive stat grid renders large 7-digit totals without clipping" do
    # Worst-case stat-grid test (frontend agent: "test the worst case"): a $1.2M home with a
    # $200k down payment over 30y at 7% → ~$2.39M total of P&I, comfortably 7-figure. The
    # auto-fit grid sizes each card to a min width and flows, so a large value must render in
    # full (no truncation/overflow) — we assert the delimited figure is present.
    post "/calculators/mortgage", params: {
      inputs: { home_price: "1200000", down_payment: "200000", annual_rate: "7", loan_term_years: "30" }
    }, headers: TURBO
    assert_response :success
    # Total of P&I is comfortably 7-figure ($2,3xx,xxx.xx) — the comma-grouped whole part
    # proves the big number reached the card intact.
    assert_select "section#result dl dd", text: /\A\$2,3\d{2},\d{3}\.\d{2}\z/
  end

  test "omitted recurring costs are treated as zero and drop from the donut" do
    # tax/insurance/HOA omitted → total_monthly == pi_monthly; only the P&I slice draws (a
    # zero-amount component contributes no slice and isn't in the legend).
    post "/calculators/mortgage", params: {
      inputs: { home_price: "250000", down_payment: "50000", annual_rate: "6", loan_term_years: "15" }
    }, headers: TURBO
    assert_response :success
    # P&I-only payment from the spec's row 2: 1687.71 monthly.
    assert_select "section#result", text: /1,687\.71/
    # Only the P&I slice in the legend — no Property tax / Home insurance / HOA rows.
    assert_select "section#result", text: /Principal & interest/
    assert_select "section#result", text: /Property tax/, count: 0
    assert_select "section#result", text: /Home insurance/, count: 0
  end

  test "the zero-rate loan computes without interest" do
    post "/calculators/mortgage", params: {
      inputs: { home_price: "120000", down_payment: "0", annual_rate: "0", loan_term_years: "1" }
    }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /10,000\.00/ # P&I 120000/12
    assert_select "section#result table tbody tr", count: 12
  end

  # ── POST /calculators/mortgage — Turbo Stream 422 (invalid) ──────────────

  test "missing required inputs render the error fragment with 422" do
    post "/calculators/mortgage", params: {
      inputs: { home_price: "", down_payment: "", annual_rate: "", loan_term_years: "" }
    }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/mortgage", params: {
      inputs: { home_price: "", down_payment: "", annual_rate: "", loan_term_years: "" }
    }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Home price can't be blank"
    assert_select "section#result [role=alert] li", text: /Loan term/
  end

  test "a down payment at or above the home price surfaces as a validation error, not a 500" do
    post "/calculators/mortgage", params: {
      inputs: { home_price: "200000", down_payment: "200000", annual_rate: "5", loan_term_years: "30" }
    }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result [role=alert] li", text: /Down payment must be less than the home price/
  end
end
