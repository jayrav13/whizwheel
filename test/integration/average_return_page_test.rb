require "test_helper"

# Integration tests for the Average Return calculator page (issue #257): the GET page renders
# its dynamic variable-length list input (the starter `inputs[returns][]` rows + the clone
# template), and the POST Turbo Stream response renders the right result fragment for each
# state — the two averages (geometric + arithmetic) in the shared stat grid, the raw echoed
# returns in `<code>`, and 422 errors phrased against the visible label. These assert the
# markup the system test then verifies visually; together they are the §11 frontend gate.
# Math correctness is the backend's gate (the 4dp reference values from the spec); here we
# assert the page surfaces the envelope's three result keys, formatted to fixed 4dp.
class AverageReturnPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/average_return ─────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/average_return"
    assert_response :success
    assert_select "h1", text: "Average Return Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders the dynamic list as multiple inputs[returns][] fields" do
    get "/calculators/average_return"
    # The starter rows each post the array key (no index) — the variable-length list.
    assert_select "input[name='inputs[returns][]']", minimum: 2
    # The list region is the Stimulus controller's target, with a clone template.
    assert_select "form[data-controller='return-list']"
    assert_select "[data-return-list-target='list']"
    assert_select "template[data-return-list-target='template'] input[name='inputs[returns][]']"
  end

  test "page renders the Add-return and Remove affordances and a live count chip" do
    get "/calculators/average_return"
    assert_select "button[data-action='return-list#add']", text: /Add return/
    assert_select "button[data-action='return-list#remove']"
    assert_select "[data-return-list-target='count']", text: /period/
  end

  test "the list group carries an accessible label and hint" do
    get "/calculators/average_return"
    assert_select "#returns_label", text: /Period returns/
    assert_select "[role=group][aria-labelledby=returns_label][aria-describedby=returns_hint]"
  end

  test "page has no mode picker (single-mode calculator)" do
    get "/calculators/average_return"
    assert_select "input[type=radio][name='inputs[mode]']", count: 0
    assert_select "fieldset legend", count: 0
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/average_return"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST — Turbo Stream success ─────────────────────────────────────────

  test "computes both averages and renders them over Turbo" do
    # The spec's worked anchor: [10, 20, −5, 15] → arithmetic 10.0000, geometric 9.5844.
    post "/calculators/average_return",
      params: { inputs: { returns: %w[10 20 -5 15] } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    within = "section#result"
    assert_select within, text: /9\.5844/    # geometric
    assert_select within, text: /10\.0000/   # arithmetic
    assert_select within, text: /Geometric average/
    assert_select within, text: /Arithmetic average/
    # Both averages render in the shared stat grid (DESIGN.md §4) — default track (small %).
    assert_select "#{within} dl.stat-grid", count: 1
    assert_select "#{within} dl.stat-grid:not(.stat-grid--wide)", count: 1
    assert_select "#{within} dl.stat-grid .stat-card", count: 2
  end

  test "the geometric average is the emphasised accent figure" do
    post "/calculators/average_return",
      params: { inputs: { returns: %w[10 20 -5 15] } }, headers: TURBO
    assert_response :success
    # The geometric card's value <dd> is lifted to accent green (the true figure, DESIGN.md §1).
    assert_select "section#result .stat-card dd.text-accent", text: /9\.5844/
  end

  test "echoes the period count and the raw returns list in a monospace code block" do
    post "/calculators/average_return",
      params: { inputs: { returns: %w[10 20 -5 15] } }, headers: TURBO
    assert_response :success
    within = "section#result"
    assert_select within, text: /Averaged over/
    assert_select within, text: /periods/
    # Raw echoed data → monospace <code> (DESIGN.md §2), never plain prose.
    assert_select "#{within} code.font-mono", text: /\[10, 20, -5, 15\]/
  end

  test "drops blank entries before computing (the variable-length list contract)" do
    # Trailing blank rows (from extra Add taps the user didn't fill) are dropped: the
    # effective list is [5, 5, 5, 5] → both averages 5.0000.
    post "/calculators/average_return",
      params: { inputs: { returns: [ "5", "5", "", "5", "5", "  " ] } }, headers: TURBO
    assert_response :success
    within = "section#result"
    assert_select within, text: /5\.0000/
    assert_select within, text: /Averaged over/
    assert_select within, text: /4 periods/
  end

  test "a single period renders both averages equal" do
    post "/calculators/average_return",
      params: { inputs: { returns: [ "10" ] } }, headers: TURBO
    assert_response :success
    within = "section#result"
    assert_select within, text: /10\.0000/
    assert_select within, text: /1 period/
  end

  test "a total-loss −100 period renders a signed −100.0000 geometric average" do
    post "/calculators/average_return",
      params: { inputs: { returns: [ "-100" ] } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /-100\.0000/
  end

  test "a net-loss arithmetic-zero case renders the negative geometric average" do
    # [10, −10] → arithmetic 0.0000, geometric −0.5013 (the spec's sign-preservation case).
    post "/calculators/average_return",
      params: { inputs: { returns: %w[10 -10] } }, headers: TURBO
    assert_response :success
    within = "section#result"
    assert_select within, text: /0\.0000/     # arithmetic
    assert_select within, text: /-0\.5013/    # geometric, signed
  end

  # The stat grid must hold a large multi-digit average without clipping (the worst case the
  # frontend agent is required to exercise). A list of extreme gains drives a large arithmetic
  # average; we assert it renders complete (delimited, fixed 4dp) in the result.
  test "the stat grid renders a large 6+ digit average in full without clipping" do
    # arithmetic = (2,000,000 + 2,000,000) / 2 = 2,000,000.0000.
    post "/calculators/average_return",
      params: { inputs: { returns: %w[2000000 2000000] } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /2,000,000\.0000/
  end

  # ── POST — Turbo Stream 422 (invalid) ───────────────────────────────────

  test "a blank list renders the error fragment with 422" do
    post "/calculators/average_return",
      params: { inputs: { returns: [ "" ] } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "the blank-list error is phrased against the Returns label, not the raw key" do
    post "/calculators/average_return",
      params: { inputs: { returns: [ "" ] } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Returns can't be blank"
  end

  test "a return below −100% surfaces a label-based validation error" do
    post "/calculators/average_return",
      params: { inputs: { returns: [ "-150" ] } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Returns each return must be at least −100%/
  end

  test "a non-numeric entry surfaces a label-based validation error, not a 500" do
    post "/calculators/average_return",
      params: { inputs: { returns: [ "10", "x", "20" ] } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Returns must be a list of numbers/
  end

  # After a 422 the form re-renders the SUBMITTED returns so the user keeps what they typed —
  # the error response carries the calculator back through the page (via create.turbo_stream).
  # The invalid −150 list re-renders that value in a row rather than resetting to blank.
  test "an invalid submission re-renders the submitted values, not blank rows" do
    post "/calculators/average_return",
      params: { inputs: { returns: %w[10 -150] } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
  end
end
