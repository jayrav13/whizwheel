require "application_system_test_case"

# Drives the real browser through the Mortgage page's key states and saves a full-page
# screenshot of each (issue #187) — a tabular-output + charts page (the payment-component
# donut + the balance-over-time curve + the P&I amortization schedule), so the visual review
# matters here. Doubles as a Turbo/Stimulus regression check (the form posts over Turbo and
# the #result fragment updates in place; the mortgage_controller paginates the long schedule
# and "Show all" reveals the rest) and a visual artifact reviewed against docs/DESIGN.md (CI
# uploads the PNGs).
#
# CHART-PAINT GATE (frontend.md, DESIGN.md §4): both charts ship a pixel-level "did it
# actually paint" assertion — sample the canvas, require a minimum count of non-transparent
# pixels — so a blank canvas is a HARD CI FAILURE, not just a visual-gate catch (markup
# assertions can't see a blank canvas; iteration-0005 shipped a blank donut every markup
# assertion passed). assert_donut_drawn covers the Chart.js donut; assert_curve_drawn covers
# the lightweight-charts balance curve.
class MortgageScreenshotsTest < ApplicationSystemTestCase
  test "empty result before any submission" do
    visit "/calculators/mortgage"
    assert_selector "h1", text: "Mortgage Calculator"
    assert_field "Home price"
    assert_field "Down payment"
    assert_field "Annual interest rate"
    assert_field "Loan term"
    assert_field "Annual property tax"
    assert_field "Annual home insurance"
    assert_field "Monthly HOA fee"
    assert_text "your answer appears here"
    screenshot_full_page("40-mortgage-default")
  end

  test "computes a 30-year mortgage and renders the hero, charts and paginated schedule" do
    visit "/calculators/mortgage"
    fill_in "Home price", with: "360000"
    fill_in "Down payment", with: "60000"
    fill_in "Annual interest rate", with: "7"
    fill_in "Loan term", with: "30"
    fill_in "Annual property tax", with: "3500"
    fill_in "Annual home insurance", with: "1200"
    fill_in "Monthly HOA fee", with: "50"
    click_button "Calculate"
    # Turbo replaced #result in place — the hero payment + totals appear without a reload.
    within "#result" do
      assert_text "2,437.58"    # total monthly payment (hero)
      assert_text "1,995.91"    # P&I portion
      assert_text "718,524.05"  # total of P&I
      assert_text "418,524.05"  # total interest
      # The chart eyebrows are uppercased by CSS, so the rendered text is upper-case.
      assert_text "MONTHLY PAYMENT BREAKDOWN"
      assert_text "BALANCE OVER TIME"
      # The interactive JS charts (DESIGN.md §4) draw on connect: the Chart.js donut and the
      # lightweight-charts curve paint into their canvases, and the controller hides the no-JS
      # fallbacks only after each chart builds. Both libraries inject a <canvas> we assert is
      # present. This exercises the chart-rendering path the headless integration test can't.
      assert_no_selector "[data-mortgage-target=donutFallback]", visible: true
      assert_no_selector "[data-mortgage-target=curveFallback]", visible: true
      assert_selector "[data-mortgage-target=donutCanvas] canvas", visible: :all
      assert_selector "[data-mortgage-target=curveCanvas] canvas", visible: :all
      # Stimulus paginates: the first page of rows shows; the rest are hidden until "Show all".
      assert_selector "tbody tr:not([hidden])", count: 12
      assert_text "Show all"
    end
    # PIXEL-LEVEL proof both charts actually DREW (the visual gate caught a blank canvas that
    # every markup assertion passed through). A drawn chart has many non-transparent pixels; a
    # blank canvas has zero. This makes the "chart didn't render" defect a hard test failure.
    assert_donut_drawn
    assert_curve_drawn
    screenshot_full_page("41-mortgage-result")
  end

  test "Show all reveals the full schedule" do
    visit "/calculators/mortgage"
    fill_in "Home price", with: "250000"
    fill_in "Down payment", with: "50000"
    fill_in "Annual interest rate", with: "6"
    fill_in "Loan term", with: "15"
    click_button "Calculate"
    within "#result" do
      assert_text "1,687.71" # P&I monthly payment (no recurring costs)
      click_button "Show all 180 months"
      # All 180 rows now visible; the final row reads "Paid off" (balance 0.00).
      assert_selector "tbody tr:not([hidden])", count: 180
      assert_text "Paid off"
    end
    screenshot_full_page("42-mortgage-full-schedule")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/mortgage"
    # Submit with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Home price can't be blank"
    end
    screenshot_full_page("43-mortgage-error")
  end

  private

  # Assert the Chart.js doughnut actually painted: read the canvas's pixel data and count
  # non-transparent pixels. A drawn doughnut covers a large fraction of its 112×112 box; a
  # blank canvas (the defect the visual gate caught) has zero. We require a generous floor so
  # the test proves "something substantial was drawn", not merely "a stray pixel exists".
  def assert_donut_drawn
    nonblank = page.evaluate_script(<<~JS)
      (() => {
        const c = document.querySelector('[data-mortgage-target=donutCanvas] canvas');
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

  # Assert the lightweight-charts balance curve actually painted. lightweight-charts renders
  # into one or more <canvas> elements inside its container; we sum non-transparent pixels
  # across them all (the series, axes and grid each draw real pixels) and require a floor, so
  # a blank curve (e.g. the container handed instead of an undrawn series) fails CI.
  def assert_curve_drawn
    nonblank = page.evaluate_script(<<~JS)
      (() => {
        const canvases = document.querySelectorAll('[data-mortgage-target=curveCanvas] canvas');
        if (!canvases.length) return -1;
        let n = 0;
        canvases.forEach((c) => {
          if (!c.width || !c.height) return;
          const ctx = c.getContext('2d');
          const data = ctx.getImageData(0, 0, c.width, c.height).data;
          for (let i = 3; i < data.length; i += 4) { if (data[i] > 0) n++; }
        });
        return n;
      })()
    JS
    assert_operator nonblank, :>, 500,
      "expected the lightweight-charts balance curve to be painted (>500 non-transparent " \
      "pixels), got #{nonblank} — the curve did not render"
  end
end
