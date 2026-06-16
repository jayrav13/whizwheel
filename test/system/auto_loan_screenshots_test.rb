require "application_system_test_case"

# Drives the real browser through the Auto Loan page's key states and saves a full-page
# screenshot of each (issue #251) — an amortized auto loan with the auto-specific amount-
# financed roll-up (trade-in, down payment, sales tax, fees) plus the donut + balance-curve
# charts and a paginated schedule. Doubles as a Turbo/Stimulus regression check (the form
# posts over Turbo and the #result fragment updates in place; the auto_loan_controller draws
# the hover-capable charts and paginates the long schedule, "Show all" revealing the rest)
# and a visual artifact reviewed against docs/DESIGN.md (CI uploads the PNGs).
class AutoLoanScreenshotsTest < ApplicationSystemTestCase
  test "empty result before any submission" do
    visit "/calculators/auto_loan"
    assert_selector "h1", text: "Auto Loan Calculator"
    assert_field "Vehicle price"
    assert_field "Loan term"
    assert_field "Annual interest rate"
    assert_field "Down payment"
    assert_field "Trade-in value"
    assert_field "Sales tax"
    assert_text "your answer appears here"
    screenshot_full_page("86-auto-loan-default")
  end

  test "computes an auto loan and renders the hero, breakdown, charts and paginated schedule" do
    visit "/calculators/auto_loan"
    fill_in "Vehicle price", with: "30000"
    fill_in "Loan term", with: "60"
    fill_in "Annual interest rate", with: "5"
    fill_in "Down payment", with: "4000"
    fill_in "Trade-in value", with: "6000"
    fill_in "Sales tax", with: "7"
    fill_in "Title, registration & other fees", with: "800"
    click_button "Calculate"
    # Turbo replaced #result in place — the hero payment + figures appear without a reload.
    within "#result" do
      assert_text "424.23"      # monthly payment
      assert_text "22,480.00"   # amount financed
      assert_text "1,680.00"    # computed sales tax (breakdown row)
      assert_text "25,453.48"   # total of payments
      assert_text "2,973.48"    # total interest
      # The chart eyebrows are uppercased by CSS, so the rendered text is upper-case.
      assert_text "WHERE YOUR MONEY GOES"
      assert_text "BALANCE OVER TIME"
      # The interactive JS charts (DESIGN.md §4) draw on connect: the Chart.js donut and the
      # lightweight-charts curve libraries paint into their canvases, and the controller hides
      # the no-JS fallbacks only after each chart builds. This exercises the chart-rendering
      # path the headless integration test can't (it asserts markup; only the browser runs the
      # chart libraries).
      assert_no_selector "[data-auto-loan-target=donutFallback]", visible: true
      assert_no_selector "[data-auto-loan-target=curveFallback]", visible: true
      assert_selector "[data-auto-loan-target=donutCanvas] canvas", visible: :all
      assert_selector "[data-auto-loan-target=curveCanvas] canvas", visible: :all
      # Stimulus paginates: the first page of rows shows; the rest are hidden until "Show all".
      assert_selector "tbody tr:not([hidden])", count: 12
      assert_text "Show all"
    end
    # PIXEL-LEVEL proof the donut actually DREW (the visual gate once caught a blank canvas
    # that every markup assertion passed through — Chart.js was handed the wrapper div, not
    # the <canvas>, and silently rendered nothing). Sample the canvas: a drawn doughnut has
    # many non-transparent pixels; a blank canvas has zero. This makes the "chart didn't
    # render" defect a hard test failure, not a visual-review-only catch.
    assert_donut_drawn
    screenshot_full_page("87-auto-loan-result")
  end

  test "Show all reveals the full schedule" do
    visit "/calculators/auto_loan"
    fill_in "Vehicle price", with: "20000"
    fill_in "Loan term", with: "36"
    fill_in "Annual interest rate", with: "0"
    fill_in "Down payment", with: "2000"
    click_button "Calculate"
    within "#result" do
      assert_text "500.00" # monthly payment 18000/36
      click_button "Show all 36 months"
      # All 36 rows now visible; the final row reads "Paid off" (balance 0.00).
      assert_selector "tbody tr:not([hidden])", count: 36
      assert_text "Paid off"
    end
    screenshot_full_page("88-auto-loan-full-schedule")
  end

  test "a large auto loan keeps its 6-digit totals on one line and unclipped" do
    # Worst-case stat-grid layout (frontend agent: "test the worst case", DESIGN.md §4): a
    # luxury vehicle financed long pushes amount financed + total of payments to 6 digits.
    # The `--wide` track must keep them on a single line (no mid-number wrap) and the
    # never-clip net must keep them fully visible (no truncation at the card edge) — geometry
    # assertions a markup/text test can't make.
    visit "/calculators/auto_loan"
    fill_in "Vehicle price", with: "150000"
    fill_in "Loan term", with: "84"
    fill_in "Annual interest rate", with: "9"
    fill_in "Sales tax", with: "8"
    fill_in "Title, registration & other fees", with: "2000"
    click_button "Calculate"
    within "#result" do
      assert_selector "dl.stat-grid.stat-grid--wide"
    end
    # No mid-number wrap and no clip on any stat-grid value (the wide track + never-clip net).
    assert_no_mid_value_wrap("#result dl.stat-grid dd")
    assert_no_value_clip("#result dl.stat-grid dd")
    screenshot_full_page("89-auto-loan-large")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/auto_loan"
    # Submit with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Vehicle price can't be blank"
    end
    screenshot_full_page("90-auto-loan-error")
  end

  private

  # Assert the Chart.js doughnut actually painted: read the canvas's pixel data and count
  # non-transparent pixels. A drawn doughnut covers a large fraction of its 112×112 box; a
  # blank canvas (the defect the visual gate caught) has zero. We require a generous floor so
  # the test proves "something substantial was drawn", not merely "a stray pixel exists".
  def assert_donut_drawn
    nonblank = page.evaluate_script(<<~JS)
      (() => {
        const c = document.querySelector('[data-auto-loan-target=donutCanvas] canvas');
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
