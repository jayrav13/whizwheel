require "test_helper"

# Integration tests for the Right Triangle calculator page (issue #193): the GET page
# renders its two solve-from modes and the three side fields, and the POST Turbo Stream
# response renders the right result fragment for each state (the solved sides/angles/area/
# perimeter/altitude + the SVG figure, or the 422 error card). These assert the markup the
# system test then verifies visually; together they are the §11 frontend gate. (JSON-envelope
# behaviour lives with the backend.)
class RightTrianglePageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/right_triangle ─────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/right_triangle"
    assert_response :success
    assert_select "h1", text: "Right Triangle Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders both solve-from mode options" do
    get "/calculators/right_triangle"
    %w[legs leg_hyp].each do |mode|
      assert_select "input[type=radio][name='inputs[mode]'][value=?]", mode
    end
  end

  test "mode picker renders as one option list — a single bordered container of rows" do
    # DESIGN.md §4: two MULTI-WORD modes → the selectable option list, ONE bordered,
    # divided container, not N independent chips. Each row carries a .mode-option label.
    get "/calculators/right_triangle"
    assert_select "fieldset div.divide-y" do
      assert_select "label.mode-option", count: 2
    end
  end

  test "each mode row names what it solves on a helper line" do
    get "/calculators/right_triangle"
    assert_select "label.mode-option", text: /Two legs \(a, b\)/, count: 1
    assert_select "label.mode-option", text: /Solve for the hypotenuse c/
    assert_select "label.mode-option", text: /Leg & hypotenuse \(a, c\)/, count: 1
    assert_select "label.mode-option", text: /Solve for the other leg b/
  end

  test "page renders the three side inputs, each labelled" do
    get "/calculators/right_triangle"
    assert_select "label[for=inputs_a]", text: /Leg a/
    assert_select "label[for=inputs_b]", text: /Leg b/
    assert_select "label[for=inputs_c]", text: /Hypotenuse \(c\)/
    assert_select "input[name='inputs[a]']"
    assert_select "input[name='inputs[b]']"
    assert_select "input[name='inputs[c]']"
  end

  test "page wires the Stimulus right-triangle controller" do
    get "/calculators/right_triangle"
    assert_select "form[data-controller=right-triangle]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/right_triangle"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/right_triangle — Turbo Stream success ──────────────

  test "legs mode solves the hypotenuse and renders every figure" do
    post "/calculators/right_triangle",
      params: { inputs: { mode: "legs", a: "3", b: "4" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # 3-4-5 triangle: c=5, area=6, perimeter=12, altitude=2.4, α=36.869898°, β=53.130102°.
    within = "section#result"
    assert_select within, text: /\b5\b/        # solved hypotenuse
    assert_select within, text: /36\.869898/    # alpha
    assert_select within, text: /53\.130102/    # beta
    assert_select within, text: /2\.4/          # altitude
    assert_select within, text: /\b12\b/        # perimeter
  end

  test "leg_hyp mode solves the other leg" do
    post "/calculators/right_triangle",
      params: { inputs: { mode: "leg_hyp", a: "6", c: "10" } }, headers: TURBO
    assert_response :success
    # 6-8-10 triangle: b=8, area=24, altitude=4.8.
    assert_select "section#result", text: /\b8\b/   # solved leg b
    assert_select "section#result", text: /\b24\b/  # area
    assert_select "section#result", text: /4\.8/    # altitude
  end

  test "result draws the labelled SVG triangle figure" do
    # The visualisation (DESIGN.md §4, extended to a static diagram): a role=img SVG with a
    # polygon body, a right-angle marker, and the labelled sides — it accompanies the grid,
    # never replacing it.
    post "/calculators/right_triangle",
      params: { inputs: { mode: "legs", a: "3", b: "4" } }, headers: TURBO
    assert_response :success
    assert_select "section#result figure svg[role=img]", count: 1
    assert_select "section#result figure svg polygon", count: 1
    # The figure labels the three sides (symbol = value) and the two acute angles.
    assert_select "section#result figure svg text", text: /a = 3/
    assert_select "section#result figure svg text", text: /c = 5/
    assert_select "section#result figure svg text", text: /α/
    assert_select "section#result figure svg text", text: /β/
  end

  test "result figures use the shared responsive stat grid (the no-JS data fallback)" do
    # DESIGN.md §4 "Stat grid" (issue #143): the shared `.stat-grid` / `.stat-card`
    # component, NOT a pinned column count. The `--wide` track holds the long worst-case
    # figures — the two angles display to six decimals ("53.130102°") and large legs drive
    # the sides/area/perimeter high — single-line rather than wrapping mid-number. Eight figures.
    post "/calculators/right_triangle",
      params: { inputs: { mode: "legs", a: "3", b: "4" } }, headers: TURBO
    assert_response :success
    assert_select "section#result dl.stat-grid", count: 1
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card", count: 8
  end

  test "large 6+ digit side values render in full without truncation" do
    # Worst-case clip check (frontend agent: "test the worst case"): big legs drive the
    # hypotenuse, area and perimeter into large figures — they must render in full, delimited.
    post "/calculators/right_triangle",
      params: { inputs: { mode: "legs", a: "300000", b: "400000" } }, headers: TURBO
    assert_response :success
    # c = 500,000; perimeter = 1,200,000; area = 60,000,000,000 — all delimited, never clipped.
    assert_select "section#result", text: /500,000/
    assert_select "section#result", text: /1,200,000/
  end

  # ── POST /calculators/right_triangle — Turbo Stream 422 (invalid) ────────

  test "missing required side renders the error fragment with 422" do
    post "/calculators/right_triangle",
      params: { inputs: { mode: "legs", a: "", b: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/right_triangle",
      params: { inputs: { mode: "legs", a: "", b: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Leg a can't be blank"
    assert_select "section#result [role=alert] li", text: "Leg b can't be blank"
  end

  test "hypotenuse-not-greater-than-leg surfaces as a labelled validation error" do
    post "/calculators/right_triangle",
      params: { inputs: { mode: "leg_hyp", a: "8", c: "6" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result [role=alert] li", text: /Hypotenuse \(c\)/
  end
end
