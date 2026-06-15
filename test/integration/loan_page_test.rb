require "test_helper"

# Integration tests for the Loan calculator page (issue #185) — a fixed-rate amortizing
# loan with a solve-for mode picker. The GET page renders its three modes (the selectable
# option list) and the four given-figure fields; the POST Turbo Stream response renders the
# right result fragment for each mode (the solved-for hero, the figures + totals stat grid,
# the schedule table) and 422 errors. These assert the markup the system test then verifies
# visually; together they are the §11 frontend gate. Math correctness is the backend's gate
# (loan reference-value tests); here we assert the page surfaces the envelope's result keys.
class LoanPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/loan ───────────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/loan"
    assert_response :success
    assert_select "h1", text: "Loan Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders all three solve-for mode options" do
    get "/calculators/loan"
    %w[payment amount term].each do |mode|
      assert_select "input[type=radio][name='inputs[mode]'][value=?]", mode
    end
  end

  test "mode picker renders as one option list — a single bordered container of rows" do
    # DESIGN.md §4: three modes but multi-word labels ("Monthly payment", "Loan amount") →
    # the selectable option list, ONE bordered, divided container, not a segmented control.
    get "/calculators/loan"
    assert_select "fieldset div.divide-y" do
      assert_select "label.mode-option", count: 3
    end
  end

  test "each mode row names what it solves and a helper line of what it is given" do
    get "/calculators/loan"
    assert_select "label.mode-option", text: /Monthly payment/, count: 1
    assert_select "label.mode-option", text: /Loan amount/, count: 1
    assert_select "label.mode-option", text: /Term/, count: 1
    assert_select "label.mode-option", text: /Given the loan amount, rate and term/
  end

  test "the first mode is selected by default" do
    get "/calculators/loan"
    assert_select "input[type=radio][name='inputs[mode]'][value=payment][checked=checked]"
  end

  test "page renders every given-figure input with a labelled, affixed field" do
    get "/calculators/loan"
    assert_select "label[for=inputs_loan_amount]", text: /Loan amount/
    assert_select "input#inputs_loan_amount[name='inputs[loan_amount]']"
    assert_select "label[for=inputs_monthly_payment]", text: /Monthly payment/
    assert_select "input#inputs_monthly_payment[name='inputs[monthly_payment]']"
    assert_select "label[for=inputs_annual_rate]", text: /Annual interest rate/
    assert_select "input#inputs_annual_rate[name='inputs[annual_rate]']"
    assert_select "label[for=inputs_term_months]", text: /Loan term/
    assert_select "input#inputs_term_months[name='inputs[term_months]']"
  end

  test "the term field steps by whole months" do
    get "/calculators/loan"
    assert_select "input#inputs_term_months[step='1']"
  end

  test "each field block declares the modes it is given via data-loan-modes" do
    # The Stimulus controller reads these to show only the active mode's given fields.
    get "/calculators/loan"
    assert_select "[data-loan-modes='payment term']"        # loan_amount
    assert_select "[data-loan-modes='amount term']"         # monthly_payment
    assert_select "[data-loan-modes='payment amount term']" # annual_rate (every mode)
    assert_select "[data-loan-modes='payment amount']"      # term_months
  end

  test "page wires the Stimulus loan controller" do
    get "/calculators/loan"
    assert_select "form[data-controller=loan]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/loan"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/loan — Turbo Stream success ───────────────────────

  test "payment mode solves the monthly payment and renders the hero + totals" do
    post "/calculators/loan",
      params: { inputs: { mode: "payment", loan_amount: "25000", annual_rate: "5", term_months: "60" } },
      headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # The hero is the solved-for figure: the monthly payment (471.78), with totals beneath.
    assert_select "section#result", text: /Monthly payment/i
    assert_select "section#result", text: /471\.78/      # level payment (the hero)
    assert_select "section#result", text: /28,306\.88/   # total of payments (delimited)
    assert_select "section#result", text: /3,306\.88/    # total interest
  end

  test "amount mode solves the affordable loan amount as the hero" do
    post "/calculators/loan",
      params: { inputs: { mode: "amount", monthly_payment: "471.78", annual_rate: "5", term_months: "60" } },
      headers: TURBO
    assert_response :success
    # The hero is the solved loan amount (24,999.96 — the cent-rounding inverse of 25,000).
    assert_select "section#result", text: /Loan amount/i
    assert_select "section#result", text: /24,999\.96/
  end

  test "term mode solves the term in whole months as the hero" do
    post "/calculators/loan",
      params: { inputs: { mode: "term", loan_amount: "25000", monthly_payment: "600", annual_rate: "5" } },
      headers: TURBO
    assert_response :success
    # The hero is the solved term: raw n ≈ 45.86 → ceil 46 months.
    assert_select "section#result", text: /Loan term/i
    assert_select "section#result", text: /46 months/
    assert_select "section#result", text: /27,516\.64/  # total of payments
  end

  test "the result renders the figures + totals stat grid (the shared wide component)" do
    post "/calculators/loan",
      params: { inputs: { mode: "payment", loan_amount: "25000", annual_rate: "5", term_months: "60" } },
      headers: TURBO
    assert_response :success
    # DESIGN.md §4 "Stat grid" (issue #143): the shared `.stat-grid` / `.stat-card`
    # component, never a per-page inline width. The worst-case money totals run
    # high-magnitude, so the grid uses the `--wide` track, and sits on the page bg
    # (`.stat-card--surface`). Five figures: payment, amount, term, total paid, total interest.
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card.stat-card--surface", count: 5
  end

  test "the result renders the schedule table with month-1 and the paid-off final row" do
    post "/calculators/loan",
      params: { inputs: { mode: "payment", loan_amount: "25000", annual_rate: "5", term_months: "60" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result table thead th", text: "Month"
    assert_select "section#result table tbody tr", count: 60
    # Month-1 breakdown from the spec anchor: interest 104.17, principal 367.61, balance 24,632.39.
    assert_select "section#result table tbody tr:first-child", text: /104\.17/
    assert_select "section#result table tbody tr:first-child", text: /367\.61/
    assert_select "section#result table tbody tr:first-child", text: /24,632\.39/
    # The final row's balance is 0.00 → rendered as "Paid off" (not a money string).
    assert_select "section#result table tbody tr:last-child", text: /Paid off/
  end

  test "the schedule has a hard total row" do
    post "/calculators/loan",
      params: { inputs: { mode: "payment", loan_amount: "25000", annual_rate: "5", term_months: "60" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result table tfoot tr", text: /Total/
    assert_select "section#result table tfoot tr", text: /28,306\.88/
  end

  test "the responsive stat grid renders large 7-digit totals without clipping" do
    # Worst-case stat-grid test (frontend agent: "test the worst case"): a big loan whose
    # total of payments runs to 7 digits ($200k @ 6%/30y → ~$431,677.04). The `--wide`
    # auto-fit grid must render the large value in full (no truncation/overflow) — we
    # assert the delimited figure is present.
    post "/calculators/loan",
      params: { inputs: { mode: "payment", loan_amount: "200000", annual_rate: "6", term_months: "360" } },
      headers: TURBO
    assert_response :success
    # Total of payments is comfortably 6-figure ($431,677.04) — the comma-grouped whole part
    # proves the big number reached the card intact.
    assert_select "section#result dl dd", text: /\A\$431,677\.04\z/
  end

  test "the zero-rate loan computes without interest" do
    post "/calculators/loan",
      params: { inputs: { mode: "payment", loan_amount: "10000", annual_rate: "0", term_months: "24" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /416\.67/    # monthly payment 10000/24
    assert_select "section#result table tbody tr", count: 24
  end

  # ── POST /calculators/loan — Turbo Stream 422 (invalid) ─────────────────

  test "missing required inputs render the error fragment with 422" do
    post "/calculators/loan",
      params: { inputs: { mode: "payment", loan_amount: "", annual_rate: "", term_months: "" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/loan",
      params: { inputs: { mode: "payment", loan_amount: "", annual_rate: "5", term_months: "60" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Loan amount can't be blank"
  end

  test "a term-mode payment too small to amortize surfaces as a validation error, not a 500" do
    # Spec edge case: payment ≤ loan_amount·r never repays the loan → validation error.
    post "/calculators/loan",
      params: { inputs: { mode: "term", loan_amount: "100000", monthly_payment: "400", annual_rate: "6" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /too small to ever repay/i
  end

  test "an unknown mode surfaces as a validation error, not a 500" do
    post "/calculators/loan",
      params: { inputs: { mode: "zzz", loan_amount: "25000", annual_rate: "5", term_months: "60" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
  end
end
