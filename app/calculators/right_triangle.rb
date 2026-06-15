require "bigdecimal/math"

module Calculators
  # calculator.net's Right Triangle calculator (spec issue #192) — the project's
  # first trigonometry calculator.
  #
  # Given TWO known sides of a right triangle, solve for everything else: the third
  # side, both acute angles (in degrees), the area, the perimeter, and the altitude
  # to the hypotenuse. A `mode` input selects which two sides are the knowns:
  #
  #   - `legs`    — both legs `a`, `b` are given; solve `c = √(a² + b²)`.
  #   - `leg_hyp` — leg `a` and hypotenuse `c` are given; solve `b = √(c² − a²)`.
  #
  # Sides: `a` and `b` are the legs; `c` is the hypotenuse (opposite the right
  # angle). `α` (alpha) is the angle opposite `a`, `β` (beta) the angle opposite `b`
  # (α + β = 90°). Once the missing side is solved, all outputs follow from the two
  # legs and the hypotenuse:
  #
  #   area      = ½ · a · b
  #   perimeter = a + b + c
  #   altitude  = (a · b) / c          (altitude to the hypotenuse)
  #   α         = atan(a / b)  in degrees
  #   β         = atan(b / a)  in degrees
  #
  # Precision/rounding (ARCHITECTURE.md §10): √ via BigDecimal#sqrt and the angles
  # via BigMath.atan are computed at high BigDecimal precision (no float drift), then
  # every output is DISPLAYED to six decimal places, half-up, as a fixed N.dddddd
  # string. The reference values in the spec pin these exactly.
  #
  # Domain guards surface as validation errors (422 via the §4 envelope), never
  # exceptions: each mode requires exactly the two sides it is given, every side must
  # be > 0, and in `leg_hyp` mode the hypotenuse must be strictly greater than the
  # known leg (else there is no real triangle).
  class RightTriangle < Base
    MODES = %w[legs leg_hyp].freeze

    # Working precision for the transcendental/irrational steps (atan, √). Far beyond
    # the six displayed places, so the half-up rounding is never on a knife's edge.
    PRECISION = 50

    # Displayed decimal places for every length/area/angle output (spec Notes).
    DISPLAY_DP = 6

    attribute :mode, :string
    attribute :a, :decimal
    attribute :b, :decimal
    attribute :c, :decimal

    validates :mode, presence: true, inclusion: { in: MODES }
    validates :a, presence: true, numericality: { greater_than: 0 }
    # b is given (and required) only in `legs` mode; c only in `leg_hyp` mode. When a
    # side IS supplied it must be a positive number — guarded conditionally so the
    # unused side staying blank is never a "greater than 0" failure.
    validates :b, presence: true, numericality: { greater_than: 0 }, if: -> { mode == "legs" }
    validates :c, presence: true, numericality: { greater_than: 0 }, if: -> { mode == "leg_hyp" }

    validate :hypotenuse_exceeds_leg

    private

    # In leg_hyp mode the hypotenuse must be strictly greater than the known leg,
    # otherwise √(c² − a²) is zero or imaginary — no real triangle. Only flagged once
    # both sides are present and positive (so it never piles onto a blank/range error).
    def hypotenuse_exceeds_leg
      return unless mode == "leg_hyp"
      return if a.nil? || c.nil?
      return unless a.positive? && c.positive?

      errors.add(:c, :greater_than, count: "leg a") if c <= a
    end

    # `mode` is validated into MODES before #compute runs (#result only computes when
    # valid?), and the two given sides are present + positive, so both branches reach
    # a real triangle. The result echoes `mode` and carries all three sides plus the
    # derived angles, area, perimeter and altitude — every value a fixed N.dddddd
    # string (§4 result shape).
    def compute
      leg_a, leg_b, hyp =
        if mode == "legs"
          [ a, b, (a * a + b * b).sqrt(PRECISION) ]
        else
          [ a, (c * c - a * a).sqrt(PRECISION), c ]
        end

      {
        mode: mode,
        a: fmt(leg_a),
        b: fmt(leg_b),
        c: fmt(hyp),
        alpha: fmt(atan_degrees(leg_a / leg_b)),
        beta: fmt(atan_degrees(leg_b / leg_a)),
        area: fmt(leg_a * leg_b / 2),
        perimeter: fmt(leg_a + leg_b + hyp),
        altitude: fmt(leg_a * leg_b / hyp)
      }
    end

    # atan of a ratio, in degrees, at working precision: radians × 180 / π.
    def atan_degrees(ratio)
      BigMath.atan(ratio, PRECISION) * 180 / BigMath.PI(PRECISION)
    end

    # A value as a fixed six-decimal-place string, half-up. BigDecimal#to_s("F")
    # drops trailing zeros ("5.0", "2.4"), so pad the fraction to exactly DISPLAY_DP
    # places — every output is N.dddddd (the schema's contract the FE renders).
    def fmt(value)
      whole, frac = value.round(DISPLAY_DP).to_s("F").split(".")
      "#{whole}.#{(frac.to_s + ('0' * DISPLAY_DP))[0, DISPLAY_DP]}"
    end
  end
end
