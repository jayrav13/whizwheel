require "test_helper"

# Unit tests for Calculators::RightTriangleHelper (issue #193) — the per-calculator
# display helper for the Right Triangle result render. The shared resolver behaviour
# (field_labels_for, the dispatch) is covered in calculators_helper_test.rb's derived
# sweep; this file pins THIS module's own display/geometry methods so their branches are
# covered by the 100% gate (ERB views are not coverage-counted — ARCHITECTURE.md §11 —
# so the helper Ruby is exercised here, not only via render).
class Calculators::RightTriangleHelperTest < ActionView::TestCase
  include Calculators::RightTriangleHelper

  # ── right_triangle_value — trim trailing zeros, never re-round ────────────

  test "right_triangle_value trims a whole value's fractional zeros" do
    assert_equal "5", right_triangle_value("5.000000")
  end

  test "right_triangle_value keeps significant decimals and trims the rest" do
    assert_equal "2.4", right_triangle_value("2.400000")
    assert_equal "36.869898", right_triangle_value("36.869898")
  end

  test "right_triangle_value renders a zeroed value as plain 0" do
    # Trimming only within the fraction keeps the leading "0" → "0", never an empty string.
    assert_equal "0", right_triangle_value("0.000000")
  end

  test "right_triangle_value delimits a large whole value for readability" do
    assert_equal "500,000", right_triangle_value("500000.000000")
    assert_equal "1,234.5", right_triangle_value("1234.500000")
  end

  # ── right_triangle_modes / right_triangle_figures — the constants ─────────

  test "right_triangle_modes exposes both solve-from modes" do
    values = right_triangle_modes.map { |m| m[:value] }
    assert_equal %w[legs leg_hyp], values
  end

  test "right_triangle_figures lists all eight figures in read order" do
    keys = right_triangle_figures.map { |f| f[:key] }
    assert_equal %i[a b c alpha beta area perimeter altitude], keys
  end

  # ── right_triangle_points — scaled geometry ──────────────────────────────

  test "right_triangle_points returns the three vertices and label anchors" do
    points = right_triangle_points({ a: "3.000000", b: "4.000000", c: "5.000000" })
    # Right angle at bottom-left; both legs drawn positive within the padded box. The viewBox
    # is widened (issue #215) to a 320×190 box with a horizontal label gutter on each side.
    assert_equal 320, points[:width]
    assert_equal 190, points[:height]
    assert_operator points[:gutter], :>, 0
    rx, ry = points[:right]
    bx, _by = points[:bottom]
    _tx, ty = points[:top]
    assert_operator bx, :>, rx     # leg b runs to the right
    assert_operator ty, :<, ry     # leg a runs upward (smaller y)
    assert points.key?(:mid_a)
    assert points.key?(:mid_b)
    assert points.key?(:mid_c)
    # Angle-label anchors are now computed (clamped) in the helper, not inline in the ERB.
    assert points.key?(:alpha)
    assert points.key?(:beta)
  end

  test "right_triangle_points insets the triangle by the gutter so labels never clip" do
    # Issue #215: the figure reserves an empty horizontal gutter on each side; the drawn
    # triangle's right-angle vertex sits inset by the gutter (x > gutter), leaving room for
    # outward-growing edge labels.
    points = right_triangle_points({ a: "3.000000", b: "4.000000", c: "5.000000" })
    right_x, = points[:right]
    assert_operator right_x, :>=, points[:gutter],
      "the drawn triangle should sit inside the left label gutter"
  end

  test "right_triangle_points clamps the angle labels inside the figure on a degenerate triangle" do
    # Issue #215: a near-degenerate tall-thin triangle (a tiny leg b) pulls the bottom vertex
    # hard against the origin; without a clamp the `end`-anchored α label would grow off the
    # left margin. The α anchor x is floored, and β ceilinged, so both stay inside the figure.
    width  = 320
    gutter = 30
    points = right_triangle_points({ a: "300000.000000", b: "3.000000", c: "300000.000000" })
    alpha_x, = points[:alpha]
    beta_x,  = points[:beta]
    # α is anchored `end`, growing left — its anchor must be far enough right that the longest
    # angle string still ends to the right of the left gutter edge.
    assert_operator alpha_x, :>=, gutter,
      "the α label anchor must be floored inside the left gutter so the text can't clip"
    # β is anchored `start`, growing right — its anchor must stay left of the right gutter edge.
    assert_operator beta_x, :<=, width - gutter,
      "the β label anchor must be ceilinged inside the right gutter so the text can't clip"
  end

  test "right_triangle_points anchors the leg-a label inside the vertical leg" do
    # The leg-`a` label sits just INSIDE the vertical leg (x to the RIGHT of the left pad) so,
    # rendered text-anchor=start, it grows into the triangle interior — a high-magnitude value
    # ("a = 300,000") can never overflow the figure's left margin (QA #272 clip, propagated
    # from Pythagorean). The old left-of-leg position (x = pad - 6) is the regression this pins.
    points = right_triangle_points({ a: "300000.000000", b: "400000.000000", c: "500000.000000" })
    mid_a_x, = points[:mid_a]
    right_x, = points[:right]   # the left/bottom vertex x == pad
    assert_operator mid_a_x, :>, right_x,
      "leg-a label must be inside (right of) the vertical leg so it grows into the interior"
  end

  test "right_triangle_points scales the longer leg to fill its box dimension" do
    # A tall-thin 5-12-13: leg b (12) is longer, so it should fill the horizontal box more
    # than a square 1-1 would; either way both drawn legs stay within the box (the drawable
    # area is the viewBox minus the label gutter on each side and the pad — issue #215).
    points = right_triangle_points({ a: "5.000000", b: "12.000000", c: "13.000000" })
    bx, _ = points[:bottom]
    assert_operator bx, :<=, points[:width] - points[:gutter] - 34  # within width - gutter - pad
  end

  test "right_triangle_points falls back to a unit triangle on a degenerate side" do
    # Defensive guard (compute only runs when valid, so this never happens in practice):
    # a non-positive read must not divide by zero — both branches fall back to 1.0.
    points = right_triangle_points({ a: "0.000000", b: "0.000000", c: "0.000000" })
    rx, ry = points[:right]
    bx, _by = points[:bottom]
    _tx, ty = points[:top]
    assert_operator bx, :>, rx
    assert_operator ty, :<, ry
  end

  # ── right_triangle_polygon — SVG points string ───────────────────────────

  test "right_triangle_polygon renders three rounded x,y pairs" do
    points = right_triangle_points({ a: "3.000000", b: "4.000000", c: "5.000000" })
    polygon = right_triangle_polygon(points)
    assert_equal 3, polygon.split(" ").length
    polygon.split(" ").each { |pair| assert_match(/\A-?\d+(\.\d+)?,-?\d+(\.\d+)?\z/, pair) }
  end
end
