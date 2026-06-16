require "test_helper"

# Integration tests for the Discount calculator PAGE (issue #254, the frontend gate): the GET
# page renders its mode picker + inputs, and the POST Turbo Stream response renders the right
# result fragment for each state (the hero final price, the stat grid + breakdown, and 422
# errors). These assert the markup the system test then verifies visually. Math correctness is
# the backend's gate (the envelope test); here we assert the page surfaces the envelope's result
# keys (mode / original_price / final_price / amount_saved).
class DiscountPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/discount ───────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/discount"
    assert_response :success
    assert_select "h1", text: "Discount Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders the original price and both discount inputs, each with a label" do
    get "/calculators/discount"
    assert_select "label[for=inputs_original_price]", text: /Original price/
    assert_select "input#inputs_original_price[name='inputs[original_price]']"
    assert_select "label[for=inputs_percent_off]", text: /Percent off/
    assert_select "input#inputs_percent_off[name='inputs[percent_off]']"
    assert_select "label[for=inputs_amount_off]", text: /Amount off/
    assert_select "input#inputs_amount_off[name='inputs[amount_off]']"
  end

  test "page renders the mode picker as a native radio option list posting inputs[mode]" do
    get "/calculators/discount"
    # DESIGN.md §4: two multi-word modes → the selectable option list (.mode-option), a native
    # radio <fieldset>/<legend> single-select on inputs[mode] (no raw <select> as the picker).
    assert_select "fieldset legend", text: /Discount type/
    assert_select "label.mode-option", count: 2
    assert_select "input[type=radio][name='inputs[mode]'][value=percent]"
    assert_select "input[type=radio][name='inputs[mode]'][value=fixed]"
    assert_select "select[name='inputs[mode]']", count: 0
  end

  test "percent mode is selected by default" do
    get "/calculators/discount"
    assert_select "input[type=radio][name='inputs[mode]'][value=percent][checked]"
  end

  test "page wires the Stimulus discount controller and tags each discount field with its mode" do
    get "/calculators/discount"
    assert_select "form[data-controller=discount]"
    assert_select "[data-discount-target=field][data-discount-mode=percent]"
    assert_select "[data-discount-target=field][data-discount-mode=fixed]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/discount"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/discount — Turbo Stream success ───────────────────

  test "a percent-off discount renders the hero final price, the saved amount and the breakdown" do
    post "/calculators/discount",
      params: { inputs: { mode: "percent", original_price: "45.00", percent_off: "10" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # Final price is the hero headline; amount saved + original surface in the stat grid/breakdown.
    assert_select "section#result", text: /Final price/i
    assert_select "section#result", text: /\$40\.50/   # final price
    assert_select "section#result", text: /\$4\.50/    # amount saved
    assert_select "section#result", text: /\$45\.00/   # original price
    # The three figures use the shared wide stat grid (DESIGN.md §4, #143).
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card", count: 3
  end

  test "a fixed-amount discount renders the final price and saved amount" do
    post "/calculators/discount",
      params: { inputs: { mode: "fixed", original_price: "80.00", amount_off: "15.00" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /\$65\.00/   # final price
    assert_select "section#result", text: /\$15\.00/   # amount saved
  end

  test "money is rendered to a fixed two decimals" do
    post "/calculators/discount",
      params: { inputs: { mode: "percent", original_price: "199.99", percent_off: "25" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /\$149\.99/  # final price
    assert_select "section#result", text: /\$50\.00/   # amount saved (49.9975 → 50.00)
  end

  test "a 7-digit money figure renders in the wide stat grid without clipping" do
    # The worst case for the discount stat grid (frontend agent: "test the worst case"): a
    # high-magnitude price, so the figures carry 7 digits + cents. The --wide grid must surface
    # the full delimited figure, never truncated — $1,000,000 @ 0% off → final $1,000,000.00.
    post "/calculators/discount",
      params: { inputs: { mode: "percent", original_price: "1000000", percent_off: "0" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /\$1,000,000\.00/
    assert_select "section#result", text: /\$0\.00/ # nothing saved at 0%
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
  end

  # ── POST /calculators/discount — Turbo Stream 422 (invalid) ─────────────

  test "a missing original price renders the error fragment with 422" do
    post "/calculators/discount",
      params: { inputs: { mode: "percent", original_price: "", percent_off: "10" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/discount",
      params: { inputs: { mode: "percent", original_price: "", percent_off: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Original price/
    assert_select "section#result [role=alert] li", text: /Percent off/
  end

  test "a percent over 100 surfaces as a validation error, not a 500" do
    post "/calculators/discount",
      params: { inputs: { mode: "percent", original_price: "50", percent_off: "120" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Percent off/
  end

  test "a fixed amount exceeding the original price surfaces as a validation error" do
    post "/calculators/discount",
      params: { inputs: { mode: "fixed", original_price: "80", amount_off: "100" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Amount off/
  end
end
