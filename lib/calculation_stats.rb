# Site-wide calculation-usage statistics for the admin dashboard (/admin/stats).
#
# An isolated query object (PORO) over the `calculation_logs` view (CalculationLog).
# It is the stable `@stats` contract the admin frontend (#221) renders against —
# the view calls ONLY the public methods below; keep their names and return shapes
# fixed.
#
# Invariants:
#   * Site-wide totals count the FULL view — discarded rows INCLUDED. Per
#     ARCHITECTURE.md §6, "usage is usage": a user soft-deleting their own history
#     hides it from THEIR view but must not erode site-wide totals. So none of the
#     aggregate methods filter `deleted_at` — they count every row.
#   * `recent` likewise returns ALL recent rows (discarded included) and tags each
#     with a `discarded:` boolean so the admin view can flag soft-deleted rows.
#   * Time math runs in the app timezone (`Time.zone`), so "today" / the daily
#     series line up with the configured zone, not raw UTC.
#
# Purity: no request, no Current.user — only the read model. That keeps it
# exhaustively testable to the 100% gate from fixtures.
class CalculationStats
  DEFAULT_DAILY_DAYS = 30
  DEFAULT_TOP_LIMIT  = 10
  DEFAULT_RECENT_LIMIT = 50

  # Counts over rolling windows, anchored to "now" in the app timezone.
  # Counts the full view — discarded rows included (§6).
  #   => { today:, last_7d:, last_30d:, all_time: }
  def volume
    {
      today:    all_rows.where(created_at: today_range).count,
      last_7d:  all_rows.where(created_at: days_ago_range(7)).count,
      last_30d: all_rows.where(created_at: days_ago_range(30)).count,
      all_time: all_rows.count
    }
  end

  # Chart-ready daily counts for the last `days` days, oldest → newest, with
  # zero-filled gaps so every day in the window has a row. Counts the full view —
  # discarded rows included (§6).
  #   => [{ date: Date, count: Integer }, ...]
  def daily_series(days: DEFAULT_DAILY_DAYS)
    start_date = (today - (days - 1))
    counts = counts_by_date(start_date)
    (0...days).map do |offset|
      date = start_date + offset
      { date: date, count: counts.fetch(date, 0) }
    end
  end

  # The most-run calculators, by total calculation count (discarded included, §6),
  # descending.
  #   => [{ calculator: String, count: Integer }, ...]
  def top_calculators(limit: DEFAULT_TOP_LIMIT)
    all_rows.group(:calculator)
            .order(count_all: :desc, calculator: :asc)
            .limit(limit)
            .count
            .map { |calculator, count| { calculator: calculator, count: count } }
  end

  # Anonymous (no user) vs. attributed (has a user) calculations, full view (§6).
  #   => { anonymous: Integer, attributed: Integer }
  def attribution
    {
      anonymous:  all_rows.where(user_id: nil).count,
      attributed: all_rows.where.not(user_id: nil).count
    }
  end

  # The most-active signed-in users, by total calculation count (discarded
  # included, §6), descending. Anonymous calculations (no user) are excluded.
  #   => [{ username: String, count: Integer }, ...]
  def top_users(limit: DEFAULT_TOP_LIMIT)
    all_rows.where.not(user_id: nil)
            .group(:username)
            .order(count_all: :desc, username: :asc)
            .limit(limit)
            .count
            .map { |username, count| { username: username, count: count } }
  end

  # The most-recent calculations, newest first — discarded rows INCLUDED (§6),
  # each tagged with a `discarded:` boolean so the admin view can flag them.
  #   => [{ calculator:, username: (nil=anonymous), created_at:, inputs:, result:, discarded: }, ...]
  def recent(limit: DEFAULT_RECENT_LIMIT)
    all_rows.order(created_at: :desc, id: :desc)
            .limit(limit)
            .map do |row|
              {
                calculator: row.calculator,
                username:   row.username,
                created_at: row.created_at,
                inputs:     row.inputs,
                result:     row.result,
                discarded:  row.deleted_at.present?
              }
            end
  end

  private

  # The base relation every query starts from: the FULL view, discarded rows
  # included (§6 — site-wide usage counts every calculation).
  def all_rows = CalculationLog.all

  # Counts grouped by calendar date (app TZ) from `start_date` forward — full
  # view, discarded included (§6). Grouped in Ruby so the date bucketing matches
  # `Time.zone` exactly rather than relying on the DB session timezone.
  def counts_by_date(start_date)
    all_rows.where(created_at: start_date.beginning_of_day..)
            .pluck(:created_at)
            .each_with_object(Hash.new(0)) { |ts, acc| acc[ts.in_time_zone.to_date] += 1 }
  end

  def today = Time.zone.today

  def today_range = today.beginning_of_day..today.end_of_day

  # A rolling window of `n` days ending now: from the start of the day `n-1`
  # days ago through now (so n=7 covers today + the prior 6 days).
  def days_ago_range(n)
    (today - (n - 1)).beginning_of_day..Time.zone.now
  end
end
