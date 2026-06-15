require "test_helper"

# Unit tests for CalculationStats — the site-wide usage query object behind
# /admin/stats. Reference values come from the calculations fixtures
# (test/fixtures/calculations.yml). Purity (read-only, no request) makes this
# exhaustive from fixtures alone.
#
# The KEPT fixture set (the soft-deleted row is excluded everywhere):
#   anon_pct                 percentage  anon   today
#   alice_pct                percentage  alice  today
#   today_bmi_alice          bmi         alice  today
#   today_bmi_anon           bmi         anon   today
#   three_days_ago_tip_bob   tip         bob    3 days ago
#   ten_days_ago_loan_alice  loan        alice  10 days ago
#   old_mortgage_anon        mortgage    anon   100 days ago
#   deleted_today_bmi_alice  bmi         alice  today   <- SOFT-DELETED (never counted)
# => 7 kept rows total.
class CalculationStatsTest < ActiveSupport::TestCase
  setup { @stats = CalculationStats.new }

  # --- volume -------------------------------------------------------------

  test "volume counts the rolling windows, kept rows only" do
    assert_equal(
      { today: 4, last_7d: 5, last_30d: 6, all_time: 7 },
      @stats.volume
    )
  end

  test "volume excludes soft-deleted rows" do
    # Discarding a kept TODAY row drops today/7d/30d/all_time each by one.
    calculations(:today_bmi_anon).discard
    assert_equal(
      { today: 3, last_7d: 4, last_30d: 5, all_time: 6 },
      @stats.volume
    )
  end

  # --- daily_series -------------------------------------------------------

  test "daily_series is zero-filled, ordered oldest to newest, length == days" do
    series = @stats.daily_series(days: 30)

    assert_equal 30, series.length
    # ordered ascending by date
    dates = series.map { |d| d[:date] }
    assert_equal dates.sort, dates
    assert_equal Time.zone.today, dates.last

    # every entry is { date: Date, count: Integer }
    assert(series.all? { |d| d[:date].is_a?(Date) && d[:count].is_a?(Integer) })

    # zero-fill: most days in the window have no calculations
    assert_includes series.map { |d| d[:count] }, 0
  end

  test "daily_series buckets counts onto the right days" do
    series = @stats.daily_series(days: 30)
    by_date = series.to_h { |d| [ d[:date], d[:count] ] }

    today = Time.zone.today
    assert_equal 4, by_date.fetch(today)             # 4 kept rows today
    assert_equal 1, by_date.fetch(today - 3)         # three_days_ago_tip_bob
    assert_equal 1, by_date.fetch(today - 10)        # ten_days_ago_loan_alice

    # rows older than the window are not in the series at all
    assert_not_includes series.map { |d| d[:date] }, today - 100
    # and the window sum equals the 30-day volume
    assert_equal @stats.volume[:last_30d], series.sum { |d| d[:count] }
  end

  test "daily_series respects a custom day count" do
    series = @stats.daily_series(days: 7)
    assert_equal 7, series.length
    assert_equal Time.zone.today - 6, series.first[:date]
    assert_equal Time.zone.today, series.last[:date]
  end

  test "daily_series excludes soft-deleted rows" do
    calculations(:today_bmi_anon).discard
    today_count = @stats.daily_series(days: 30).to_h { |d| [ d[:date], d[:count] ] }.fetch(Time.zone.today)
    assert_equal 3, today_count
  end

  # --- top_calculators ----------------------------------------------------

  test "top_calculators ranks by kept count desc, then name asc" do
    assert_equal(
      [
        { calculator: "bmi",        count: 2 },
        { calculator: "percentage", count: 2 },
        { calculator: "loan",       count: 1 },
        { calculator: "mortgage",   count: 1 },
        { calculator: "tip",        count: 1 }
      ],
      @stats.top_calculators
    )
  end

  test "top_calculators honors the limit" do
    top = @stats.top_calculators(limit: 2)
    assert_equal 2, top.length
    assert_equal "bmi", top.first[:calculator]
  end

  test "top_calculators excludes soft-deleted rows" do
    # The deleted row is a bmi; bmi already excludes it (count stays 2). Discard a
    # kept bmi to prove deletion lowers the count.
    calculations(:today_bmi_anon).discard
    bmi = @stats.top_calculators.find { |c| c[:calculator] == "bmi" }
    assert_equal 1, bmi[:count]
  end

  # --- attribution --------------------------------------------------------

  test "attribution splits anonymous vs attributed, kept only" do
    assert_equal({ anonymous: 3, attributed: 4 }, @stats.attribution)
  end

  test "attribution excludes soft-deleted rows" do
    calculations(:today_bmi_anon).discard # an anonymous row
    assert_equal({ anonymous: 2, attributed: 4 }, @stats.attribution)
  end

  # --- top_users ----------------------------------------------------------

  test "top_users ranks signed-in users by kept count desc, anonymous excluded" do
    assert_equal(
      [
        { username: "alice", count: 3 },
        { username: "bob",   count: 1 }
      ],
      @stats.top_users
    )
  end

  test "top_users honors the limit" do
    top = @stats.top_users(limit: 1)
    assert_equal 1, top.length
    assert_equal "alice", top.first[:username]
  end

  test "top_users excludes soft-deleted rows" do
    calculations(:today_bmi_alice).discard # one of alice's kept rows
    alice = @stats.top_users.find { |u| u[:username] == "alice" }
    assert_equal 2, alice[:count]
  end

  # --- recent -------------------------------------------------------------

  test "recent returns kept rows newest-first with the documented shape" do
    rows = @stats.recent

    assert_equal 7, rows.length # the 7 kept rows, deleted one excluded
    assert_equal %i[calculator username created_at inputs result].sort, rows.first.keys.sort

    # newest-first ordering
    timestamps = rows.map { |r| r[:created_at] }
    assert_equal timestamps.sort.reverse, timestamps

    # the soft-deleted row never appears
    assert_not_includes rows.map { |r| r[:inputs] }, { "weight" => "99" }
  end

  test "recent surfaces anonymous rows with a nil username and attributed with the username" do
    rows = @stats.recent

    old = rows.find { |r| r[:calculator] == "mortgage" } # old_mortgage_anon
    assert_nil old[:username]
    assert_equal({ "price" => "300000" }, old[:inputs])

    tip = rows.find { |r| r[:calculator] == "tip" } # three_days_ago_tip_bob
    assert_equal "bob", tip[:username]
  end

  test "recent honors the limit" do
    assert_equal 2, @stats.recent(limit: 2).length
  end

  test "recent excludes soft-deleted rows" do
    before = @stats.recent.length
    calculations(:today_bmi_anon).discard
    assert_equal before - 1, @stats.recent.length
  end
end
