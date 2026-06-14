require "test_helper"

# Integration tests for the Tip calculator PAGE (issue #76, the frontend gate): the GET
# page renders its three inputs (no mode picker — single-mode calculator) and the POST
# Turbo Stream response renders the right result fragment for each state (the hero total +
# tip, the per-person split when people > 1, and 422 errors). These assert the markup the
# system test then verifies visually. Math correctness is the backend's gate (the envelope
# test); here we assert the page surfaces the envelope's four result keys.
class TipPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/tip ────────────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/tip"
    assert_response :success
    assert_select "h1", text: "Tip Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders all three inputs, each with a label" do
    get "/calculators/tip"
    assert_select "label[for=inputs_bill]", text: /Bill amount/
    assert_select "input#inputs_bill[name='inputs[bill]']"
    assert_select "label[for=inputs_tip_percent]", text: /Tip/
    assert_select "input#inputs_tip_percent[name='inputs[tip_percent]']"
    assert_select "label[for=inputs_people]", text: /People/
    assert_select "input#inputs_people[name='inputs[people]']"
  end

  test "people defaults to 1 in the form" do
    get "/calculators/tip"
    assert_select "input#inputs_people[value='1']"
  end

  test "page renders no mode picker — it is a single-mode calculator" do
    get "/calculators/tip"
    # No variant/mode selector applies (spec issue #76): no fieldset/legend picker, no
    # inputs[mode] field, none of the mode-picker component classes.
    assert_select "input[name='inputs[mode]']", count: 0
    assert_select "label.mode-option", count: 0
    assert_select "label.mode-pill", count: 0
  end

  test "page renders the tip-percentage quick-pick chips" do
    get "/calculators/tip"
    # Convenience chips for common rates — buttons (not radios), so they never post.
    assert_select "button.tip-preset[type=button]", count: 4
    assert_select "button.tip-preset[data-tip-value-param='20']", text: /20%/
  end

  test "page wires the Stimulus tip controller" do
    get "/calculators/tip"
    assert_select "form[data-controller=tip]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/tip"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/tip — Turbo Stream success ────────────────────────

  test "a split calculation renders the hero total and the per-person breakdown" do
    post "/calculators/tip",
      params: { inputs: { bill: "50.00", tip_percent: "15", people: "2" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # The grand total is the hero headline; the per-person split surfaces both figures.
    assert_select "section#result", text: /Total to pay/i
    assert_select "section#result", text: /\$57\.50/
    assert_select "section#result", text: /\$7\.50/
    assert_select "section#result", text: /Split 2 ways/i
    assert_select "section#result", text: /\$28\.75/
    assert_select "section#result", text: /\$3\.75/
  end

  test "a single-person calculation omits the per-person split block" do
    post "/calculators/tip",
      params: { inputs: { bill: "50.00", tip_percent: "15", people: "1" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /\$57\.50/
    # With one person the per-person figures equal the whole-party figures, so the split
    # block is suppressed (no "Split … ways" heading).
    assert_select "section#result", text: /Split/i, count: 0
  end

  test "money is rendered to a fixed two decimals" do
    post "/calculators/tip",
      params: { inputs: { bill: "100", tip_percent: "20", people: "1" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /\$120\.00/
    assert_select "section#result", text: /\$20\.00/
  end

  test "a 6+ digit per-person split figure renders in the responsive auto-fit grid without clipping" do
    # The worst case for the per-person stat grid (frontend agent: "test the worst case"):
    # a large bill split, so the per-person total carries 6+ digits + cents. The auto-fit
    # grid must surface the full figure (delimited, never truncated) — $2,000,000 @ 20% / 2
    # → total 2,400,000.00; per-person 1,200,000.00.
    post "/calculators/tip",
      params: { inputs: { bill: "2000000", tip_percent: "20", people: "2" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /\$2,400,000\.00/
    assert_select "section#result", text: /Split 2 ways/i
    # The full per-person figure is present (the shared stat grid's card shell + break-words
    # keep it whole) — not a clipped/rounded form.
    assert_select "section#result", text: /\$1,200,000\.00/
    # The split block is the shared responsive stat grid (DESIGN.md §4, issue #143): a
    # `.stat-grid` of two `.stat-card`s (each person pays / tip each).
    assert_select "section#result dl.stat-grid", count: 1
    assert_select "section#result dl.stat-grid .stat-card", count: 2
  end

  # ── POST /calculators/tip — Turbo Stream 422 (invalid) ──────────────────

  test "a missing bill renders the error fragment with 422" do
    post "/calculators/tip", params: { inputs: { bill: "", tip_percent: "15", people: "1" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/tip", params: { inputs: { bill: "", tip_percent: "", people: "1" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Bill amount can't be blank"
    assert_select "section#result [role=alert] li", text: "Tip can't be blank"
  end

  test "an invalid people count surfaces as a validation error, not a 500" do
    post "/calculators/tip", params: { inputs: { bill: "50", tip_percent: "15", people: "0" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result [role=alert] li", text: /People/
  end
end
