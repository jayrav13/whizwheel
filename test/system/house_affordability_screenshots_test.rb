require "application_system_test_case"

# Drives the real browser through the House Affordability page's key states and saves a
# full-page screenshot of each (issue #259) — a hero + stat-grid + housing-budget donut page,
# so the visual review matters here. Doubles as a Turbo/Stimulus regression check (the form
# posts over Turbo and the #result fragment updates in place; the house_affordability
# controller draws the donut and hides its no-JS fallback) and a visual artifact reviewed
# against docs/DESIGN.md (CI uploads the PNGs).
#
# CHART-PAINT GATE (frontend.md, DESIGN.md §4): the donut ships a pixel-level "did it actually
# paint" assertion — sample the canvas, require a minimum count of non-transparent pixels — so
# a blank canvas is a HARD CI FAILURE, not just a visual-gate catch (markup assertions can't
# see a blank canvas; iteration-0005 shipped a blank donut every markup assertion passed).
# assert_donut_drawn covers the Chart.js doughnut.
#
# WORST-CASE STAT GRID (frontend.md "test the worst case"): a high-income buyer pushes the max
# loan/price into seven figures, so the `--wide` grid is exercised with a large value and
# checked for mid-number wrap and clipping (assertions a markup test cannot make).
class HouseAffordabilityScreenshotsTest < ApplicationSystemTestCase
  test "empty result before any submission" do
    visit "/calculators/house_affordability"
    assert_selector "h1", text: "House Affordability Calculator"
    assert_field "Annual income"
    assert_field "Monthly debts"
    assert_field "Down payment"
    assert_field "Annual interest rate"
    assert_field "Loan term"
    assert_field "Front-end DTI"
    assert_field "Back-end DTI"
    assert_field "Monthly property tax"
    assert_field "Monthly home insurance"
    assert_field "Monthly HOA fee"
    assert_text "your answer appears here"
    screenshot_full_page("70-house-affordability-default")
  end

  test "computes the max home price and renders the hero, stat grid and budget donut" do
    visit "/calculators/house_affordability"
    fill_in "Annual income", with: "120000"
    fill_in "Monthly debts", with: "500"
    fill_in "Down payment", with: "60000"
    fill_in "Annual interest rate", with: "6"
    fill_in "Loan term", with: "30"
    fill_in "Front-end DTI", with: "28"
    fill_in "Back-end DTI", with: "36"
    fill_in "Monthly property tax", with: "250"
    fill_in "Monthly home insurance", with: "100"
    fill_in "Monthly HOA fee", with: "0"
    click_button "Calculate"
    # Turbo replaced #result in place — the hero price + budget figures appear without a reload.
    within "#result" do
      assert_text "468,639.46"  # max home price (hero)
      assert_text "408,639.46"  # max loan amount
      assert_text "10,000.00"   # gross monthly income
      assert_text "2,800.00"    # max monthly housing
      assert_text "2,450.00"    # principal & interest room
      # The donut eyebrow is uppercased by CSS, so the rendered text is upper-case.
      assert_text "MONTHLY HOUSING BUDGET"
      # The interactive Chart.js donut (DESIGN.md §4) draws on connect; the controller hides
      # the no-JS fallback only after the chart builds, leaving the live canvas present.
      assert_no_selector "[data-house-affordability-target=donutFallback]", visible: true
      assert_selector "[data-house-affordability-target=donutCanvas] canvas", visible: :all
    end
    # PIXEL-LEVEL proof the donut actually DREW (the visual gate caught a blank canvas that
    # every markup assertion passed through). A drawn doughnut has many non-transparent pixels;
    # a blank canvas has zero. This makes the "chart didn't render" defect a hard test failure.
    assert_donut_drawn
    screenshot_full_page("71-house-affordability-result")
  end

  test "a high income renders a 7-figure loan in the wide stat grid without wrapping or clipping" do
    visit "/calculators/house_affordability"
    fill_in "Annual income", with: "600000"
    fill_in "Monthly debts", with: "0"
    fill_in "Down payment", with: "0"
    fill_in "Annual interest rate", with: "5"
    fill_in "Loan term", with: "30"
    fill_in "Front-end DTI", with: "28"
    fill_in "Back-end DTI", with: "36"
    fill_in "Monthly property tax", with: "0"
    fill_in "Monthly home insurance", with: "0"
    fill_in "Monthly HOA fee", with: "0"
    click_button "Calculate"
    within "#result" do
      assert_selector "dl.stat-grid--wide"
      # The max loan amount clears $2M — a 7-figure value in the wide grid.
      assert_text(/\$2,\d{3},\d{3}\.\d{2}/)
    end
    # The `--wide` grid must hold the big figure on one line (no mid-number wrap) and never
    # clip it (DESIGN.md §4 "Stat grid" — single-line preferred, clipping never allowed).
    assert_no_mid_value_wrap("#result dl.stat-grid--wide dd")
    assert_no_value_clip("#result dl.stat-grid--wide dd")
    screenshot_full_page("72-house-affordability-large")
  end

  test "constraints that leave no affordability show the error fragment" do
    visit "/calculators/house_affordability"
    fill_in "Annual income", with: "30000"
    fill_in "Monthly debts", with: "2000"
    fill_in "Down payment", with: "0"
    fill_in "Annual interest rate", with: "6"
    fill_in "Loan term", with: "30"
    fill_in "Front-end DTI", with: "28"
    fill_in "Back-end DTI", with: "36"
    fill_in "Monthly property tax", with: "800"
    fill_in "Monthly home insurance", with: "200"
    fill_in "Monthly HOA fee", with: "0"
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: /No home is affordable/
    end
    screenshot_full_page("73-house-affordability-error")
  end

  private

  # Assert the Chart.js doughnut actually painted: read the canvas's pixel data and count
  # non-transparent pixels. A drawn doughnut covers a large fraction of its 112×112 box; a
  # blank canvas (the defect the visual gate caught) has zero. We require a generous floor so
  # the test proves "something substantial was drawn", not merely "a stray pixel exists".
  def assert_donut_drawn
    nonblank = page.evaluate_script(<<~JS)
      (() => {
        const c = document.querySelector('[data-house-affordability-target=donutCanvas] canvas');
        if (!c) return -1;
        const ctx = c.getContext('2d');
        const data = ctx.getImageData(0, 0, c.width, c.height).data;
        let n = 0;
        for (let i = 3; i < data.length; i += 4) { if (data[i] > 0) n++; }
        return n;
      })()
    JS
    assert_operator nonblank, :>, 500,
      "expected the Chart.js donut canvas to be painted (>500 non-transparent pixels), " \
      "got #{nonblank} — the doughnut did not render"
  end
end
