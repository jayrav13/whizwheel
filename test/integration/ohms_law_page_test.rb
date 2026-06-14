require "test_helper"

# Integration tests for the Ohm's Law calculator page (issue #55): the GET page
# renders its six input-pair modes and the four quantity fields, and the POST Turbo
# Stream response renders the right result fragment for each state (the solved V/I/R/P
# set + 422 errors). These assert the markup the system test then verifies visually;
# together they are the §11 frontend gate. (JSON-envelope behaviour lives in
# ohms_law_envelope_test.rb.)
class OhmsLawPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/ohms_law ───────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/ohms_law"
    assert_response :success
    assert_select "h1", text: "Ohm's Law Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders all six input-pair mode options" do
    get "/calculators/ohms_law"
    %w[vi vr vp ir ip rp].each do |mode|
      assert_select "input[type=radio][name='inputs[mode]'][value=?]", mode
    end
  end

  test "mode picker renders as one option list — a single bordered container of rows" do
    # DESIGN.md §4: six multi-word modes → the selectable option list — ONE bordered,
    # divided container, not N independent chips. Each row carries a .mode-option label.
    get "/calculators/ohms_law"
    assert_select "fieldset div.divide-y" do
      assert_select "label.mode-option", count: 6
    end
  end

  test "each mode row names the pair it solves on a helper line" do
    # The non-pill presentation adds a one-line helper naming the two solved quantities.
    get "/calculators/ohms_law"
    assert_select "label.mode-option", text: /Voltage & Current/, count: 1
    assert_select "label.mode-option", text: /Solve for resistance & power/
    assert_select "label.mode-option", text: /Solve for voltage & current/
  end

  test "page renders every quantity input with a labelled, unit-affixed field" do
    get "/calculators/ohms_law"
    assert_select "label[for=inputs_voltage]", text: /Voltage \(V\)/
    assert_select "label[for=inputs_current]", text: /Current \(I\)/
    assert_select "label[for=inputs_resistance]", text: /Resistance \(R\)/
    assert_select "label[for=inputs_power]", text: /Power \(P\)/
    assert_select "input[name='inputs[voltage]']"
    assert_select "input[name='inputs[current]']"
    assert_select "input[name='inputs[resistance]']"
    assert_select "input[name='inputs[power]']"
  end

  test "page wires the Stimulus ohms-law controller" do
    get "/calculators/ohms_law"
    assert_select "form[data-controller=ohms-law]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/ohms_law"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/ohms_law — Turbo Stream success ───────────────────

  test "vi mode solves resistance and power and renders all four quantities" do
    post "/calculators/ohms_law", params: { inputs: { mode: "vi", voltage: "12", current: "2" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # All four quantities render: V=12, I=2 (given) and R=6, P=24 (solved).
    assert_select "section#result", text: /\b12\b/
    assert_select "section#result", text: /\b6\b/
    assert_select "section#result", text: /\b24\b/
  end

  test "rp mode (the square-root branch) renders the solved voltage and current" do
    post "/calculators/ohms_law", params: { inputs: { mode: "rp", resistance: "4", power: "36" } }, headers: TURBO
    assert_response :success
    # I = √(36/4) = 3, V = 3 × 4 = 12.
    assert_select "section#result", text: /\b12\b/
    assert_select "section#result", text: /\b3\b/
  end

  test "result tags the two given quantities and the two solved ones" do
    post "/calculators/ohms_law", params: { inputs: { mode: "vi", voltage: "12", current: "2" } }, headers: TURBO
    assert_response :success
    # The render distinguishes given (echoed) from solved, not by colour alone:
    # each quantity carries a visible "Given" or "Solved" tag.
    assert_select "section#result", text: /Given/i
    assert_select "section#result", text: /Solved/i
  end

  test "solved-values grid is a responsive auto-fit grid, not a pinned column count" do
    # DESIGN.md §4 "Stat grid": size each card to a min width and let the grid flow,
    # rather than pin a fixed column count — so the grid uses the auto-fit minmax track.
    post "/calculators/ohms_law", params: { inputs: { mode: "vi", voltage: "12", current: "2" } }, headers: TURBO
    assert_response :success
    assert_select "section#result dl[class*='grid-cols-[repeat(auto-fit']"
  end

  test "large 6+ digit solved values render in full without truncation" do
    # Worst-case clip check (frontend agent: "test the worst case"): a high-power
    # circuit drives R and P into 6+ digit figures — they must render in full.
    # mode=vi, V=999000, I=999  → R = 1000, P = 998,001,000.
    post "/calculators/ohms_law",
      params: { inputs: { mode: "vi", voltage: "999000", current: "999" } }, headers: TURBO
    assert_response :success
    # Solved power = 998,001,000 (a 9-digit figure) renders delimited, never clipped.
    assert_select "section#result", text: /998,001,000/
    # Given voltage echoes back at full width too.
    assert_select "section#result", text: /999,000/
  end

  # ── POST /calculators/ohms_law — Turbo Stream 422 (invalid) ─────────────

  test "missing required input renders the error fragment with 422" do
    post "/calculators/ohms_law", params: { inputs: { mode: "vi", voltage: "", current: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/ohms_law", params: { inputs: { mode: "vi", voltage: "", current: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Voltage (V) can't be blank"
    assert_select "section#result [role=alert] li", text: "Current (I) can't be blank"
    assert_select "section#result [role=alert] li", text: /\AVoltage can't/, count: 0
  end

  test "division-by-zero input surfaces as a validation error, not a 500" do
    post "/calculators/ohms_law", params: { inputs: { mode: "vi", voltage: "12", current: "0" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
  end
end
