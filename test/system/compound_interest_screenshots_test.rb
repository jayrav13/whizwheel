require "application_system_test_case"

# Drives the real browser through the Compound Interest page's key states and saves a
# full-page screenshot of each (issue #189) — a multi-mode (compounding-frequency picker)
# financial calculator with a growth-series chart. Doubles as a Turbo/Stimulus regression
# check (the form posts over Turbo and the #result fragment updates in place; the
# compound_interest_controller draws the Chart.js donut + the lightweight-charts growth
# curve and hides the no-JS fallbacks once each paints) and a visual artifact reviewed
# against docs/DESIGN.md (CI uploads the PNGs).
class CompoundInterestScreenshotsTest < ApplicationSystemTestCase
  test "empty result before any submission" do
    visit "/calculators/compound_interest"
    assert_selector "h1", text: "Compound Interest Calculator"
    assert_field "Principal"
    assert_field "Annual interest rate"
    assert_field "Time"
    # The compounding mode picker is the .mode-option selectable option list (DESIGN.md §4).
    assert_selector "fieldset legend", text: "Compounding frequency"
    assert_selector "label.mode-option", count: 5
    assert_text "your answer appears here"
    screenshot_full_page("60-compound-interest-default")
  end

  test "computes a result and renders the hero, charts and year table" do
    visit "/calculators/compound_interest"
    fill_in "Principal", with: "20000"
    fill_in "Annual interest rate", with: "5"
    fill_in "Time", with: "10"
    # Select the Monthly compounding option (the .mode-option label is the visible control;
    # its visually-hidden peer radio carries the value).
    find("label.mode-option", text: "Monthly").click
    click_button "Calculate"

    # Turbo replaced #result in place — the hero future value + totals appear without a reload.
    within "#result" do
      assert_text "32,940.19" # future value
      assert_text "12,940.19" # total interest
      # The chart eyebrows are uppercased by CSS, so the rendered text is upper-case.
      assert_text "PRINCIPAL VS. INTEREST"
      assert_text "GROWTH OVER TIME"
      # The interactive JS charts (DESIGN.md §4) draw on connect: the Chart.js donut and the
      # lightweight-charts growth curve paint into their canvases, and the controller hides
      # the no-JS fallbacks only after each chart builds. Both libraries inject a <canvas>.
      assert_no_selector "[data-compound-interest-target=donutFallback]", visible: true
      assert_no_selector "[data-compound-interest-target=curveFallback]", visible: true
      assert_selector "[data-compound-interest-target=donutCanvas] canvas", visible: :all
      assert_selector "[data-compound-interest-target=curveCanvas] canvas", visible: :all
      # The year-by-year table: one row per whole year 0..10 (11 rows).
      assert_selector "tbody tr", count: 11
    end

    # PIXEL-LEVEL proof the donut actually DREW (a blank canvas passes every markup assertion
    # — the visual gate once caught Chart.js handed the wrapper div, not the <canvas>). Sample
    # the canvas: a drawn doughnut has many non-transparent pixels; a blank canvas has zero.
    # This makes "the chart didn't render" a HARD test failure, not a visual-review-only catch.
    assert_donut_drawn
    # PIXEL-LEVEL proof the growth curve actually DREW: lightweight-charts paints into a
    # <canvas> inside the curve container; sample it the same way. A blank curve canvas fails.
    assert_curve_drawn
    screenshot_full_page("61-compound-interest-result")
  end

  test "the wide stat grid holds a 7-digit money figure on one line without clipping" do
    # Worst-case (frontend agent: "test the worst case"): a $1,000,000 principal at 0% (the
    # no-growth edge) → future value exactly $1,000,000.00. The --wide track must hold the
    # 7-digit money figure on a single line and never clip it (DESIGN.md §4 "Stat grid").
    visit "/calculators/compound_interest"
    fill_in "Principal", with: "1000000"
    fill_in "Annual interest rate", with: "0"
    fill_in "Time", with: "5"
    find("label.mode-option", text: "Monthly").click
    click_button "Calculate"

    within "#result" do
      assert_text "1,000,000.00"
    end
    # The big figure stays on one line on the --wide track and is never truncated at the
    # card edge (single-line is preferred; the never-clip net is the floor below that).
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd")
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    screenshot_full_page("62-compound-interest-wide")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/compound_interest"
    # Submit with no numbers → server 422 → error fragment in #result. (Compounding has a
    # default checked option, so the only errors are the three blank numeric fields.)
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Principal can't be blank"
    end
    screenshot_full_page("63-compound-interest-error")
  end

  private

  # Assert the Chart.js doughnut actually painted: read the canvas's pixel data and count
  # non-transparent pixels. A drawn doughnut covers a large fraction of its 112×112 box; a
  # blank canvas (the defect the visual gate caught) has zero. We require a generous floor so
  # the test proves "something substantial was drawn", not merely "a stray pixel exists".
  def assert_donut_drawn
    nonblank = canvas_nonblank_pixels("[data-compound-interest-target=donutCanvas] canvas")
    assert_operator nonblank, :>, 500,
      "expected the Chart.js donut canvas to be painted (>500 non-transparent pixels), " \
      "got #{nonblank} — the doughnut did not render"
  end

  # Assert the lightweight-charts growth curve actually painted, the same way: sample the
  # canvas inside the curve container and require a floor of non-transparent pixels. A blank
  # curve canvas (a chart wired to the wrong element / fed no data) has near-zero and fails.
  def assert_curve_drawn
    nonblank = canvas_nonblank_pixels("[data-compound-interest-target=curveCanvas] canvas")
    assert_operator nonblank, :>, 500,
      "expected the lightweight-charts growth curve canvas to be painted (>500 " \
      "non-transparent pixels), got #{nonblank} — the curve did not render"
  end

  # Count non-transparent pixels (alpha > 0) in the first canvas matching `selector`. -1 if
  # the canvas is absent. lightweight-charts may render several stacked canvases inside the
  # container; we sample the largest-painted by scanning all and taking the max non-blank.
  def canvas_nonblank_pixels(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const canvases = document.querySelectorAll(#{selector.to_json});
        if (!canvases.length) return -1;
        let max = 0;
        canvases.forEach((c) => {
          if (!c.width || !c.height) return;
          const ctx = c.getContext('2d');
          if (!ctx) return;
          const data = ctx.getImageData(0, 0, c.width, c.height).data;
          let n = 0;
          for (let i = 3; i < data.length; i += 4) { if (data[i] > 0) n++; }
          if (n > max) max = n;
        });
        return max;
      })()
    JS
  end
end
