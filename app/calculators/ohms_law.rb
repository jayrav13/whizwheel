module Calculators
  # calculator.net's Ohm's Law page, as a single multi-mode calculator
  # (ARCHITECTURE.md §3.2, spec issue #54). The four electrical quantities —
  # Voltage (V), Current (I), Resistance (R) and Power (P) — are related by
  # `V = I × R` and `P = V × I`, with the usual algebraic rearrangements.
  #
  # The user supplies EXACTLY TWO quantities; `mode` names the unordered pair
  # (one of the six), and the calculator solves for the other two. The `result`
  # always carries all four keys — the two given echo back, the two solved are
  # computed.
  #
  # Only the two inputs named by `mode` are required (the other two are ignored
  # and recomputed). Inputs that would divide by zero — and a negative radicand
  # in `rp` mode, which has no real square root — surface as validation errors
  # (422 via the §4 envelope), never exceptions. The math is exact BigDecimal;
  # rounding is for display only (§10).
  class OhmsLaw < Base
    MODES = %w[vi vr vp ir ip rp].freeze

    # Which two inputs each mode supplies (and therefore requires).
    REQUIRED_INPUTS = {
      "vi" => %i[voltage current],
      "vr" => %i[voltage resistance],
      "vp" => %i[voltage power],
      "ir" => %i[current resistance],
      "ip" => %i[current power],
      "rp" => %i[resistance power]
    }.freeze

    # Inputs that appear in a denominator for each mode (so a supplied zero is
    # invalid). `ir` divides by nothing and is omitted.
    DIVISORS = {
      "vi" => %i[current],          # R = V / I
      "vr" => %i[resistance],       # I = V / R
      "vp" => %i[voltage power],    # I = P / V, R = V² / P
      "ip" => %i[current],          # V = P / I, R = P / I²
      "rp" => %i[resistance]        # I = √(P / R)
    }.freeze

    # Significant digits for the only irrational branch (rp's square root) — far
    # beyond any display rounding the frontend applies (§10).
    SQRT_PRECISION = 50

    attribute :mode, :string
    attribute :voltage, :decimal
    attribute :current, :decimal
    attribute :resistance, :decimal
    attribute :power, :decimal

    validates :mode, presence: true, inclusion: { in: MODES }

    validate :required_inputs_present
    validate :no_division_by_zero
    validate :radicand_non_negative

    private

    # Presence for only the two inputs the selected mode supplies. ActiveModel
    # coerces a non-numeric :decimal to nil, so a nil after assignment is
    # "missing or not a number" — both a presence-style failure for the set.
    def required_inputs_present
      required_inputs.each do |name|
        errors.add(name, :blank) if public_send(name).nil?
      end
    end

    # A supplied zero in any of the mode's denominators is invalid — reported,
    # never raised. Guards on `&.zero?` so a separately-reported blank input
    # (nil) doesn't double up here.
    def no_division_by_zero
      DIVISORS.fetch(mode, []).each do |name|
        errors.add(name, :other_than, count: 0) if public_send(name)&.zero?
      end
    end

    # `rp` solves `I = √(P / R)`; the radicand `P / R` must be ≥ 0. Resistance is
    # guarded non-zero above, so only flag the sign once both are present and R
    # is non-zero (otherwise the division itself is already invalid).
    def radicand_non_negative
      return unless mode == "rp"
      return if power.nil? || resistance.nil? || resistance.zero?

      errors.add(:power, :greater_than_or_equal_to, count: 0) if (power / resistance).negative?
    end

    def required_inputs
      REQUIRED_INPUTS.fetch(mode, [])
    end

    # `mode` is validated into MODES before #compute runs (it only runs when
    # valid?), so this dispatch reaches a defined branch every time. Each branch
    # returns the full V/I/R/P set: the two given echoed, the two solved.
    def compute
      send(:"compute_#{mode}")
    end

    def compute_vi
      { voltage: voltage, current: current,
        resistance: voltage / current, power: voltage * current }
    end

    def compute_vr
      i = voltage / resistance
      { voltage: voltage, current: i,
        resistance: resistance, power: voltage * i }
    end

    def compute_vp
      { voltage: voltage, current: power / voltage,
        resistance: voltage * voltage / power, power: power }
    end

    def compute_ir
      { voltage: current * resistance, current: current,
        resistance: resistance, power: current * current * resistance }
    end

    def compute_ip
      { voltage: power / current, current: current,
        resistance: power / (current * current), power: power }
    end

    def compute_rp
      i = (power / resistance).sqrt(SQRT_PRECISION)
      { voltage: i * resistance, current: i,
        resistance: resistance, power: power }
    end
  end
end
