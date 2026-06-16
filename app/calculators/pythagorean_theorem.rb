module Calculators
  # calculator.net's Pythagorean Theorem calculator (spec issue #243) — a leaner
  # sibling of Right Triangle that isolates the side-solving core: given TWO of the
  # three sides of a right triangle, solve for the missing one via `a² + b² = c²`
  # (where `c` is the hypotenuse). No angles, no area — just the sides.
  #
  # A `mode` input selects which side is unknown:
  #
  #   - `hypotenuse` — both legs `a`, `b` are given; solve `c = √(a² + b²)`.
  #   - `leg`        — leg `a` and hypotenuse `c` are given; solve `b = √(c² − a²)`.
  #
  # `a` and `b` are the legs; `c` is the hypotenuse (opposite the right angle). Each
  # mode requires exactly the two sides it is GIVEN; the side it solves for is left
  # blank.
  #
  # Precision/rounding (ARCHITECTURE.md §10, matching Right Triangle): the √ is taken
  # via BigDecimal#sqrt at high precision (no float drift), then every side is
  # DISPLAYED to six decimal places, half-up, as a fixed N.dddddd string. The spec's
  # reference values pin these exactly.
  #
  # Domain guards surface as validation errors (422 via the §4 envelope), never
  # exceptions: each mode requires exactly its two given sides, every side must be
  # > 0, and in `leg` mode the hypotenuse `c` must be strictly greater than the known
  # leg `a` (else √(c² − a²) is zero or imaginary — no real triangle).
  class PythagoreanTheorem < Base
    MODES = %w[hypotenuse leg].freeze

    # Working precision for the √ step — far beyond the six displayed places, so the
    # half-up rounding is never on a knife's edge.
    PRECISION = 50

    # Displayed decimal places for every side output (spec Notes).
    DISPLAY_DP = 6

    attribute :mode, :string
    attribute :a, :decimal
    attribute :b, :decimal
    attribute :c, :decimal

    validates :mode, presence: true, inclusion: { in: MODES }
    validates :a, presence: true, numericality: { greater_than: 0 }
    # b is given (and required) only in `hypotenuse` mode; c only in `leg` mode. When
    # a side IS supplied it must be a positive number — guarded conditionally so the
    # unused side staying blank is never a "greater than 0" failure.
    validates :b, presence: true, numericality: { greater_than: 0 }, if: -> { mode == "hypotenuse" }
    validates :c, presence: true, numericality: { greater_than: 0 }, if: -> { mode == "leg" }

    validate :hypotenuse_exceeds_leg

    private

    # In `leg` mode the hypotenuse must be strictly greater than the known leg,
    # otherwise √(c² − a²) is zero or imaginary — no real triangle. Only flagged once
    # both sides are present and positive (so it never piles onto a blank/range error).
    def hypotenuse_exceeds_leg
      return unless mode == "leg"
      return if a.nil? || c.nil?
      return unless a.positive? && c.positive?

      errors.add(:c, :greater_than, count: "leg a") if c <= a
    end

    # `mode` is validated into MODES before #compute runs (#result only computes when
    # valid?), and the two given sides are present + positive, so both branches reach
    # a real triangle. The result echoes `mode` and carries all three sides — each a
    # fixed N.dddddd string (§4 result shape).
    def compute
      leg_a, leg_b, hyp =
        if mode == "hypotenuse"
          [ a, b, (a * a + b * b).sqrt(PRECISION) ]
        else
          [ a, (c * c - a * a).sqrt(PRECISION), c ]
        end

      {
        mode: mode,
        a: fmt(leg_a),
        b: fmt(leg_b),
        c: fmt(hyp)
      }
    end

    # A value as a fixed six-decimal-place string, half-up. BigDecimal#to_s("F")
    # drops trailing zeros ("5.0", "12.0"), so pad the fraction to exactly DISPLAY_DP
    # places — every output is N.dddddd (the schema's contract the FE renders).
    def fmt(value)
      whole, frac = value.round(DISPLAY_DP).to_s("F").split(".")
      "#{whole}.#{(frac.to_s + ('0' * DISPLAY_DP))[0, DISPLAY_DP]}"
    end
  end
end
