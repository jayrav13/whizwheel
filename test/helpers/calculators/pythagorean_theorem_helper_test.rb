require "test_helper"

# Unit tests for Calculators::PythagoreanTheoremHelper (spec issue #253) — the per-
# calculator display helper for the Pythagorean Theorem result render. The shared resolver
# behaviour (field_labels_for, the dispatch) is covered in calculators_helper_test.rb's
# derived sweep; this file pins THIS module's own display/geometry methods so their branches
# are covered by the 100% gate (ERB views are not coverage-counted — ARCHITECTURE.md §11 —
# so the helper Ruby is exercised here, not only via render).
class Calculators::PythagoreanTheoremHelperTest < ActionView::TestCase
  include Calculators::PythagoreanTheoremHelper

  # ── pythagorean_theorem_value — trim trailing zeros, never re-round ───────

  test "value trims a whole value's fractional zeros" do
    assert_equal "5", pythagorean_theorem_value("5.000000")
  end

  test "value keeps significant decimals and trims the rest" do
    assert_equal "2.4", pythagorean_theorem_value("2.400000")
    assert_equal "1.414214", pythagorean_theorem_value("1.414214")
  end

  test "value renders a zeroed value as plain 0" do
    # Trimming only within the fraction keeps the leading "0" → "0", never an empty string.
    assert_equal "0", pythagorean_theorem_value("0.000000")
  end

  test "value delimits a large whole value for readability" do
    assert_equal "500,000", pythagorean_theorem_value("500000.000000")
    assert_equal "1,234.5", pythagorean_theorem_value("1234.500000")
  end

  # ── pythagorean_theorem_modes / _figures — the constants ─────────────────

  test "modes exposes both solve-for modes" do
    values = pythagorean_theorem_modes.map { |m| m[:value] }
    assert_equal %w[hypotenuse leg], values
  end

  test "figures lists all three sides in read order" do
    keys = pythagorean_theorem_figures.map { |f| f[:key] }
    assert_equal %i[a b c], keys
  end

  # ── pythagorean_theorem_solved_key — which side a mode solves ─────────────

  test "solved_key maps hypotenuse mode to c and leg mode to b" do
    assert_equal :c, pythagorean_theorem_solved_key("hypotenuse")
    assert_equal :b, pythagorean_theorem_solved_key("leg")
  end

  # ── pythagorean_theorem_points — scaled geometry ─────────────────────────

  test "points returns the three vertices and label anchors" do
    points = pythagorean_theorem_points({ a: "3.000000", b: "4.000000", c: "5.000000" })
    # Right angle at bottom-left; both legs drawn positive within the padded box.
    assert_equal 260, points[:width]
    assert_equal 190, points[:height]
    rx, ry = points[:right]
    bx, _by = points[:bottom]
    _tx, ty = points[:top]
    assert_operator bx, :>, rx     # leg b runs to the right
    assert_operator ty, :<, ry     # leg a runs upward (smaller y)
    assert points.key?(:mid_a)
    assert points.key?(:mid_b)
    assert points.key?(:mid_c)
  end

  test "points scales the longer leg to fill its box dimension" do
    # A tall-thin 5-12-13: leg b (12) is longer, so it fills the horizontal box; either way
    # both drawn legs stay within the box.
    points = pythagorean_theorem_points({ a: "5.000000", b: "12.000000", c: "13.000000" })
    bx, _ = points[:bottom]
    assert_operator bx, :<=, 260 - 34  # within width - pad
  end

  test "points falls back to a unit triangle on a degenerate side" do
    # Defensive guard (compute only runs when valid, so this never happens in practice):
    # a non-positive read must not divide by zero — both branches fall back to 1.0.
    points = pythagorean_theorem_points({ a: "0.000000", b: "0.000000", c: "0.000000" })
    rx, ry = points[:right]
    bx, _by = points[:bottom]
    _tx, ty = points[:top]
    assert_operator bx, :>, rx
    assert_operator ty, :<, ry
  end

  # ── pythagorean_theorem_polygon — SVG points string ──────────────────────

  test "polygon renders three rounded x,y pairs" do
    points = pythagorean_theorem_points({ a: "3.000000", b: "4.000000", c: "5.000000" })
    polygon = pythagorean_theorem_polygon(points)
    assert_equal 3, polygon.split(" ").length
    polygon.split(" ").each { |pair| assert_match(/\A-?\d+(\.\d+)?,-?\d+(\.\d+)?\z/, pair) }
  end
end
