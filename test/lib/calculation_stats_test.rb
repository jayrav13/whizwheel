require "test_helper"

# Unit tests for CalculationStats — the site-wide usage query object behind
# /admin/stats. Reference values come from the calculations fixtures
# (test/fixtures/calculations.yml). Purity (read-only, no request) makes this
# exhaustive from fixtures alone.
#
# §6 invariant under test: site-wide admin stats count the FULL table —
# DISCARDED ROWS INCLUDED. "Usage is usage"; a user soft-deleting their own
# history hides it from their view but must not erode site-wide totals. So every
# aggregate below counts the discarded fixture row too, and `recent` returns it
# (flagged `discarded: true`).
#
# The FULL fixture set (all 8 rows counted; nothing is excluded):
#   anon_pct                 percentage  anon   today
#   alice_pct                percentage  alice  today
#   today_bmi_alice          bmi         alice  today
#   today_bmi_anon           bmi         anon   today
#   three_days_ago_tip_bob   tip         bob    3 days ago
#   ten_days_ago_loan_alice  loan        alice  10 days ago
#   old_mortgage_anon        mortgage    anon   100 days ago
#   deleted_today_bmi_alice  bmi         alice  today   <- SOFT-DELETED (STILL counted, §6)
# => 8 total rows, all of which count toward site-wide stats.
#
# Timezone note: daily_series buckets timestamps via `Time.zone` (app TZ). These
# tests run with `Time.zone == UTC` (config.time_zone is commented out, so Rails
# defaults to UTC). Daily-series correctness under a NON-UTC `Time.zone` is
# currently UNVERIFIED — if config.time_zone is ever set, add a case that fixes
# `Time.zone` to a non-UTC zone and asserts the day-bucketing still lines up.
class CalculationStatsTest < ActiveSupport::TestCase
  setup { @stats = CalculationStats.new }

  # --- volume -------------------------------------------------------------

  test "volume counts the rolling windows over the full table, discarded included" do
    assert_equal(
      { today: 5, last_7d: 6, last_30d: 7, all_time: 8 },
      @stats.volume
    )
  end

  test "volume counts a row whether or not it is discarded (§6)" do
    # Discarding a currently-kept TODAY row must NOT change any window total —
    # site-wide usage counts discarded rows.
    calculations(:today_bmi_anon).discard
    assert_equal(
      { today: 5, last_7d: 6, last_30d: 7, all_time: 8 },
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

  test "daily_series buckets counts onto the right days, discarded included (§6)" do
    series = @stats.daily_series(days: 30)
    by_date = series.to_h { |d| [ d[:date], d[:count] ] }

    today = Time.zone.today
    assert_equal 5, by_date.fetch(today)             # 5 rows today (incl. the discarded one)
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

  test "daily_series counts a discarded row too (§6)" do
    calculations(:today_bmi_anon).discard
    today_count = @stats.daily_series(days: 30).to_h { |d| [ d[:date], d[:count] ] }.fetch(Time.zone.today)
    assert_equal 5, today_count
  end

  # --- top_calculators ----------------------------------------------------

  test "top_calculators ranks by total count desc (discarded included), then name asc" do
    assert_equal(
      [
        { calculator: "bmi",        count: 3 }, # 2 kept + 1 discarded — §6 counts all 3
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

  test "top_calculators counts discarded rows (§6)" do
    # Discarding a currently-kept bmi must NOT lower bmi's site-wide count.
    calculations(:today_bmi_anon).discard
    bmi = @stats.top_calculators.find { |c| c[:calculator] == "bmi" }
    assert_equal 3, bmi[:count]
  end

  # --- attribution --------------------------------------------------------

  test "attribution splits anonymous vs attributed over the full table (§6)" do
    assert_equal({ anonymous: 3, attributed: 5 }, @stats.attribution)
  end

  test "attribution counts discarded rows (§6)" do
    calculations(:today_bmi_anon).discard # an anonymous row
    assert_equal({ anonymous: 3, attributed: 5 }, @stats.attribution)
  end

  # --- top_users ----------------------------------------------------------

  test "top_users ranks signed-in users by total count desc (discarded included), anonymous excluded" do
    assert_equal(
      [
        { username: "alice", count: 4 }, # 3 kept + 1 discarded — §6 counts all 4
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

  test "top_users counts discarded rows (§6)" do
    calculations(:today_bmi_alice).discard # one of alice's currently-kept rows
    alice = @stats.top_users.find { |u| u[:username] == "alice" }
    assert_equal 4, alice[:count]
  end

  # --- recent -------------------------------------------------------------

  test "recent returns the full table newest-first with the documented shape" do
    rows = @stats.recent

    assert_equal 8, rows.length # all 8 rows, discarded included (§6)
    assert_equal %i[calculator username created_at inputs result discarded].sort, rows.first.keys.sort

    # newest-first ordering
    timestamps = rows.map { |r| r[:created_at] }
    assert_equal timestamps.sort.reverse, timestamps

    # the soft-deleted row DOES appear (§6)
    assert_includes rows.map { |r| r[:inputs] }, { "weight" => "99" }
  end

  test "recent flags discarded rows true and kept rows false" do
    rows = @stats.recent

    discarded_row = rows.find { |r| r[:inputs] == { "weight" => "99" } } # deleted_today_bmi_alice
    assert discarded_row[:discarded], "the soft-deleted row should be flagged discarded: true"

    kept_row = rows.find { |r| r[:calculator] == "mortgage" } # old_mortgage_anon, kept
    assert_not kept_row[:discarded], "a kept row should be flagged discarded: false"
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

  test "recent includes a discarded row in its count (§6)" do
    # All 8 rows are returned; discarding one more currently-kept row keeps the
    # total at 8 (discarded rows are still counted).
    before = @stats.recent.length
    assert_equal 8, before
    calculations(:today_bmi_anon).discard
    assert_equal before, @stats.recent.length
  end

  test "recent ties break by id desc deterministically" do
    # Two rows sharing the SAME created_at must order by `id: :desc`. Build a pair
    # with an identical timestamp, then assert recent() returns the higher id
    # first among them — pinning the secondary sort key.
    ts = Time.zone.now.change(usec: 0)
    a = Calculation.create!(calculator: "tie", inputs: { "n" => "1" }, result: {}, created_at: ts)
    b = Calculation.create!(calculator: "tie", inputs: { "n" => "2" }, result: {}, created_at: ts)
    assert b.id > a.id, "fixture precondition: b is the later-inserted (higher id) row"

    tie_rows = @stats.recent.select { |r| r[:calculator] == "tie" }
    assert_equal [ { "n" => "2" }, { "n" => "1" } ], tie_rows.map { |r| r[:inputs] },
                 "same-timestamp rows must order by id desc (higher id first)"
  end
end
