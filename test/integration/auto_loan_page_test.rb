require "test_helper"

# Integration tests for the Auto Loan calculator page (issue #251) — an amortized auto
# loan with the auto-specific amount-financed roll-up (trade-in, down payment, sales tax,
# fees). The GET page renders its three required + four optional inputs; the POST Turbo
# Stream response renders the right result fragment for each state (the hero monthly
# payment, the amount-financed breakdown, the totals stat grid, the donut + balance-curve
# charts, the schedule table, and 422 errors). These assert the markup the system test then
# verifies visually; together they are the §11 frontend gate. Math correctness is the
# backend's gate; here we assert the page surfaces the envelope's result keys.
#
# Reference values are the spec's row-1 anchor (issue #251):
#   30000 / 60mo / 5% / down 4000 / trade 6000 / tax 7% / fees 800 →
#   sales_tax 1680.00, amount_financed 22480.00, monthly 424.23, total_paid 25453.48,
#   total_interest 2973.48; month-1 interest 93.67, principal 330.56, balance 22149.44.
class AutoLoanPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  ANCHOR = {
    auto_price: "30000", term_months: "60", annual_rate: "5",
    down_payment: "4000", trade_in: "6000", sales_tax_rate: "7", fees: "800"
  }.freeze

  # ── GET /calculators/auto_loan ──────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/auto_loan"
    assert_response :success
    assert_select "h1", text: "Auto Loan Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders the three required labeled inputs" do
    get "/calculators/auto_loan"
    assert_select "label[for=inputs_auto_price]", text: /Vehicle price/
    assert_select "input#inputs_auto_price[name='inputs[auto_price]']"
    assert_select "label[for=inputs_term_months]", text: /Loan term/
    assert_select "input#inputs_term_months[name='inputs[term_months]']"
    assert_select "label[for=inputs_annual_rate]", text: /Annual interest rate/
    assert_select "input#inputs_annual_rate[name='inputs[annual_rate]']"
  end

  test "page renders the four optional adjustment inputs" do
    get "/calculators/auto_loan"
    assert_select "label[for=inputs_down_payment]", text: /Down payment/
    assert_select "input#inputs_down_payment[name='inputs[down_payment]']"
    assert_select "label[for=inputs_trade_in]", text: /Trade-in value/
    assert_select "input#inputs_trade_in[name='inputs[trade_in]']"
    assert_select "label[for=inputs_sales_tax_rate]", text: /Sales tax/
    assert_select "input#inputs_sales_tax_rate[name='inputs[sales_tax_rate]']"
    assert_select "label[for=inputs_fees]", text: /fees/
    assert_select "input#inputs_fees[name='inputs[fees]']"
  end

  test "the term field steps by whole months" do
    get "/calculators/auto_loan"
    assert_select "input#inputs_term_months[step='1']"
  end

  test "the form is a plain single-mode form with no mode picker" do
    get "/calculators/auto_loan"
    # No mode/variant picker — the inputs don't depend on a chosen mode (DESIGN.md §4).
    assert_select "input[name='inputs[mode]']", count: 0
    assert_select "fieldset legend", count: 0
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/auto_loan"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/auto_loan — Turbo Stream success ───────────────────

  test "a calculation renders the hero monthly payment and amount financed" do
    post "/calculators/auto_loan", params: { inputs: ANCHOR }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    assert_select "section#result", text: /Monthly payment/i
    assert_select "section#result", text: /424\.23/    # level monthly payment
    assert_select "section#result", text: /22,480\.00/ # amount financed (delimited)
  end

  test "the result renders the totals in the stat grid" do
    post "/calculators/auto_loan", params: { inputs: ANCHOR }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /25,453\.48/ # total of payments
    assert_select "section#result", text: /2,973\.48/  # total interest
    assert_select "section#result", text: /60/         # number of payments
  end

  test "the result renders the amount-financed breakdown roll-up" do
    post "/calculators/auto_loan", params: { inputs: ANCHOR }, headers: TURBO
    assert_response :success
    # The auto-specific story: price + tax + fees − down − trade-in → amount financed.
    assert_select "section#result", text: /Amount financed/i
    assert_select "section#result", text: /Vehicle price/i
    assert_select "section#result", text: /Sales tax/i
    assert_select "section#result", text: /Trade-in value/i
    assert_select "section#result", text: /1,680\.00/  # the computed sales tax
  end

  test "the breakdown omits zero adjustment rows" do
    # A bare loan (no down/trade/tax/fees) shows only the vehicle-price row — no rows of
    # zeros. sales_tax is 0.00 so its row is dropped too.
    post "/calculators/auto_loan", params: { inputs: { auto_price: "20000", term_months: "36", annual_rate: "0" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /Vehicle price/i
    assert_select "section#result dt", text: "Down payment", count: 0
    assert_select "section#result dt", text: "Trade-in value", count: 0
  end

  test "the result renders the donut and balance-curve charts (with no-JS fallbacks)" do
    post "/calculators/auto_loan", params: { inputs: ANCHOR }, headers: TURBO
    assert_response :success
    # The no-JS fallbacks are always rendered server-side (DESIGN.md §4 / §6): a labelled
    # donut image with the financed-vs-interest breakdown + the SVG balance curve line.
    assert_select "section#result [role=img][aria-label*='Amount financed']"
    assert_select "section#result svg polyline" # the balance curve line
    assert_select "section#result", text: /Where your money goes/i
    assert_select "section#result", text: /Balance over time/i
  end

  test "the result wires the interactive JS chart canvases and their data" do
    post "/calculators/auto_loan", params: { inputs: ANCHOR }, headers: TURBO
    assert_response :success
    # The hover-capable JS charts (DESIGN.md §4): a Chart.js donut canvas and a
    # lightweight-charts curve container, each hidden until the controller draws it, with
    # its fallback alongside. The controller reads the series from data-*-value attributes.
    assert_select "section#result [data-auto-loan-target=donutCanvas] canvas"
    assert_select "section#result [data-auto-loan-target=donutFallback]"
    assert_select "section#result [data-auto-loan-target=curveCanvas]"
    assert_select "section#result [data-auto-loan-target=curveFallback]"
    assert_select "section#result [data-auto-loan-donut-value]"
    assert_select "section#result [data-auto-loan-curve-value]"
  end

  test "the result renders the schedule table with month-1 and the paid-off final row" do
    post "/calculators/auto_loan", params: { inputs: ANCHOR }, headers: TURBO
    assert_response :success
    assert_select "section#result table thead th", text: "Month"
    assert_select "section#result table tbody tr", count: 60
    # Month-1 breakdown from the spec anchor: interest 93.67, principal 330.56, balance
    # 22,149.44.
    assert_select "section#result table tbody tr:first-child", text: /93\.67/
    assert_select "section#result table tbody tr:first-child", text: /330\.56/
    assert_select "section#result table tbody tr:first-child", text: /22,149\.44/
    # The final row's balance is 0.00 → rendered as "Paid off" (not a money string).
    assert_select "section#result table tbody tr:last-child", text: /Paid off/
  end

  test "the schedule has a hard total row" do
    post "/calculators/auto_loan", params: { inputs: ANCHOR }, headers: TURBO
    assert_response :success
    assert_select "section#result table tfoot tr", text: /Total/
    assert_select "section#result table tfoot tr", text: /25,453\.48/
  end

  test "the result wires the Stimulus auto-loan controller with a show-all toggle" do
    post "/calculators/auto_loan", params: { inputs: ANCHOR }, headers: TURBO
    assert_response :success
    assert_select "section#result [data-controller=auto-loan]"
    assert_select "section#result button[data-action='auto-loan#showAll']"
  end

  test "the responsive stat grid renders large 6+ digit totals without clipping" do
    # Worst-case stat-grid test (frontend agent: "test the worst case"): a luxury vehicle
    # financed long whose total of payments and amount financed run to 6 digits. The auto-fit
    # grid sizes each card to a min width and flows, so a large value must render in full (no
    # truncation/overflow) — we assert the delimited figure is present. The `--wide` track
    # keeps it on one line; the never-clip net is the floor.
    post "/calculators/auto_loan",
      params: { inputs: { auto_price: "150000", term_months: "84", annual_rate: "9", sales_tax_rate: "8", fees: "2000" } },
      headers: TURBO
    assert_response :success
    # Amount financed is comfortably 6-figure ($164,000.00) — the comma-grouped whole part
    # proves the big number reached the card intact.
    assert_select "section#result dl.stat-grid dd", text: /\A\$1\d{2},\d{3}\.\d{2}\z/
    # The grid is the shared responsive stat grid (DESIGN.md §4 "Stat grid", issue #143): a
    # `.stat-grid--wide` of `.stat-card--surface` cards (it sits on the page bg).
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card.stat-card--surface", count: 4
  end

  test "the zero-rate loan computes without interest" do
    post "/calculators/auto_loan", params: { inputs: { auto_price: "20000", term_months: "36", annual_rate: "0", down_payment: "2000" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /500\.00/ # monthly payment 18000/36
    assert_select "section#result table tbody tr", count: 36
  end

  # ── POST /calculators/auto_loan — Turbo Stream 422 (invalid) ─────────────

  test "missing required inputs render the error fragment with 422" do
    post "/calculators/auto_loan", params: { inputs: { auto_price: "", term_months: "", annual_rate: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/auto_loan", params: { inputs: { auto_price: "", term_months: "", annual_rate: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Vehicle price can't be blank"
    assert_select "section#result [role=alert] li", text: /Loan term/
  end

  test "a financed amount that nets to zero or below surfaces as a validation error" do
    # Trade-in + down payment exceeding the taxed price leaves nothing to finance — the
    # backend rejects amount_financed <= 0; the FE surfaces it as a base error, not a 500.
    post "/calculators/auto_loan",
      params: { inputs: { auto_price: "10000", term_months: "36", annual_rate: "5", down_payment: "5000", trade_in: "6000" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result [role=alert] li", text: /amount financed/i
  end
end
