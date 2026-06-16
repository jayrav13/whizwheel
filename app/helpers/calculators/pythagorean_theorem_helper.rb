# Per-calculator helper for the Pythagorean Theorem calculator (spec issue #253; split
# per issue #107). A leaner sibling of Right Triangle — sides only, no angles/area. Holds
# the field-label map (single source of truth for error phrasing, DESIGN.md §4), the two
# solve-for modes the picker renders, the ordered side figures the stat grid reads, and the
# SVG-figure geometry the result partial draws. Auto-included into views; slug
# `pythagorean_theorem` → Calculators::PythagoreanTheoremHelper::FIELD_LABELS in
# field_labels_for.
#
# Ruby helpers are coverage-counted (ARCHITECTURE.md §11), so every branch here is
# exercised by a test.
module Calculators
  module PythagoreanTheoremHelper
    # The visible label for each input — used to phrase validation errors against what the
    # page rendered ("Hypotenuse (c) …", not "c …").
    FIELD_LABELS = {
      "mode" => "Solve for",
      "a"    => "Leg a",
      "b"    => "Leg b",
      "c"    => "Hypotenuse (c)"
    }.freeze

    # The two solve-for modes (the `mode` input). Two multi-word labels → the DESIGN.md §4
    # selectable option list (.mode-option), each row naming the two given sides and the
    # side it solves for. `fields` lists the side-input keys that mode is GIVEN — the form
    # shows exactly those two and leaves the solved side blank.
    MODES = [
      {
        value:  "hypotenuse",
        label:  "Solve the hypotenuse",
        solves: "Given the two legs a and b → find c",
        fields: %w[a b]
      },
      {
        value:  "leg",
        label:  "Solve a leg",
        solves: "Given leg a and hypotenuse c → find b",
        fields: %w[a c]
      }
    ].freeze

    # The three side figures in a fixed read order, regardless of which mode was solved:
    # leg a, leg b, hypotenuse c. `symbol` is the side letter; the result partial lifts the
    # SOLVED side to accent green and tags it (the non-colour state cue, DESIGN.md §6).
    FIGURES = [
      { key: :a, label: "Leg a",          symbol: "a" },
      { key: :b, label: "Leg b",          symbol: "b" },
      { key: :c, label: "Hypotenuse",     symbol: "c" }
    ].freeze

    # The two solve-for modes, for the view (templates see a module's methods, not its
    # constants).
    def pythagorean_theorem_modes = MODES

    # The ordered side figures, for the result render.
    def pythagorean_theorem_figures = FIGURES

    # The result key the chosen mode SOLVES for ("hypotenuse" → :c, "leg" → :b) — so the
    # result render can lift exactly the solved side to accent green and tag it "Solved",
    # the others "Given" (DESIGN.md §6 — state never by colour alone).
    def pythagorean_theorem_solved_key(mode)
      mode == "leg" ? :b : :c
    end

    # Drop the calculator's six-decimal display string ("5.000000", "1.414214") to the
    # fewest places that keep it exact for display: trim trailing fractional zeros, and the
    # trailing dot if the value is whole ("5.000000" → "5", "1.414214" → "1.414214",
    # "0.000000" → "0"), then delimit the whole-number part so a large figure stays readable
    # under tabular-nums ("500000" → "500,000"). The backend always emits a fixed N.dddddd
    # string (ARCHITECTURE.md §10, §4), so there is always a whole part before the dot; the
    # FE only tidies trailing zeros and delimits for reading, never re-rounds.
    def pythagorean_theorem_value(string)
      # Trim only WITHIN the fraction (everything after the dot) so a leading "0" survives —
      # "0.000000" → "0", not "". A whole value loses its now-empty fraction (and the dot).
      whole, frac = string.to_s.split(".")
      frac = frac.to_s.sub(/0+\z/, "")
      delimited = number_with_delimiter(whole)
      frac.empty? ? delimited : "#{delimited}.#{frac}"
    end

    # The SVG figure geometry for a solved right triangle (DESIGN.md §4 visualisation
    # vocabulary, extended to a static labeled diagram — the spec explicitly permits inline
    # SVG here, NOT the charting library). Returns the three vertex points laid out inside a
    # `width × height` box (with `pad` margin for the labels), SCALED to the solved side
    # ratios so the drawn triangle is geometrically faithful — a 3-4-5 looks like a 3-4-5.
    # The right angle sits at the bottom-left; leg a runs up the left side (vertical), leg b
    # along the bottom (horizontal), the hypotenuse c spans them. Pure geometry → returns a
    # Hash the partial reads; no markup here.
    def pythagorean_theorem_points(result, width: 260, height: 190, pad: 34)
      leg_a = result[:a].to_f # vertical leg
      leg_b = result[:b].to_f # horizontal leg

      # Guard the degenerate read (defensive; #compute only runs when valid, so both > 0):
      # fall back to a unit value if a ratio can't be formed.
      leg_a = 1.0 if leg_a <= 0
      leg_b = 1.0 if leg_b <= 0

      box_w = width  - (pad * 2)
      box_h = height - (pad * 2)
      # Scale so the longer leg fills its box dimension; the shorter keeps the true ratio.
      scale  = [ box_w / leg_b, box_h / leg_a ].min
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
    def pythagorean_theorem_polygon(points)
      [ points[:right], points[:bottom], points[:top] ]
        .map { |x, y| "#{x.round(2)},#{y.round(2)}" }
        .join(" ")
    end
  end
end
