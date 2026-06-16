require "test_helper"

# Integration tests for the Income Tax calculator page (issue #260): the GET page renders
# its mode picker + fields, and the POST Turbo Stream response renders the right result
# fragment for each state (the hero total tax + stat grid + per-bracket breakdown table, and
# the 422 error card). These assert the markup the system test then verifies visually;
# together they are the §11 frontend gate.
class IncomeTaxPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/income_tax ──────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/income_tax"
    assert_response :success
    assert_select "h1", text: "Income Tax Calculator"
    assert_select "input[type=submit][value='Calculate tax']"
  end

  test "page renders every income input with a label" do
    get "/calculators/income_tax"
    assert_select "label[for=inputs_taxable_income]", text: /Taxable income/
    assert_select "label[for=inputs_gross_income]", text: /Gross income/
    assert_select "label[for=inputs_deductions]", text: /Deductions/
    assert_select "input[name='inputs[taxable_income]']"
    assert_select "input[name='inputs[gross_income]']"
    assert_select "input[name='inputs[deductions]']"
  end

  # The income picker is the SELECTABLE OPTION LIST (.mode-option) — N=2 but both labels are
  # multi-word, so per DESIGN.md §4 it routes to the option list, not a segmented control. A
  # native radio <fieldset>/<legend> posts inputs[mode].
  test "income picker renders as a selectable option list" do
    get "/calculators/income_tax"
    assert_select "fieldset legend", text: "How do you want to enter income?"
    assert_select "input[type=radio][name='inputs[mode]'][value=taxable]"
    assert_select "input[type=radio][name='inputs[mode]'][value=gross]"
    assert_select "label.mode-option[data-mode=taxable]", text: /Taxable income/
    assert_select "label.mode-option[data-mode=gross]", text: /Gross income/
    # Not a segmented control / wrapping pill row.
    assert_select "label.direction-pill", count: 0
    assert_select "label.mode-pill", count: 0
  end

  test "taxable mode is the default checked option" do
    get "/calculators/income_tax"
    assert_select "input[type=radio][name='inputs[mode]'][value=taxable][checked=checked]"
  end

  test "page wires the Stimulus income-tax controller" do
    get "/calculators/income_tax"
    assert_select "form[data-controller=income-tax]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/income_tax"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/income_tax — Turbo Stream success ──────────────────

  test "a direct taxable income renders the hero total tax into the result" do
    post "/calculators/income_tax",
      params: { inputs: { taxable_income: "250000", mode: "taxable" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    within = "section#result"
    assert_select within, text: /Total federal income tax/i
    # total_tax 57,063.00 on 250,000 taxable.
    assert_select within, text: /57,063\.00/
    assert_select within, text: /250,000\.00/
  end

  test "the result renders the four-stat grid (taxable, after-tax, effective, marginal)" do
    post "/calculators/income_tax",
      params: { inputs: { taxable_income: "250000", mode: "taxable" } }, headers: TURBO
    assert_response :success
    within = "section#result"
    # The stat grid is the shared responsive grid (DESIGN.md §4), and money figures run high
    # (after-tax income, 7-figure incomes) so it takes the --wide track.
    assert_select "#{within} dl.stat-grid.stat-grid--wide", count: 1
    assert_select "#{within} dl.stat-grid .stat-card", count: 4
    assert_select "#{within} dl dt", text: "Taxable income"
    assert_select "#{within} dl dt", text: "After-tax income"
    assert_select "#{within} dl dt", text: "Effective rate"
    assert_select "#{within} dl dt", text: "Marginal rate"
    # after-tax 192,937.00; effective 22.8252%; marginal 32%.
    assert_select within, text: /192,937\.00/
    assert_select within, text: /22\.8252%/
    assert_select within, text: /32%/
  end

  test "the per-bracket breakdown renders as a data table with a hard total row" do
    post "/calculators/income_tax",
      params: { inputs: { taxable_income: "250000", mode: "taxable" } }, headers: TURBO
    assert_response :success
    within = "section#result"
    # One row per bracket reached (5 for 250,000) + the header row + the total row.
    assert_select "#{within} table tbody tr", count: 5
    # The bracket range is raw echoed data → monospace <code> (DESIGN.md §2).
    assert_select "#{within} table tbody tr td code.font-mono"
    # Worked anchor: the 22% bracket taxes 54,875.00 → 12,072.50.
    assert_select within, text: /12,072\.50/
    assert_select within, text: /54,875\.00/
    # The hard total row carries total_tax.
    assert_select "#{within} table tfoot tr td", text: /57,063\.00/
  end

  test "gross income and deductions derive the taxable income" do
    post "/calculators/income_tax",
      params: { inputs: { gross_income: "60000", deductions: "14600", mode: "gross" } }, headers: TURBO
    assert_response :success
    within = "section#result"
    # taxable_income = 60000 − 14600 = 45400 → total_tax 5,209.50.
    assert_select within, text: /45,400\.00/
    assert_select within, text: /5,209\.50/
  end

  # Zero taxable income reaches no bracket — the brackets array is empty, so the table shows a
  # quiet "no tax" note rather than an empty table.
  test "zero taxable income shows the no-tax breakdown note" do
    post "/calculators/income_tax",
      params: { inputs: { taxable_income: "0", mode: "taxable" } }, headers: TURBO
    assert_response :success
    within = "section#result"
    assert_select within, text: /no federal income tax is owed/i
    assert_select "#{within} table", count: 0
  end

  # Worst-case render (frontend agent rule): a 6+ digit money figure must lay out in the
  # --wide stat grid without clipping. A 1,000,000 taxable income → 327,020.25 tax and a
  # 672,979.75 after-tax income — every figure carries thousands delimiters and cents and must
  # appear in full.
  test "a seven-figure income renders every figure in full without clipping" do
    post "/calculators/income_tax",
      params: { inputs: { taxable_income: "1000000", mode: "taxable" } }, headers: TURBO
    assert_response :success
    within = "section#result"
    assert_select within, text: /1,000,000\.00/  # taxable income
    assert_select within, text: /327,020\.25/    # total tax (hero)
    assert_select within, text: /672,979\.75/    # after-tax income
  end

  # ── POST /calculators/income_tax — Turbo Stream 422 (invalid) ────────────

  test "missing both income inputs renders the error fragment with 422" do
    post "/calculators/income_tax",
      params: { inputs: { mode: "taxable" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/income_tax",
      params: { inputs: { mode: "taxable" } }, headers: TURBO
    assert_response :unprocessable_entity
    # The :blank validation lands on taxable_income → "Taxable income can't be blank".
    assert_select "section#result [role=alert] li", text: "Taxable income can't be blank"
  end

  test "a negative taxable income surfaces as a validation error, not a 500" do
    post "/calculators/income_tax",
      params: { inputs: { taxable_income: "-100", mode: "taxable" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
  end
end
