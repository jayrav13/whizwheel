# Per-calculator helper for the Right Triangle calculator (issue #193; split per
# issue #107). Holds the field-label map (single source of truth for error phrasing,
# DESIGN.md §4), the two solve-from modes the picker renders, the ordered list of result
# figures the stat grid reads, and the SVG-figure geometry the result partial draws.
# Auto-included into views; slug `right_triangle` →
# Calculators::RightTriangleHelper::FIELD_LABELS in field_labels_for.
module Calculators
  module RightTriangleHelper
    # The visible label for each Right Triangle input — used to phrase validation errors
    # against what the page rendered ("Hypotenuse (c) …", not "c …").
    FIELD_LABELS = {
      "mode" => "Solve from",
      "a"    => "Leg a",
      "b"    => "Leg b",
      "c"    => "Hypotenuse (c)"
    }.freeze

    # The two solve-from modes (the `mode` input). Two multi-word labels → the §4
    # selectable option list (.mode-option), each row naming the two given sides and the
    # side it solves for. `fields` lists the side-input keys that mode is GIVEN — the form
    # shows exactly those two and leaves the solved side blank.
    MODES = [
      {
        value:  "legs",
        label:  "Two legs (a, b)",
        solves: "Solve for the hypotenuse c",
        fields: %w[a b]
      },
      {
        value:  "leg_hyp",
        label:  "Leg & hypotenuse (a, c)",
        solves: "Solve for the other leg b",
        fields: %w[a c]
      }
    ].freeze

    # The result figures in a fixed read order, regardless of which mode was solved: the
    # three sides first, then the two acute angles, then area / perimeter / altitude. Each
    # entry carries the result key, a label, a short symbol, and the unit suffix shown
    # beside the value. `kind: :angle` figures are degrees; the rest are lengths/derived.
    FIGURES = [
      { key: :a,         label: "Leg a",       symbol: "a", unit: "",  kind: :side  },
      { key: :b,         label: "Leg b",       symbol: "b", unit: "",  kind: :side  },
      { key: :c,         label: "Hypotenuse",  symbol: "c", unit: "",  kind: :side  },
      { key: :alpha,     label: "Angle α",     symbol: "α", unit: "°", kind: :angle },
      { key: :beta,      label: "Angle β",     symbol: "β", unit: "°", kind: :angle },
      { key: :area,      label: "Area",        symbol: "",  unit: "",  kind: :area  },
      { key: :perimeter, label: "Perimeter",   symbol: "",  unit: "",  kind: :side  },
      { key: :altitude,  label: "Altitude h",  symbol: "h", unit: "",  kind: :side  }
    ].freeze

    # The two solve-from modes, for the view (templates see a module's methods, not its
    # constants).
    def right_triangle_modes = MODES

    # The ordered result figures, for the result render.
    def right_triangle_figures = FIGURES

    # Drop the calculator's six-decimal display string ("5.000000", "36.869898") to the
    # fewest places that keep it exact for display: trim trailing fractional zeros, and the
    # trailing dot if the value is whole ("5.000000" → "5", "2.400000" → "2.4", "0.000000"
    # → "0"), then delimit the whole-number part so a large figure stays readable under
    # tabular-nums ("500000" → "500,000"). The backend always emits a fixed N.dddddd string
    # (ARCHITECTURE.md §10, §4), so there is always a whole part before the dot; the FE only
    # tidies trailing zeros and delimits for reading, never re-rounds.
    def right_triangle_value(string)
      # Trim only WITHIN the fraction (everything after the dot) so a leading "0" survives —
      # "0.000000" → "0", not "". A whole value loses its now-empty fraction (and the dot).
      whole, frac = string.to_s.split(".")
      frac = frac.to_s.sub(/0+\z/, "")
      delimited = number_with_delimiter(whole)
      frac.empty? ? delimited : "#{delimited}.#{frac}"
    end

    # The SVG figure geometry for a solved Right Triangle (DESIGN.md §4 charts/visualisation
    # vocabulary, extended to a static labeled diagram). Returns the three vertex points of a
    # right triangle laid out inside a `width × height` box (with `pad` margin for the labels),
    # SCALED to the solved side ratios so the drawn triangle is geometrically faithful — a 3-4-5
    # looks like a 3-4-5, a 5-12-13 reads tall and thin. The right angle sits at the bottom-left;
    # leg a runs up the left side (vertical), leg b along the bottom (horizontal), the hypotenuse
    # c spans them. Heights/widths come straight from the solved `result` so the picture matches
    # the numbers. Pure geometry → returns a Hash the partial reads; no markup here.
    def right_triangle_points(result, width: 260, height: 190, pad: 34)
      leg_a = result[:a].to_f # vertical leg
      leg_b = result[:b].to_f # horizontal leg

      # Guard the degenerate read (defensive; #compute only runs when valid, so both > 0):
      # fall back to an isosceles right triangle if a ratio can't be formed.
      leg_a = 1.0 if leg_a <= 0
      leg_b = 1.0 if leg_b <= 0

      box_w = width  - (pad * 2)
      box_h = height - (pad * 2)
      # Scale so the longer leg fills its box dimension; the shorter keeps the true ratio.
      scale = [ box_w / leg_b, box_h / leg_a ].min
      draw_b = leg_b * scale
      draw_a = leg_a * scale

      right  = [ pad, height - pad ]               # right-angle vertex (bottom-left)
      bottom = [ pad + draw_b, height - pad ]      # end of horizontal leg b
      top    = [ pad, height - pad - draw_a ]      # top of vertical leg a

      {
        width: width, height: height,
        right: right, bottom: bottom, top: top,
        # Edge midpoints, for the side labels (nudged outward off the stroke). mid_a sits
        # just left of the vertical leg, kept inside the padded box so the label isn't clipped.
        mid_a: [ pad - 6, height - pad - (draw_a / 2) ],           # left of leg a
        mid_b: [ pad + (draw_b / 2), height - pad + 18 ],          # below leg b
        mid_c: [ pad + (draw_b / 2) + 12, height - pad - (draw_a / 2) - 6 ] # over hypotenuse
      }
    end

    # An SVG polygon `points` string ("x1,y1 x2,y2 x3,y3") from the three vertices.
    def right_triangle_polygon(points)
      [ points[:right], points[:bottom], points[:top] ]
        .map { |x, y| "#{x.round(2)},#{y.round(2)}" }
        .join(" ")
    end
  end
end
