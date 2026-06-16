require "test_helper"

# Integration tests for the Sales Tax calculator PAGE (issue #252, the frontend gate): the GET
# page renders its segmented mode picker + the three solve-for inputs, and the POST Turbo Stream
# response renders the right result fragment for each state (the solved-for hero, the stat grid +
# breakdown, and 422 errors). These assert the markup the system test then verifies visually.
# Math correctness is the backend's gate (the envelope test, #242); here we assert the page
# surfaces the envelope's result keys (mode / before_tax_price / after_tax_price / rate /
# tax_amount). Structural twin of VAT (#255) — keep the page tests parallel.
class SalesTaxPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/sales_tax ──────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/sales_tax"
    assert_response :success
    assert_select "h1", text: "Sales Tax Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders all three figure inputs, each with a label" do
    get "/calculators/sales_tax"
    assert_select "label[for=inputs_before_tax_price]", text: /Before-tax price/
    assert_select "input#inputs_before_tax_price[name='inputs[before_tax_price]']"
    assert_select "label[for=inputs_after_tax_price]", text: /After-tax price/
    assert_select "input#inputs_after_tax_price[name='inputs[after_tax_price]']"
    assert_select "label[for=inputs_rate]", text: /Tax rate/
    assert_select "input#inputs_rate[name='inputs[rate]']"
  end

  test "page renders the mode picker as a native radio segmented control posting inputs[mode]" do
    get "/calculators/sales_tax"
    # DESIGN.md §4: three short labels → the segmented control (.direction-pill), a native radio
    # <fieldset>/<legend> single-select on inputs[mode] (never a raw <select> as the picker).
    assert_select "fieldset legend", text: /Solve for/
    assert_select "label.direction-pill", count: 3
    assert_select "input[type=radio][name='inputs[mode]'][value=after]"
    assert_select "input[type=radio][name='inputs[mode]'][value=before]"
    assert_select "input[type=radio][name='inputs[mode]'][value=rate]"
    assert_select "select[name='inputs[mode]']", count: 0
  end

  test "after mode is selected by default" do
    get "/calculators/sales_tax"
    assert_select "input[type=radio][name='inputs[mode]'][value=after][checked]"
  end

  test "page wires the Stimulus sales-tax controller and tags each field with its modes" do
    get "/calculators/sales_tax"
    assert_select "form[data-controller=sales-tax]"
    assert_select "[data-sales-tax-target=field][data-sales-tax-modes='after rate']"
    assert_select "[data-sales-tax-target=field][data-sales-tax-modes='before rate']"
    assert_select "[data-sales-tax-target=field][data-sales-tax-modes='after before']"
  end

  test "page renders a helper line per mode" do
    get "/calculators/sales_tax"
    assert_select "[data-sales-tax-target=modeHelper][data-mode=after]"
    assert_select "[data-sales-tax-target=modeHelper][data-mode=before]"
    assert_select "[data-sales-tax-target=modeHelper][data-mode=rate]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/sales_tax"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/sales_tax — Turbo Stream success ──────────────────

  test "after mode renders the after-tax-price hero, the figures and the breakdown" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "after", before_tax_price: "100", rate: "6" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # After-tax price is the hero (the solved figure); before/tax/rate surface in the stat grid.
    assert_select "section#result", text: /After-tax price/i
    assert_select "section#result", text: /\$106\.00/   # after-tax price (hero)
    assert_select "section#result", text: /\$100\.00/   # before-tax price
    assert_select "section#result", text: /\$6\.00/     # tax amount
    assert_select "section#result", text: /6\.0000%/    # rate to 4 dp
    # The four figures use the shared wide stat grid (DESIGN.md §4, #143).
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card", count: 4
  end

  test "before mode solves the before-tax price from the after-tax price and rate" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "before", after_tax_price: "106", rate: "6" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /Before-tax price/i
    assert_select "section#result", text: /\$100\.00/   # before-tax price (hero/solved)
    assert_select "section#result", text: /\$6\.00/     # tax amount
  end

  test "rate mode solves the tax rate from the before- and after-tax prices" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "rate", before_tax_price: "100", after_tax_price: "106" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /Tax rate/i
    assert_select "section#result", text: /6\.0000%/    # rate (hero/solved), 4 dp
    assert_select "section#result", text: /\$6\.00/     # tax amount
  end

  test "money is rendered to a fixed two decimals" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "after", before_tax_price: "49.99", rate: "7.25" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /\$53\.61/    # after-tax price
    assert_select "section#result", text: /\$3\.62/     # tax amount (3.624… → 3.62)
  end

  test "a 7-digit money figure renders in the wide stat grid without clipping" do
    # The worst case for the sales-tax stat grid (frontend agent: "test the worst case"): a
    # high-magnitude price, so the figures carry 7 digits + cents. The --wide grid must surface
    # the full delimited figure, never truncated — $1,000,000 @ 0% tax → after $1,000,000.00.
    post "/calculators/sales_tax",
      params: { inputs: { mode: "after", before_tax_price: "1000000", rate: "0" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /\$1,000,000\.00/
    assert_select "section#result", text: /\$0\.00/    # no tax at 0%
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
  end

  # ── POST /calculators/sales_tax — Turbo Stream 422 (invalid) ────────────

  test "a missing required field renders the error fragment with 422" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "after", before_tax_price: "100", rate: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "after", before_tax_price: "", rate: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Before-tax price/
    assert_select "section#result [role=alert] li", text: /Tax rate/
  end

  test "a non-positive price surfaces as a validation error, not a 500" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "after", before_tax_price: "0", rate: "6" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Before-tax price/
  end

  test "in rate mode an after price below the before price surfaces as a validation error" do
    post "/calculators/sales_tax",
      params: { inputs: { mode: "rate", before_tax_price: "100", after_tax_price: "90" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /After-tax price/
  end
end
