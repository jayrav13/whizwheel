require "application_system_test_case"

# Drives the real browser through the Personal Loan page's key states and saves a full-page
# screenshot of each (issue #256) — the single-mode loan-core skin of the loan cluster, with
# the monthly-payment hero, the loan figures + totals stat grid, a principal-vs-interest donut
# + a balance-over-time curve, and the full repayment schedule. Doubles as a Turbo/Stimulus
# regression check (the form posts over Turbo and the #result fragment updates in place; the
# personal_loan_controller draws the charts and paginates the long schedule) and a visual
# artifact reviewed against docs/DESIGN.md (CI uploads the PNGs).
class PersonalLoanScreenshotsTest < ApplicationSystemTestCase
  test "empty result before any submission" do
    visit "/calculators/personal_loan"
    assert_selector "h1", text: "Personal Loan Calculator"
    assert_field "Loan amount"
    assert_field "Annual interest rate"
    assert_field "Loan term"
    assert_text "your answer appears here"
    screenshot_full_page("80-personal-loan-default")
  end

  test "computes a personal loan and renders the hero, charts and paginated schedule" do
    visit "/calculators/personal_loan"
    fill_in "Loan amount", with: "15000"
    fill_in "Annual interest rate", with: "7"
    fill_in "Loan term", with: "36"
    click_button "Calculate"
    # Turbo replaced #result in place — the hero payment + totals appear without a reload.
    within "#result" do
      assert_text "463.16"      # monthly payment (the hero)
      assert_text "16,673.61"   # total of payments
      assert_text "1,673.61"    # total interest
      # The chart eyebrows are uppercased by CSS, so the rendered text is upper-case.
      assert_text "WHERE YOUR MONEY GOES"
      assert_text "BALANCE OVER TIME"
      # The interactive JS charts (DESIGN.md §4) draw on connect: the Chart.js donut and the
      # lightweight-charts curve libraries paint into their canvases, and the controller hides
      # the no-JS fallbacks only after each chart builds. This exercises the chart-rendering
      # path the headless integration test can't (it asserts markup; only the browser runs the
      # chart libraries).
      assert_no_selector "[data-personal-loan-target=donutFallback]", visible: true
      assert_no_selector "[data-personal-loan-target=curveFallback]", visible: true
      assert_selector "[data-personal-loan-target=donutCanvas] canvas", visible: :all
      assert_selector "[data-personal-loan-target=curveCanvas] canvas", visible: :all
      # Stimulus paginates: the first page of rows shows; the rest are hidden until "Show all".
      assert_selector "tbody tr:not([hidden])", count: 12
      assert_text "Show all"
    end
    # WORST-CASE stat-grid geometry (frontend agent: "test the worst case"). The `--wide` grid
    # carries high-magnitude money; assert no value wraps mid-number and none clips.
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd")
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    # PIXEL-LEVEL proof the donut actually DREW (a blank canvas passes every markup assertion —
    # the visual gate once caught a donut handed the wrapper div, not the <canvas>, which
    # rendered nothing). Sample the canvas: a drawn doughnut has many non-transparent pixels.
    assert_donut_drawn
    screenshot_full_page("81-personal-loan-result")
  end

  test "Show all reveals the full schedule" do
    # 24 months (> the 12-row first page) so Stimulus paginates and the "Show all" button shows.
    visit "/calculators/personal_loan"
    fill_in "Loan amount", with: "10000"
    fill_in "Annual interest rate", with: "0"
    fill_in "Loan term", with: "24"
    click_button "Calculate"
    within "#result" do
      assert_text "416.67" # monthly payment 10000/24
      # Paginated: only the first page shows until "Show all".
      assert_selector "tbody tr:not([hidden])", count: 12
      click_button "Show all 24 months"
      # All 24 rows now visible; the final row reads "Paid off" (balance 0.00).
      assert_selector "tbody tr:not([hidden])", count: 24
      assert_text "Paid off"
    end
    screenshot_full_page("82-personal-loan-full-schedule")
  end

  test "a large loan's wide stat grid renders high-magnitude totals on one line" do
    # A large, long-term personal loan's total of payments is 7-figure ($1,721,651.90) — the
    # exact case the --wide track exists for. Prove the worst-case figures hold on one line and
    # never clip in the narrow result panel.
    visit "/calculators/personal_loan"
    fill_in "Loan amount", with: "1000000"
    fill_in "Annual interest rate", with: "12"
    fill_in "Loan term", with: "120"
    click_button "Calculate"
    within "#result" do
      assert_text "1,721,651.90"
    end
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd")
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    screenshot_full_page("83-personal-loan-large-result")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/personal_loan"
    # Submit with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Loan amount can't be blank"
    end
    screenshot_full_page("84-personal-loan-error")
  end

  private

  # Assert the Chart.js doughnut actually painted: read the canvas's pixel data and count
  # non-transparent pixels. A drawn doughnut covers a large fraction of its 112×112 box; a blank
  # canvas (the defect the visual gate caught) has zero. A generous floor proves "something
  # substantial was drawn", not merely "a stray pixel exists".
  def assert_donut_drawn
    nonblank = page.evaluate_script(<<~JS)
      (() => {
        const c = document.querySelector('[data-personal-loan-target=donutCanvas] canvas');
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
