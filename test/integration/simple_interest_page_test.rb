require "test_helper"

# Integration tests for the Simple Interest calculator page (issue #78): the GET page
# renders its fields + the Years|Months segmented control, and the POST Turbo Stream
# response renders the right result fragment for each state (the hero answer + breakdown,
# and the 422 error card). These assert the markup the system test then verifies visually;
# together they are the §11 frontend gate.
class SimpleInterestPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/simple_interest ────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/simple_interest"
    assert_response :success
    assert_select "h1", text: "Simple Interest Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders every input with a label" do
    get "/calculators/simple_interest"
    assert_select "label[for=inputs_principal]", text: /Principal/
    assert_select "label[for=inputs_rate]", text: /Annual rate/
    assert_select "label[for=inputs_time]", text: /Time/
    assert_select "input[name='inputs[principal]']"
    assert_select "input[name='inputs[rate]']"
    assert_select "input[name='inputs[time]']"
  end

  # The unit picker is a SEGMENTED CONTROL (N=2 short labels Years|Months), per the
  # picker rule — a native radio <fieldset> with the two halves as .direction-pill, not
  # a wrapping pill row or the .mode-option list.
  test "unit picker renders as a two-option segmented control" do
    get "/calculators/simple_interest"
    assert_select "fieldset legend", text: "Time unit"
    assert_select "input[type=radio][name='inputs[unit]'][value=years]"
    assert_select "input[type=radio][name='inputs[unit]'][value=months]"
    # The segmented-control halves are .direction-pill (not .mode-option / .mode-pill).
    assert_select "label.direction-pill[data-unit=years]", text: "Years"
    assert_select "label.direction-pill[data-unit=months]", text: "Months"
    assert_select "label.mode-option", count: 0
    assert_select "label.mode-pill", count: 0
  end

  test "years is the default checked unit" do
    get "/calculators/simple_interest"
    assert_select "input[type=radio][name='inputs[unit]'][value=years][checked=checked]"
  end

  test "page wires the Stimulus simple-interest controller" do
    get "/calculators/simple_interest"
    assert_select "form[data-controller=simple-interest]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/simple_interest"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/simple_interest — Turbo Stream success ─────────────

  test "a years calculation renders the hero total and the interest into the result" do
    post "/calculators/simple_interest",
      params: { inputs: { principal: "1000", rate: "5", time: "3", unit: "years" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # Ending balance 1,150.00; interest accrued 150.00 — both money-formatted to cents.
    assert_select "section#result", text: /1,150\.00/
    assert_select "section#result", text: /150\.00/
    assert_select "section#result", text: /Ending balance/i
  end

  test "a months calculation converts to years before computing" do
    post "/calculators/simple_interest",
      params: { inputs: { principal: "2000", rate: "6", time: "18", unit: "months" } }, headers: TURBO
    assert_response :success
    # 2000 @ 6% for 18 months → 1.5 years → 180.00 interest, 2,180.00 total.
    assert_select "section#result", text: /2,180\.00/
    assert_select "section#result", text: /180\.00/
    assert_select "section#result", text: /months/
  end

  test "the result renders the principal + interest = total breakdown as a stat grid" do
    post "/calculators/simple_interest",
      params: { inputs: { principal: "5000", rate: "3.5", time: "2", unit: "years" } }, headers: TURBO
    assert_response :success
    within = "section#result"
    # The breakdown is the shared responsive stat grid (DESIGN.md §4 "Stat grid", issue
    # #143): a `.stat-grid` of three `.stat-card`s, sized to the canonical min width and
    # left to flow.
    assert_select "#{within} dl.stat-grid", count: 1
    assert_select "#{within} dl.stat-grid .stat-card", count: 3
    assert_select "#{within} dl dt", text: "Principal"
    assert_select "#{within} dl dt", text: "Interest"
    assert_select "#{within} dl dt", text: "Total"
    assert_select within, text: /5,000\.00/  # principal
    assert_select within, text: /350\.00/    # interest
    assert_select within, text: /5,350\.00/  # total
  end

  # Worst-case render (frontend agent rule): a 6+ digit money figure must lay out in the
  # auto-fit stat grid without clipping. A 1,000,000 principal over 10 years at 8% ⇒
  # 800,000.00 interest and a 1,800,000.00 ending balance — every figure carries thousands
  # delimiters and cents and must appear in full.
  test "a six-plus-digit result renders in full without clipping" do
    post "/calculators/simple_interest",
      params: { inputs: { principal: "1000000", rate: "8", time: "10", unit: "years" } }, headers: TURBO
    assert_response :success
    within = "section#result"
    assert_select within, text: /1,000,000\.00/  # principal
    assert_select within, text: /800,000\.00/    # interest
    assert_select within, text: /1,800,000\.00/  # total (also the hero ending balance)
  end

  # ── POST /calculators/simple_interest — Turbo Stream 422 (invalid) ──────

  test "missing required input renders the error fragment with 422" do
    post "/calculators/simple_interest",
      params: { inputs: { principal: "", rate: "", time: "", unit: "years" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/simple_interest",
      params: { inputs: { principal: "", rate: "", time: "", unit: "years" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Principal can't be blank"
    assert_select "section#result [role=alert] li", text: "Annual rate can't be blank"
    assert_select "section#result [role=alert] li", text: "Time can't be blank"
  end

  test "a negative principal surfaces as a validation error, not a 500" do
    post "/calculators/simple_interest",
      params: { inputs: { principal: "-1", rate: "5", time: "3", unit: "years" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
  end
end
