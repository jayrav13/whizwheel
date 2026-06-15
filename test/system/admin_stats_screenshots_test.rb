require "application_system_test_case"

# Drives the real browser through the admin stats dashboard (#221) and saves a full-page
# screenshot for the visual gate (CI uploads the PNG, reviewed against docs/DESIGN.md).
# Doubles as the Stimulus chart test: it asserts the dependency-free inline-SVG bar chart
# (bar_chart_controller) actually PAINTS — the SVG must contain rendered <rect> bars after
# the controller connects, the inline-SVG analogue of the mandatory "did it paint" canvas
# pixel check (DESIGN.md §4 "Charts": a blank chart is a hard failure, not a visual-gate
# catch). Signs in as alice (the admin from the roles fixture).
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

    # The trend chart: the bar_chart controller draws <rect> bars into the SVG target.
    # A non-empty bar count is the inline-SVG "did it actually paint" assertion — a blank
    # chart (no rects) is a hard failure, mirroring the canvas pixel check for JS charts.
    assert_selector "svg[data-bar-chart-target=svg] rect", minimum: 1
    bar_count = all("svg[data-bar-chart-target=svg] rect").count
    assert_operator bar_count, :>=, 1,
      "the trend chart painted no bars — bar_chart_controller did not render"

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
end
