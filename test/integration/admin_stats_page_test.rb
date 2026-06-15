require "test_helper"

# Integration tests for the admin site-wide stats dashboard page (#221): signed in as
# an admin, GET /admin/stats renders the real view with the volume stat cards, the trend
# chart container (+ its no-JS data table), the breakdown tables, and a discarded badge on
# the soft-deleted recent row. The data comes from the calculations fixtures via the
# `calculation_logs` view (CalculationStats). Together with the system test this is the
# §11 frontend gate. (The ADMIN gate itself — 404 for non-admins — is covered by
# Admin::StatsControllerTest; here alice is the admin from the roles fixture.)
class AdminStatsPageTest < ActionDispatch::IntegrationTest
  def sign_in_as_admin
    post session_path, params: { username: "alice", password: "password" }
    follow_redirect!
  end

  test "the page renders the title and the admin eyebrow" do
    sign_in_as_admin
    get admin_stats_path
    assert_response :success
    assert_select "h1", text: "Calculation statistics"
    assert_select "p", text: /site-wide usage/i
  end

  test "the volume stat grid renders the four window counts" do
    sign_in_as_admin
    get admin_stats_path
    # The shared stat grid (DESIGN.md §4) — wide track for a potentially large all-time count.
    assert_select "dl.stat-grid.stat-grid--wide"
    assert_select "dt", text: "Today"
    assert_select "dt", text: "Last 7 days"
    assert_select "dt", text: "Last 30 days"
    assert_select "dt", text: "All time"
    # all_time counts the FULL view (§6): 7 kept + 1 discarded = 8.
    assert_select "dd", text: "8"
  end

  test "the trend section wires the lightweight-charts controller with a series value over a no-JS table fallback" do
    sign_in_as_admin
    get admin_stats_path
    # The Stimulus controller (TradingView lightweight-charts Histogram, DESIGN.md §4) + its
    # JSON series value (the chart's data) and the container the controller draws into.
    assert_select "[data-controller=volume-trend-chart][data-volume-trend-chart-series-value]"
    assert_select "[data-volume-trend-chart-target=chart]"
    # The no-JS data-table fallback for the daily series (DESIGN.md §4 "Charts") — the only
    # place hand-rolled chart markup is allowed; the controller retires it once the chart paints.
    assert_select "[data-volume-trend-chart-target=fallback] table"
    assert_select "[data-volume-trend-chart-target=fallback] th", text: "Date"
  end

  test "the chart's series value is valid JSON of 30 {date,count} points" do
    sign_in_as_admin
    get admin_stats_path
    value = css_select("[data-volume-trend-chart-series-value]").first["data-volume-trend-chart-series-value"]
    series = JSON.parse(value)
    assert_equal 30, series.length
    assert(series.all? { |p| p.key?("date") && p.key?("count") })
  end

  test "the recent activity feed renders the echoed input -> result values in a monospace code element" do
    sign_in_as_admin
    get admin_stats_path
    # DESIGN.md §2: raw echoed data (the recent-activity input → result summaries) renders in a
    # real <code> with font-mono, not plain prose. The summary carries the "→" arrow joiner.
    assert_select "td code.font-mono", text: /→/
  end

  test "the breakdown tables render top calculators, top users and the attribution split" do
    sign_in_as_admin
    get admin_stats_path
    assert_select "h2", text: "Top calculators"
    assert_select "h2", text: "Top users"
    assert_select "h2", text: "Anonymous vs. attributed"
    # bmi appears 3× in the fixtures (incl. the discarded one, §6) — the top calculator.
    assert_select "td", text: "bmi"
    # alice is an attributed user with multiple rows.
    assert_select "td", text: "alice"
  end

  test "the recent activity feed flags the soft-deleted row with a Discarded badge" do
    sign_in_as_admin
    get admin_stats_path
    assert_select "h2", text: "Recent activity"
    # The discarded fixture row (deleted_today_bmi_alice) carries the BLEND discarded badge.
    assert_select "span", text: "Discarded"
  end

  test "an anonymous recent row shows 'anonymous' rather than a username" do
    sign_in_as_admin
    get admin_stats_path
    # Several fixture rows have no user (anon_pct, today_bmi_anon, …).
    assert_select "td span.italic", text: "anonymous"
  end
end
