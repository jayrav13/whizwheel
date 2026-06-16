require "test_helper"

# Integration tests for the Personal Loan calculator page (issue #256) — the single-mode
# loan-core skin of the loan cluster. The GET page renders the three fields and the submit;
# the POST Turbo Stream response renders the result fragment (the monthly-payment hero, the
# loan figures + totals stat grid, the principal-vs-interest donut + balance curve charts,
# and the schedule table) and 422 errors. These assert the markup the system test then
# verifies visually; together they are the §11 frontend gate. Math correctness is the
# backend's gate (personal_loan reference-value tests); here we assert the page surfaces the
# envelope's result keys.
class PersonalLoanPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/personal_loan ──────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/personal_loan"
    assert_response :success
    assert_select "h1", text: "Personal Loan Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders every input with a labelled, affixed field" do
    get "/calculators/personal_loan"
    assert_select "label[for=inputs_loan_amount]", text: /Loan amount/
    assert_select "input#inputs_loan_amount[name='inputs[loan_amount]']"
    assert_select "label[for=inputs_annual_rate]", text: /Annual interest rate/
    assert_select "input#inputs_annual_rate[name='inputs[annual_rate]']"
    assert_select "label[for=inputs_term_months]", text: /Loan term/
    assert_select "input#inputs_term_months[name='inputs[term_months]']"
  end

  test "the term field steps by whole months" do
    get "/calculators/personal_loan"
    assert_select "input#inputs_term_months[step='1']"
  end

  test "the page is single-mode — no mode picker is rendered" do
    # The spec is explicit: no mode picker (always solves the monthly payment).
    get "/calculators/personal_loan"
    assert_select "input[type=radio][name='inputs[mode]']", count: 0
    assert_select "label.mode-option", count: 0
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/personal_loan"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/personal_loan — Turbo Stream success ──────────────

  test "computes the monthly payment and renders the hero + totals" do
    post "/calculators/personal_loan",
      params: { inputs: { loan_amount: "15000", annual_rate: "7", term_months: "36" } },
      headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # The hero is the level monthly payment; the totals appear beneath.
    assert_select "section#result", text: /Monthly payment/i
    assert_select "section#result", text: /463\.16/     # level payment (the hero)
    assert_select "section#result", text: /16,673\.61/  # total of payments (delimited)
    assert_select "section#result", text: /1,673\.61/   # total interest
  end

  test "the result renders the figures + totals stat grid (the shared wide component)" do
    post "/calculators/personal_loan",
      params: { inputs: { loan_amount: "15000", annual_rate: "7", term_months: "36" } },
      headers: TURBO
    assert_response :success
    # DESIGN.md §4 "Stat grid" (issue #143): the shared `.stat-grid` / `.stat-card`
    # component, never a per-page inline width. The worst-case money totals run
    # high-magnitude, so the grid uses the `--wide` track, and sits on the page bg
    # (`.stat-card--surface`). Five figures: amount, payment, term, total paid, total interest.
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card.stat-card--surface", count: 5
  end

  test "the result wires the personal-loan Stimulus controller and its chart data" do
    post "/calculators/personal_loan",
      params: { inputs: { loan_amount: "15000", annual_rate: "7", term_months: "36" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result [data-controller=personal-loan]"
    # The donut + curve series are wired as data values for the JS charts.
    assert_select "[data-personal-loan-donut-value]"
    assert_select "[data-personal-loan-curve-value]"
  end

  test "the result renders both charts with their no-JS fallbacks" do
    post "/calculators/personal_loan",
      params: { inputs: { loan_amount: "15000", annual_rate: "7", term_months: "36" } },
      headers: TURBO
    assert_response :success
    # Chart eyebrows + the always-present no-JS fallbacks (DESIGN.md §4 "Charts"): the donut
    # canvas + conic fallback, and the curve canvas + SVG fallback.
    assert_select "section#result", text: /Where your money goes/i
    assert_select "section#result", text: /Balance over time/i
    assert_select "[data-personal-loan-target=donutCanvas] canvas"
    assert_select "[data-personal-loan-target=donutFallback]"
    assert_select "[data-personal-loan-target=curveCanvas]"
    assert_select "[data-personal-loan-target=curveFallback] svg polyline"
  end

  test "the donut legend names principal and total interest without colour alone" do
    post "/calculators/personal_loan",
      params: { inputs: { loan_amount: "15000", annual_rate: "7", term_months: "36" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /Principal/
    assert_select "section#result", text: /Total interest/
  end

  test "the result renders the schedule table with month-1 and the paid-off final row" do
    post "/calculators/personal_loan",
      params: { inputs: { loan_amount: "15000", annual_rate: "7", term_months: "36" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result table thead th", text: "Month"
    assert_select "section#result table tbody tr", count: 36
    # Month-1 breakdown from the spec anchor: interest 87.50, principal 375.66, balance 14,624.34.
    assert_select "section#result table tbody tr:first-child", text: /87\.50/
    assert_select "section#result table tbody tr:first-child", text: /375\.66/
    assert_select "section#result table tbody tr:first-child", text: /14,624\.34/
    # The final row's balance is 0.00 → rendered as "Paid off" (not a money string).
    assert_select "section#result table tbody tr:last-child", text: /Paid off/
  end

  test "the schedule has a hard total row" do
    post "/calculators/personal_loan",
      params: { inputs: { loan_amount: "15000", annual_rate: "7", term_months: "36" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result table tfoot tr", text: /Total/
    assert_select "section#result table tfoot tr", text: /16,673\.61/
  end

  test "the responsive wide stat grid renders large 7-digit totals without clipping" do
    # Worst-case stat-grid test (frontend agent: "test the worst case"): a large, long-term
    # personal loan whose total of payments runs to 7 digits. The `--wide` auto-fit grid must
    # render the large value in full (no truncation/overflow) — we assert the delimited figure
    # is present.
    post "/calculators/personal_loan",
      params: { inputs: { loan_amount: "1000000", annual_rate: "12", term_months: "120" } },
      headers: TURBO
    assert_response :success
    # Total of payments is comfortably 7-figure ($1,721,651.90) — the comma-grouped whole part
    # proves the big number reached the card intact.
    assert_select "section#result dl.stat-grid--wide dd", text: /\A\$1,721,651\.90\z/
  end

  test "the zero-rate loan computes without interest" do
    post "/calculators/personal_loan",
      params: { inputs: { loan_amount: "5000", annual_rate: "0", term_months: "12" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /416\.67/    # monthly payment 5000/12
    assert_select "section#result table tbody tr", count: 12
  end

  # ── POST /calculators/personal_loan — Turbo Stream 422 (invalid) ────────

  test "missing required inputs render the error fragment with 422" do
    post "/calculators/personal_loan",
      params: { inputs: { loan_amount: "", annual_rate: "", term_months: "" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/personal_loan",
      params: { inputs: { loan_amount: "", annual_rate: "7", term_months: "36" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Loan amount can't be blank"
  end
end
