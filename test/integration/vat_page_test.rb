require "test_helper"

# Integration tests for the VAT calculator PAGE (issue #255, the frontend gate): the GET page
# renders its mode picker + inputs, and the POST Turbo Stream response renders the right result
# fragment for each state (the hero solved figure, the stat grid + breakdown, and 422 errors).
# These assert the markup the system test then verifies visually. Math correctness is the
# backend's gate (the envelope test); here we assert the page surfaces the envelope's result
# keys (mode / net_price / gross_price / rate / vat_amount).
#
# Deliberate structural twin of the Sales Tax page test (net/VAT/gross ↔ before/tax/after).
class VatPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/vat ────────────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/vat"
    assert_response :success
    assert_select "h1", text: "VAT Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders the three figure inputs, each with a label" do
    get "/calculators/vat"
    assert_select "label[for=inputs_net_price]", text: /Net price/
    assert_select "input#inputs_net_price[name='inputs[net_price]']"
    assert_select "label[for=inputs_gross_price]", text: /Gross price/
    assert_select "input#inputs_gross_price[name='inputs[gross_price]']"
    assert_select "label[for=inputs_rate]", text: /VAT rate/
    assert_select "input#inputs_rate[name='inputs[rate]']"
  end

  test "page renders the mode picker as a native radio segmented control posting inputs[mode]" do
    get "/calculators/vat"
    # DESIGN.md §4: THREE short labels → the segmented control (.direction-pill), a native radio
    # <fieldset>/<legend> single-select on inputs[mode] (no raw <select> as the picker).
    assert_select "fieldset legend", text: /Solve for/
    assert_select "label.direction-pill", count: 3
    assert_select "input[type=radio][name='inputs[mode]'][value=gross]"
    assert_select "input[type=radio][name='inputs[mode]'][value=net]"
    assert_select "input[type=radio][name='inputs[mode]'][value=rate]"
    assert_select "select[name='inputs[mode]']", count: 0
  end

  test "gross mode is selected by default" do
    get "/calculators/vat"
    assert_select "input[type=radio][name='inputs[mode]'][value=gross][checked]"
  end

  test "page wires the Stimulus vat controller and tags each field with the modes that give it" do
    get "/calculators/vat"
    assert_select "form[data-controller=vat]"
    # Net price is GIVEN by gross + rate modes; gross price by net + rate; rate by gross + net.
    assert_select "[data-vat-target=field][data-vat-modes='gross rate']"
    assert_select "[data-vat-target=field][data-vat-modes='net rate']"
    assert_select "[data-vat-target=field][data-vat-modes='gross net']"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/vat"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/vat — Turbo Stream success ────────────────────────

  test "gross mode renders the hero gross price, the VAT amount and the breakdown" do
    post "/calculators/vat",
      params: { inputs: { mode: "gross", net_price: "10.00", rate: "10" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # The solved figure (gross) is the hero headline; the figures surface in the stat grid.
    assert_select "section#result", text: /Gross price/i
    assert_select "section#result", text: /\$11\.00/   # gross (the hero)
    assert_select "section#result", text: /\$1\.00/    # vat amount
    assert_select "section#result", text: /\$10\.00/   # net price
    # The four figures use the shared wide stat grid (DESIGN.md §4, #143).
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card", count: 4
  end

  test "net mode solves the net price from the gross price and rate" do
    post "/calculators/vat",
      params: { inputs: { mode: "net", gross_price: "11.00", rate: "10" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /Net price/i
    assert_select "section#result", text: /\$10\.00/   # net (the hero)
    assert_select "section#result", text: /\$1\.00/    # vat amount
  end

  test "rate mode solves the VAT rate from the net and gross prices" do
    post "/calculators/vat",
      params: { inputs: { mode: "rate", net_price: "10.00", gross_price: "11.00" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /VAT rate/i
    # rate hero — the 4dp envelope rate ("10.0000") is trimmed to "10%" for display.
    assert_select "section#result", text: /10%/
    assert_select "section#result", text: /\$1\.00/    # vat amount
  end

  test "a fractional rate row renders to the cent (the Sales Tax twin anchor)" do
    post "/calculators/vat",
      params: { inputs: { mode: "gross", net_price: "49.99", rate: "7.25" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /\$53\.61/   # gross
    assert_select "section#result", text: /\$3\.62/    # vat amount (3.624… → 3.62)
  end

  test "a 7-digit money figure renders in the wide stat grid without clipping" do
    # The worst case for the VAT stat grid (frontend agent: "test the worst case"): a
    # high-magnitude net price, so the figures carry 7 digits + cents. The --wide grid must
    # surface the full delimited figure, never truncated — net $1,000,000 @ 10% → gross
    # $1,100,000.00, vat $100,000.00.
    post "/calculators/vat",
      params: { inputs: { mode: "gross", net_price: "1000000", rate: "10" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /\$1,000,000\.00/  # net price
    assert_select "section#result", text: /\$1,100,000\.00/  # gross price
    assert_select "section#result", text: /\$100,000\.00/    # vat amount
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
  end

  # ── POST /calculators/vat — Turbo Stream 422 (invalid) ──────────────────

  test "a missing net price renders the error fragment with 422" do
    post "/calculators/vat",
      params: { inputs: { mode: "gross", net_price: "", rate: "10" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/vat",
      params: { inputs: { mode: "gross", net_price: "", rate: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Net price/
    assert_select "section#result [role=alert] li", text: /VAT rate/
  end

  test "a non-positive net price surfaces as a validation error, not a 500" do
    post "/calculators/vat",
      params: { inputs: { mode: "gross", net_price: "0", rate: "10" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Net price/
  end

  test "a gross below the net in rate mode surfaces as a validation error" do
    post "/calculators/vat",
      params: { inputs: { mode: "rate", net_price: "10", gross_price: "9" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Gross price/
  end
end
