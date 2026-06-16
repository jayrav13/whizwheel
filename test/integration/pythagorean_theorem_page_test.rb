require "test_helper"

# Integration tests for the Pythagorean Theorem calculator page (spec issue #253): the GET
# page renders its two solve-for modes and the three side fields, and the POST Turbo Stream
# response renders the right result fragment for each state (the solved side + the labeled
# SVG figure + the three-side stat grid, or the 422 error card). These assert the markup the
# system test then verifies visually; together they are the §11 frontend gate. (JSON-envelope
# behaviour lives with the backend.)
class PythagoreanTheoremPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/pythagorean_theorem ────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/pythagorean_theorem"
    assert_response :success
    assert_select "h1", text: "Pythagorean Theorem Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders both solve-for mode options" do
    get "/calculators/pythagorean_theorem"
    %w[hypotenuse leg].each do |mode|
      assert_select "input[type=radio][name='inputs[mode]'][value=?]", mode
    end
  end

  test "mode picker renders as one option list — a single bordered container of rows" do
    # DESIGN.md §4: two MULTI-WORD modes → the selectable option list, ONE bordered,
    # divided container, not N independent chips. Each row carries a .mode-option label.
    get "/calculators/pythagorean_theorem"
    assert_select "fieldset div.divide-y" do
      assert_select "label.mode-option", count: 2
    end
  end

  test "each mode row names what it solves on a helper line" do
    get "/calculators/pythagorean_theorem"
    assert_select "label.mode-option", text: /Solve the hypotenuse/, count: 1
    assert_select "label.mode-option", text: /Given the two legs a and b/
    assert_select "label.mode-option", text: /Solve a leg/, count: 1
    assert_select "label.mode-option", text: /Given leg a and hypotenuse c/
  end

  test "page renders the three side inputs, each labelled" do
    get "/calculators/pythagorean_theorem"
    assert_select "label[for=inputs_a]", text: /Leg a/
    assert_select "label[for=inputs_b]", text: /Leg b/
    assert_select "label[for=inputs_c]", text: /Hypotenuse \(c\)/
    assert_select "input[name='inputs[a]']"
    assert_select "input[name='inputs[b]']"
    assert_select "input[name='inputs[c]']"
  end

  test "page wires the Stimulus pythagorean-theorem controller" do
    get "/calculators/pythagorean_theorem"
    assert_select "form[data-controller=pythagorean-theorem]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/pythagorean_theorem"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/pythagorean_theorem — Turbo Stream success ─────────

  test "hypotenuse mode solves c and renders the figure and grid" do
    post "/calculators/pythagorean_theorem",
      params: { inputs: { mode: "hypotenuse", a: "3", b: "4" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # 3-4-5 triangle: c = 5.
    within = "section#result"
    assert_select within, text: /Solved hypotenuse c/i
    assert_select within, text: /\b5\b/        # solved hypotenuse
    # Three-side stat grid, the solved side tagged "Solved".
    assert_select "section#result dl.stat-grid .stat-card", count: 3
    assert_select "section#result", text: /Solved/
    assert_select "section#result", text: /Given/
  end

  test "hypotenuse mode renders an irrational result to six decimals" do
    post "/calculators/pythagorean_theorem",
      params: { inputs: { mode: "hypotenuse", a: "1", b: "1" } }, headers: TURBO
    assert_response :success
    # c = √2 = 1.414214 (6 dp, half-up) — the full six-decimal figure renders.
    assert_select "section#result", text: /1\.414214/
  end

  test "leg mode solves the other leg b" do
    post "/calculators/pythagorean_theorem",
      params: { inputs: { mode: "leg", a: "5", c: "13" } }, headers: TURBO
    assert_response :success
    # 5-12-13 triangle: b = 12.
    assert_select "section#result", text: /Solved leg b/i
    assert_select "section#result", text: /\b12\b/
  end

  test "result draws the labelled SVG triangle figure" do
    # The visualisation (DESIGN.md §4, extended to a static diagram, and the spec explicitly
    # permits inline SVG here): a role=img SVG with a polygon body, a right-angle marker, and
    # the labelled sides — it accompanies the grid, never replacing it.
    post "/calculators/pythagorean_theorem",
      params: { inputs: { mode: "hypotenuse", a: "3", b: "4" } }, headers: TURBO
    assert_response :success
    assert_select "section#result figure svg[role=img]", count: 1
    assert_select "section#result figure svg polygon", count: 1
    # The figure labels the three sides (symbol = value).
    assert_select "section#result figure svg text", text: /a = 3/
    assert_select "section#result figure svg text", text: /b = 4/
    assert_select "section#result figure svg text", text: /c = 5/
  end

  test "result echoes the substituted equation in a monospace code element" do
    # DESIGN.md §2: raw echoed quantitative data quoted back → a real <code> font-mono.
    post "/calculators/pythagorean_theorem",
      params: { inputs: { mode: "hypotenuse", a: "3", b: "4" } }, headers: TURBO
    assert_response :success
    assert_select "section#result code.font-mono", text: /c = √\(a² \+ b²\)/
  end

  test "result figures use the shared responsive stat grid (the no-JS data fallback)" do
    # DESIGN.md §4 "Stat grid" (issue #143): the shared `.stat-grid` / `.stat-card`
    # component, NOT a pinned column count. The `--wide` track holds the long worst-case
    # figures (large legs drive a delimited high-magnitude hypotenuse). Three figures.
    post "/calculators/pythagorean_theorem",
      params: { inputs: { mode: "hypotenuse", a: "3", b: "4" } }, headers: TURBO
    assert_response :success
    assert_select "section#result dl.stat-grid", count: 1
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card", count: 3
  end

  test "large 6+ digit side values render in full without truncation" do
    # Worst-case clip check (frontend agent: "test the worst case"): big legs drive the
    # hypotenuse into a large figure — it must render in full, delimited.
    post "/calculators/pythagorean_theorem",
      params: { inputs: { mode: "hypotenuse", a: "300000", b: "400000" } }, headers: TURBO
    assert_response :success
    # c = 500,000 — delimited, never clipped.
    assert_select "section#result", text: /500,000/
  end

  # ── POST /calculators/pythagorean_theorem — Turbo Stream 422 (invalid) ───

  test "missing required side renders the error fragment with 422" do
    post "/calculators/pythagorean_theorem",
      params: { inputs: { mode: "hypotenuse", a: "", b: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/pythagorean_theorem",
      params: { inputs: { mode: "hypotenuse", a: "", b: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Leg a can't be blank"
    assert_select "section#result [role=alert] li", text: "Leg b can't be blank"
  end

  test "hypotenuse-not-greater-than-leg surfaces as a labelled validation error" do
    post "/calculators/pythagorean_theorem",
      params: { inputs: { mode: "leg", a: "8", c: "6" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result [role=alert] li", text: /Hypotenuse \(c\)/
  end
end
