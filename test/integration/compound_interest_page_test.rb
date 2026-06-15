require "test_helper"

# Integration tests for the Compound Interest calculator page (issue #189) — a multi-mode
# (compounding-frequency picker) financial calculator with a growth-series chart. The GET
# page renders its three inputs + the compounding mode picker; the POST Turbo Stream
# response renders the right result fragment for each state (the hero future value, the
# totals stat grid, the donut + growth-curve charts, the year-by-year table, and 422
# errors). These assert the markup the system test then verifies visually; together they
# are the §11 frontend gate. Math correctness is the backend's gate; here we assert the
# page surfaces the envelope's result keys.
class CompoundInterestPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # Spec reference row used across the success assertions: 20000 @ 5% monthly 10y.
  REF = { principal: "20000", annual_rate: "5", years: "10", compounding: "monthly" }.freeze

  # ── GET /calculators/compound_interest ──────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/compound_interest"
    assert_response :success
    assert_select "h1", text: "Compound Interest Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders the three labeled inputs" do
    get "/calculators/compound_interest"
    assert_select "label[for=inputs_principal]", text: /Principal/
    assert_select "input#inputs_principal[name='inputs[principal]']"
    assert_select "label[for=inputs_annual_rate]", text: /Annual interest rate/
    assert_select "input#inputs_annual_rate[name='inputs[annual_rate]']"
    assert_select "label[for=inputs_years]", text: /Time/
    assert_select "input#inputs_years[name='inputs[years]']"
  end

  test "the years field accepts fractional terms" do
    # years is :decimal (2.5 years is valid), so the field steps by any, not whole years.
    get "/calculators/compound_interest"
    assert_select "input#inputs_years[step='any']"
  end

  # ── The compounding-frequency mode picker (DESIGN.md §4) ─────────────────

  test "the compounding picker is a native radio fieldset, not a select" do
    get "/calculators/compound_interest"
    # Five modes, several multi-word → the `.mode-option` selectable option list, posted as
    # a single-select native radio fieldset/legend (DESIGN.md §4). Never a raw <select>.
    assert_select "fieldset legend", text: /Compounding frequency/i
    assert_select "select[name='inputs[compounding]']", count: 0
  end

  test "the picker renders all five compounding modes as .mode-option rows" do
    get "/calculators/compound_interest"
    %w[annually semiannually quarterly monthly daily].each do |mode|
      assert_select "input[type=radio][name='inputs[compounding]'][value=#{mode}]"
    end
    # Each option is a styled .mode-option label paired to its visually-hidden peer radio.
    assert_select "label.mode-option", count: 5
    assert_select "input[name='inputs[compounding]'].peer.sr-only", count: 5
  end

  test "the picker defaults to Annually (the first option checked)" do
    get "/calculators/compound_interest"
    assert_select "input[type=radio][name='inputs[compounding]'][value=annually][checked=checked]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/compound_interest"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST — Turbo Stream success ──────────────────────────────────────────

  test "a calculation renders the hero future value and the detail sentence" do
    post "/calculators/compound_interest", params: { inputs: REF }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    assert_select "section#result", text: /Future value/i
    assert_select "section#result", text: /32,940\.19/ # future value (delimited)
    assert_select "section#result", text: /12,940\.19/ # total interest earned
    assert_select "section#result", text: /compounding monthly/i
  end

  test "the result renders the totals stat grid (shared component, --wide track)" do
    post "/calculators/compound_interest", params: { inputs: REF }, headers: TURBO
    assert_response :success
    # The shared responsive stat grid (DESIGN.md §4 "Stat grid", issue #143): a `.stat-grid`
    # of three `.stat-card`s. `--wide` because the future value is a high-magnitude money
    # figure that wraps mid-number at the default 9.5rem track in the narrow panel.
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card", count: 3
    assert_select "section#result dl.stat-grid dt", text: "Future value"
    assert_select "section#result dl.stat-grid dt", text: "Total interest"
    assert_select "section#result dl.stat-grid dt", text: "Principal"
  end

  test "the result renders the donut and growth-curve charts (with no-JS fallbacks)" do
    post "/calculators/compound_interest", params: { inputs: REF }, headers: TURBO
    assert_response :success
    # The no-JS fallbacks are always rendered server-side (DESIGN.md §4 / §6): a labelled
    # donut image with the principal-vs-interest breakdown + the SVG growth curve line.
    assert_select "section#result [role=img][aria-label*='Principal']"
    assert_select "section#result svg polyline" # the growth curve line
    assert_select "section#result", text: /Principal vs\. interest/i
    assert_select "section#result", text: /Growth over time/i
  end

  test "the result wires the interactive JS chart canvases and their data" do
    post "/calculators/compound_interest", params: { inputs: REF }, headers: TURBO
    assert_response :success
    # The hover-capable JS charts (DESIGN.md §4): a Chart.js donut canvas and a
    # lightweight-charts curve container, each hidden until the controller draws it, with
    # its fallback alongside. The controller reads the series from data-*-value attributes.
    assert_select "section#result [data-compound-interest-target=donutCanvas] canvas"
    assert_select "section#result [data-compound-interest-target=donutFallback]"
    assert_select "section#result [data-compound-interest-target=curveCanvas]"
    assert_select "section#result [data-compound-interest-target=curveFallback]"
    assert_select "section#result [data-compound-interest-donut-value]"
    assert_select "section#result [data-compound-interest-curve-value]"
    assert_select "section#result [data-controller=compound-interest]"
  end

  test "the result renders the year-by-year balance table with a hard final row" do
    post "/calculators/compound_interest", params: { inputs: REF }, headers: TURBO
    assert_response :success
    assert_select "section#result table thead th", text: "Year"
    assert_select "section#result table thead th", text: "Balance"
    # One row per whole year 0..10 → 11 rows for the 10-year term.
    assert_select "section#result table tbody tr", count: 11
    # The final (year 0) row shows the starting principal; the tfoot shows the future value.
    assert_select "section#result table tbody tr:first-child", text: /20,000\.00/ # year 0 balance
    assert_select "section#result table tfoot tr", text: /Final balance/
    assert_select "section#result table tfoot tr", text: /32,940\.19/
  end

  test "a different mode (annually) computes its own result" do
    post "/calculators/compound_interest",
      params: { inputs: { principal: "10000", annual_rate: "6", years: "5", compounding: "annually" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /13,382\.26/ # future value, annually
    assert_select "section#result", text: /compounding annually/i
  end

  test "the responsive stat grid renders large 7-digit money without clipping" do
    # Worst-case stat-grid test (frontend agent: "test the worst case"): a $1,000,000
    # principal at 0% (the no-growth edge) → future value exactly $1,000,000.00. The 7-digit
    # money figure must reach the card whole (the --wide track holds it on one line; the
    # never-clip net wraps rather than clips below that — DESIGN.md §4).
    post "/calculators/compound_interest",
      params: { inputs: { principal: "1000000", annual_rate: "0", years: "5", compounding: "monthly" } },
      headers: TURBO
    assert_response :success
    # The comma-grouped 7-digit whole part proves the big number reached the card intact.
    assert_select "section#result dl.stat-grid dd", text: /\A\$1,000,000\.00\z/
  end

  test "a fractional term is accepted and produces a result" do
    post "/calculators/compound_interest",
      params: { inputs: { principal: "5000", annual_rate: "8", years: "2.5", compounding: "quarterly" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /Future value/i
    # The growth series for a 2.5y term ends on the term endpoint, so the curve fallback +
    # table render without error.
    assert_select "section#result svg polyline"
    assert_select "section#result table tbody tr"
  end

  test "the zero-rate calculation earns no interest" do
    post "/calculators/compound_interest",
      params: { inputs: { principal: "1000", annual_rate: "0", years: "5", compounding: "monthly" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /1,000\.00/ # future value = principal
    assert_select "section#result", text: /Future value/i
  end

  # ── POST — Turbo Stream 422 (invalid) ────────────────────────────────────

  test "missing required inputs render the error fragment with 422" do
    post "/calculators/compound_interest",
      params: { inputs: { principal: "", annual_rate: "", years: "", compounding: "monthly" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/compound_interest",
      params: { inputs: { principal: "", annual_rate: "", years: "", compounding: "monthly" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Principal can't be blank"
    assert_select "section#result [role=alert] li", text: /Annual interest rate/
    assert_select "section#result [role=alert] li", text: /Time/
  end

  test "a non-positive principal surfaces as a validation error, not a 500" do
    post "/calculators/compound_interest",
      params: { inputs: { principal: "0", annual_rate: "5", years: "10", compounding: "monthly" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
  end

  test "an invalid compounding mode surfaces as a validation error" do
    post "/calculators/compound_interest",
      params: { inputs: { principal: "1000", annual_rate: "5", years: "10", compounding: "weekly" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
  end
end
