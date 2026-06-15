require "application_system_test_case"

# Drives the real browser through the admin stats dashboard (#221) and saves a full-page
# screenshot for the visual gate (CI uploads the PNG, reviewed against docs/DESIGN.md).
# Doubles as the Stimulus chart test: it asserts the TradingView lightweight-charts Histogram
# trend chart (volume_trend_chart_controller, DESIGN.md §4 — every chart, dashboard charts
# included, uses the house JS library) actually PAINTS — the mandatory pixel-level "did it
# paint" check (sample the <canvas>, count non-transparent pixels, require a minimum), so a
# blank canvas is a HARD CI failure, not just a visual-gate catch. (The library renders to a
# <canvas>, so the prior SVG <rect>-count assertion is replaced with the canvas pixel sample,
# matching test/system/amortization_screenshots_test.rb's assert_donut_drawn.) Signs in as
# alice (the admin from the roles fixture).
class AdminStatsScreenshotsTest < ApplicationSystemTestCase
  test "the admin dashboard renders the stats, the painted trend chart, and the discarded badge" do
    sign_in_as("alice", "password")
    # Wait for the post-login redirect to land (the session cookie is set) before
    # navigating — visiting too early races the in-flight login POST and 404s the
    # admin gate. The Admin nav link only renders for a signed-in admin.
    assert_link "Admin"
    visit "/admin/stats"

    assert_selector "h1", text: "Calculation statistics"

    # Volume stat cards (the section heading is CSS-uppercased to "VOLUME").
    assert_text "Today"
    assert_text "All time"

    # The trend chart: volume_trend_chart_controller draws a lightweight-charts Histogram into
    # the chart target's <canvas> and retires the no-JS table fallback once it paints. The
    # canvas being present + the fallback hidden is the markup evidence; the pixel sample below
    # is the load-bearing "did it actually paint" proof (a markup assertion can't see a blank
    # canvas — the lesson behind this whole convention, DESIGN.md §4).
    assert_selector "[data-volume-trend-chart-target=chart] canvas", visible: :all
    assert_no_selector "[data-volume-trend-chart-target=fallback]", visible: true
    assert_trend_chart_drawn

    # Breakdown tables (the h2 headings are CSS-uppercased, so the visible text is caps).
    assert_text "TOP CALCULATORS"
    assert_text "TOP USERS"
    assert_text "ANONYMOUS VS. ATTRIBUTED"

    # The recent feed flags the soft-deleted fixture row with the discarded badge.
    assert_text "RECENT ACTIVITY"
    # The badge label is CSS-uppercased; the rendered text is "DISCARDED".
    assert_selector "span", text: "DISCARDED"
    # An anonymous row reads "anonymous", not a blank/username.
    assert_text "anonymous"
    # The recent-feed input → result summaries are raw echoed data rendered in a monospace
    # <code> (DESIGN.md §2), each carrying the "→" arrow joiner.
    assert_selector "td code.font-mono", text: /→/

    screenshot_full_page("70-admin-stats")
  end

  test "the volume stat grid renders large counts without clipping" do
    sign_in_as("alice", "password")
    # Wait for the post-login redirect to land (the session cookie is set) before
    # navigating — visiting too early races the in-flight login POST and 404s the
    # admin gate. The Admin nav link only renders for a signed-in admin.
    assert_link "Admin"
    visit "/admin/stats"
    # The volume grid uses the shared wide stat-grid; assert no value is clipped at the
    # card edge (DESIGN.md §4: stats must NEVER clip). The fixture counts are small, but
    # the geometry guard catches a layout that would clip a large all-time count.
    assert_no_value_clip("dl.stat-grid--wide .stat-card dd")
    screenshot_full_page("71-admin-stats-volume")
  end

  private

  # Assert the lightweight-charts Histogram trend chart actually painted: read every <canvas>
  # the library stacks inside the chart target and count non-transparent pixels across them.
  # A drawn histogram (bars + grid lines + axis labels) covers many pixels; a blank canvas (the
  # defect this convention exists to catch — markup assertions can't see it, DESIGN.md §4) has
  # zero. We require a generous floor so the test proves "something substantial was drawn",
  # not merely "a stray pixel exists". Mirrors amortization_screenshots_test#assert_donut_drawn.
  def assert_trend_chart_drawn
    nonblank = page.evaluate_script(<<~JS)
      (() => {
        const canvases = document.querySelectorAll('[data-volume-trend-chart-target=chart] canvas');
        if (canvases.length === 0) return -1;
        let n = 0;
        canvases.forEach((c) => {
          if (!c.width || !c.height) return;
          const ctx = c.getContext('2d');
          if (!ctx) return;
          const data = ctx.getImageData(0, 0, c.width, c.height).data;
          for (let i = 3; i < data.length; i += 4) { if (data[i] > 0) n++; }
        });
        return n;
      })()
    JS
    assert_operator nonblank, :>, 500,
      "expected the lightweight-charts trend canvas to be painted (>500 non-transparent " \
      "pixels), got #{nonblank} — the histogram did not render"
  end
end
