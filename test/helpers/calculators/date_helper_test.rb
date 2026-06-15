require "test_helper"

# Unit tests for Calculators::DateHelper (issue #195) — the per-calculator helper for the
# Date calculator. Ruby helpers are coverage-counted (ARCHITECTURE.md §11), so every method
# and branch here is exercised. The shared calculators_helper_test.rb is a derived file we
# never edit, so each per-calculator helper carries its own test alongside it (the #107
# no-shared-edit convention). ActionView::TestCase includes the module under test so its
# methods are callable in the view context, exactly as a template sees them.
class Calculators::DateHelperTest < ActionView::TestCase
  include Calculators::DateHelper

  # ── FIELD_LABELS ─────────────────────────────────────────────────────────

  test "FIELD_LABELS maps every input key to its visible label" do
    assert_equal "Start date", Calculators::DateHelper::FIELD_LABELS["start_date"]
    assert_equal "End date", Calculators::DateHelper::FIELD_LABELS["end_date"]
    assert_equal "Operation", Calculators::DateHelper::FIELD_LABELS["operation"]
    assert_equal "Calculation", Calculators::DateHelper::FIELD_LABELS["mode"]
    %w[years months weeks days].each do |key|
      assert_equal key.capitalize, Calculators::DateHelper::FIELD_LABELS[key]
    end
  end

  # ── date_modes / date_offset_fields ──────────────────────────────────────

  test "date_modes lists the two modes in spec order with helper copy" do
    assert_equal %w[difference add_subtract], date_modes.map { |m| m[:value] }
    assert date_modes.all? { |m| m[:label].present? && m[:helper].present? }
  end

  test "date_offset_fields lists the four offsets coarse-to-fine" do
    assert_equal %i[years months weeks days], date_offset_fields.map { |f| f[:key] }
    assert_equal %w[Years Months Weeks Days], date_offset_fields.map { |f| f[:label] }
  end

  # ── date_breakdown_phrase ────────────────────────────────────────────────

  test "date_breakdown_phrase joins the non-zero units" do
    assert_equal "2 years · 2 months · 5 days",
      date_breakdown_phrase(years: 2, months: 2, days: 5)
  end

  test "date_breakdown_phrase drops zero-valued units" do
    assert_equal "2 days", date_breakdown_phrase(years: 0, months: 0, days: 2)
  end

  test "date_breakdown_phrase singularizes a unit of one" do
    assert_equal "1 year · 1 month · 1 day",
      date_breakdown_phrase(years: 1, months: 1, days: 1)
  end

  test "date_breakdown_phrase falls back to '0 days' when every unit is zero" do
    assert_equal "0 days", date_breakdown_phrase(years: 0, months: 0, days: 0)
  end

  # ── date_weeks_phrase ────────────────────────────────────────────────────

  test "date_weeks_phrase names both units, pluralized" do
    assert_equal "113 weeks and 4 days",
      date_weeks_phrase(total_weeks: 113, remainder_days: 4)
  end

  test "date_weeks_phrase singularizes a single week and day" do
    assert_equal "1 week and 1 day",
      date_weeks_phrase(total_weeks: 1, remainder_days: 1)
  end

  test "date_weeks_phrase names zero parts rather than dropping them" do
    assert_equal "0 weeks and 0 days",
      date_weeks_phrase(total_weeks: 0, remainder_days: 0)
  end

  # ── date_long_format ─────────────────────────────────────────────────────

  test "date_long_format renders an ISO string as a long human date" do
    assert_equal "Wednesday, January 31, 2024", date_long_format("2024-01-31")
    assert_equal "Saturday, March 1, 2025", date_long_format("2025-03-01")
  end
end
