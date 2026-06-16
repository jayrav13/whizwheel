require "test_helper"

# Integration tests for the ROI (return on investment) calculator page (issue #258): the GET
# page renders its three inputs (the optional investment period unlocking the annualized
# figure), and the POST Turbo Stream response renders the right result fragment for each state
# — the ROI % hero (gain green / loss coral, paired with a Gain/Loss tag), the annualized
# figure ONLY when a period was supplied, the invested → gain → returned stat grid, and 422
# errors phrased against the visible label. These assert the markup the system test then
# verifies visually; together they are the §11 frontend gate. Math correctness is the backend's
# gate (the reference values from the spec); here we assert the page surfaces the envelope's
# result keys, formatted and tinted by sign.
class RoiPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/roi ────────────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/roi"
    assert_response :success
    assert_select "h1", text: "ROI Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders the three inputs, the period marked optional" do
    get "/calculators/roi"
    assert_select "input[name='inputs[amount_invested]']"
    assert_select "input[name='inputs[amount_returned]']"
    assert_select "input[name='inputs[investment_years]']"
    # The period is the optional input that unlocks the annualized figure.
    assert_select "label[for=inputs_investment_years]", text: /optional/i
  end

  test "the investment period is never auto-prefilled (blank stays blank)" do
    get "/calculators/roi"
    assert_select "input[name='inputs[investment_years]'][value]", count: 0
  end

  test "page has no mode picker (single-mode calculator)" do
    get "/calculators/roi"
    assert_select "input[type=radio][name='inputs[mode]']", count: 0
    assert_select "fieldset legend", count: 0
  end

  test "page wires the roi Stimulus controller for the live direction preview" do
    get "/calculators/roi"
    assert_select "form[data-controller='roi']"
    assert_select "[data-roi-target='preview']"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/roi"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST — Turbo Stream success (a gain, with a period) ──────────────────

  test "computes the ROI and annualized return for a gain over Turbo" do
    # The spec's sheep-farm anchor: invested 50000, returned 70000, 5 years.
    post "/calculators/roi",
      params: { inputs: { amount_invested: "50000", amount_returned: "70000", investment_years: "5" } },
      headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    within = "section#result"
    assert_select within, text: /40\.0000/   # ROI %
    assert_select within, text: /6\.9610/    # annualized ROI %
    assert_select within, text: /Return on investment/
    assert_select within, text: /Annualized ROI/
    # The stat grid figures (delimited, with cents).
    assert_select within, text: /50,000\.00/   # amount invested
    assert_select within, text: /20,000\.00/   # total gain
    assert_select within, text: /70,000\.00/   # amount returned
  end

  test "a gain tints the hero ROI figure accent green and tags it Gain" do
    post "/calculators/roi",
      params: { inputs: { amount_invested: "50000", amount_returned: "70000", investment_years: "5" } },
      headers: TURBO
    assert_response :success
    # The ROI hero value is lifted to accent green (the positive figure, DESIGN.md §1) and
    # paired with the word "Gain" (never colour alone, §6).
    assert_select "section#result p.text-accent", text: /40\.0000/
    assert_select "section#result", text: /Gain/
  end

  test "the stat grid uses the shared --wide component (high-magnitude money)" do
    post "/calculators/roi",
      params: { inputs: { amount_invested: "50000", amount_returned: "70000" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card", count: 3
  end

  test "the raw invested → returned figures are echoed in monospace code" do
    post "/calculators/roi",
      params: { inputs: { amount_invested: "50000", amount_returned: "70000" } },
      headers: TURBO
    assert_response :success
    # Raw echoed data → monospace <code> (DESIGN.md §2), never plain prose.
    assert_select "section#result code.font-mono", text: /50,000\.00/
    assert_select "section#result code.font-mono", text: /70,000\.00/
  end

  # ── POST — without a period (annualized omitted) ─────────────────────────

  test "omits the annualized figure when no period is supplied" do
    post "/calculators/roi",
      params: { inputs: { amount_invested: "50000", amount_returned: "70000" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /40\.0000/        # ROI still present
    assert_select "section#result", text: /Annualized ROI/, count: 0
  end

  # ── POST — a loss ────────────────────────────────────────────────────────

  test "a loss renders a signed negative ROI tinted coral and tagged Loss" do
    # The spec's loss anchor: invested 10000, returned 8000, no period.
    post "/calculators/roi",
      params: { inputs: { amount_invested: "10000", amount_returned: "8000" } },
      headers: TURBO
    assert_response :success
    within = "section#result"
    assert_select within, text: /-20\.0000/     # negative ROI %
    assert_select "#{within} p.text-primary", text: /-20\.0000/
    assert_select within, text: /Loss/
    # The total gain reads as a loss figure.
    assert_select within, text: /2,000\.00/
  end

  # ── POST — break-even ────────────────────────────────────────────────────

  test "a break-even result reads in neutral ink with a Break-even tag" do
    post "/calculators/roi",
      params: { inputs: { amount_invested: "1000", amount_returned: "1000" } },
      headers: TURBO
    assert_response :success
    within = "section#result"
    assert_select within, text: /0\.0000/
    assert_select within, text: /Break-even/
    # Neither accent nor coral on the hero figure — neutral ink.
    assert_select "#{within} p.text-ink", text: /0\.0000/
  end

  # ── POST — worst-case large money (stat grid never clips) ────────────────

  test "the stat grid renders a 7-figure money value in full without clipping" do
    # invested 1,000,000 → returned 1,500,000 = a 500,000.00 gain.
    post "/calculators/roi",
      params: { inputs: { amount_invested: "1000000", amount_returned: "1500000" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /1,000,000\.00/
    assert_select "section#result", text: /500,000\.00/
    assert_select "section#result", text: /1,500,000\.00/
  end

  # ── POST — Turbo Stream 422 (invalid) ────────────────────────────────────

  test "a zero amount invested renders the error fragment with 422" do
    post "/calculators/roi",
      params: { inputs: { amount_invested: "0", amount_returned: "100" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "the error is phrased against the visible label, not the raw key" do
    post "/calculators/roi",
      params: { inputs: { amount_invested: "0", amount_returned: "100" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Amount invested must be greater than 0/
  end

  test "a blank amount returned surfaces a label-based presence error" do
    post "/calculators/roi",
      params: { inputs: { amount_invested: "100", amount_returned: "" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Amount returned can't be blank/
  end

  test "a zero investment period surfaces a label-based error" do
    post "/calculators/roi",
      params: { inputs: { amount_invested: "100", amount_returned: "200", investment_years: "0" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Investment period must be greater than 0/
  end

  test "a non-numeric amount surfaces a label-based error, not a 500" do
    post "/calculators/roi",
      params: { inputs: { amount_invested: "x", amount_returned: "100" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Amount invested/
  end
end
