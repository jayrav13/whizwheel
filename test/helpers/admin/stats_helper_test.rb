require "test_helper"

# Unit tests for Admin::StatsHelper — the display formatting for the admin stats feed
# (#221). Ruby helpers are coverage-counted (ARCHITECTURE.md §11), so every branch is
# exercised here.
class Admin::StatsHelperTest < ActionView::TestCase
  # ── calculation_summary / summarize_pairs ──────────────────────────────

  test "summarizes inputs and result as a key: value sentence with an arrow" do
    summary = calculation_summary({ "weight" => "70" }, { "bmi" => "22.9" })
    assert_equal "weight: 70 → bmi: 22.9", summary
  end

  test "renders an empty side as an em dash" do
    assert_equal "— → bmi: 22.9", calculation_summary({}, { "bmi" => "22.9" })
    assert_equal "weight: 70 → —", calculation_summary({ "weight" => "70" }, {})
  end

  test "renders a nil side as an em dash" do
    assert_equal "— → —", calculation_summary(nil, nil)
  end

  test "parses a JSON-string side (legacy rows stored as a string)" do
    assert_equal "weight: 70 → —", calculation_summary('{"weight":"70"}', "{}")
  end

  test "treats an unparseable or non-object string side as empty" do
    assert_equal "— → —", calculation_summary("not json", "42")
  end

  test "truncates an outsized value so one field can't blow out the row" do
    long = "x" * 100
    summary = calculation_summary({ "note" => long }, {})
    assert_includes summary, "..."
    assert_not_includes summary, long
  end

  test "caps the number of pairs and appends an ellipsis when there are more" do
    inputs = { "a" => "1", "b" => "2", "c" => "3", "d" => "4" }
    summary = calculation_summary(inputs, {})
    assert_includes summary, "a: 1"
    assert_includes summary, "c: 3"
    assert_not_includes summary, "d: 4"
    assert_includes summary, "…"
  end

  test "returns a plain (non html_safe) string of the raw value so the view escapes it once" do
    # The summary is raw echoed data the view renders inside a <code> (DESIGN.md §2); the
    # value must reach the view UNescaped and not html_safe, so `<%= %>` escapes it exactly
    # once. A SafeBuffer here (or pre-escaped text) would double-escape: "<x>" → "&lt;x&gt;".
    summary = calculation_summary({ "tag" => "<x>" }, {})
    assert_equal "tag: <x> → —", summary
    assert_not summary.html_safe?, "summary must be a plain String so the view owns escaping"
  end

  test "shows all pairs without an ellipsis when within the cap" do
    summary = calculation_summary({ "a" => "1", "b" => "2", "c" => "3" }, {})
    assert_includes summary, "c: 3"
    assert_not_includes summary, "…"
  end

  # ── calculation_timestamp ──────────────────────────────────────────────

  test "formats a timestamp in the app timezone with a fixed, unambiguous shape" do
    time = Time.zone.local(2026, 6, 15, 14, 4, 0)
    assert_equal "Jun 15, 2026 · 2:04 PM", calculation_timestamp(time)
  end
end
