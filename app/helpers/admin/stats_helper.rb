module Admin
  # View helpers for the admin site-wide stats dashboard (#221). Frontend turf —
  # display formatting only, no queries (the data is the `@stats` / CalculationStats
  # contract from the controller). Ruby helpers are coverage-counted (ARCHITECTURE.md
  # §11), so every branch here is exercised by a test.
  module StatsHelper
    # A compact, human one-line summary of a recent calculation's inputs/result for the
    # activity feed, e.g. "weight: 70 → bmi: 22.9". Both `inputs` and `result` are plain
    # Hashes from the read model (CalculationLog#inputs/#result); we render up to a few
    # key/value pairs on each side so a wide row stays readable rather than dumping JSON.
    # An empty side (e.g. the original {} fixture rows) is shown as "—" so the row never
    # collapses to nothing.
    def calculation_summary(inputs, result)
      "#{summarize_pairs(inputs)} → #{summarize_pairs(result)}"
    end

    # Format a calculation's timestamp for the feed: a fixed, unambiguous, app-timezone
    # rendering ("Jun 15, 2026 · 2:04 PM") so the column aligns and reads the same on
    # every visitor's machine (no relative "3 days ago" drift in a screenshotted artifact).
    def calculation_timestamp(time)
      time.in_time_zone.strftime("%b %-d, %Y · %-l:%M %p")
    end

    private

    # Render a Hash as up to MAX_PAIRS "key: value" segments joined by commas; an empty
    # Hash becomes an em dash. Long values are truncated so one outsized field can't blow
    # out the row width. The read model can hand us either a Hash (jsonb) or, for legacy
    # rows stored as a JSON string, a String — coerce_hash normalizes both.
    MAX_PAIRS = 3
    VALUE_LIMIT = 24

    def summarize_pairs(value)
      hash = coerce_hash(value)
      return "—" if hash.blank?

      pairs = hash.first(MAX_PAIRS).map do |key, val|
        # `escape: false` keeps truncate's return a plain (non-SafeBuffer) String, so the
        # value is escaped exactly ONCE by the view's `<%= %>`. Without it, truncate returns
        # an html_safe SafeBuffer with the value already escaped, which the view then escapes
        # AGAIN — a "<x>" input rendering as the literal "&lt;x&gt;" (double-escape). This is
        # raw echoed data going into a <code> (DESIGN.md §2), so the view must own escaping.
        "#{key}: #{truncate(val.to_s, length: VALUE_LIMIT, escape: false)}"
      end
      pairs << "…" if hash.size > MAX_PAIRS
      pairs.join(", ")
    end

    # Normalize a read-model value into a Hash: pass a Hash through, parse a JSON String
    # (the view can surface jsonb as a string for older rows), and treat anything else
    # (nil, a non-object JSON value) as empty.
    def coerce_hash(value)
      return value if value.is_a?(Hash)

      if value.is_a?(String)
        parsed = JSON.parse(value) rescue nil
        return parsed if parsed.is_a?(Hash)
      end
      {}
    end
  end
end
