module Calculators
  # calculator.net's Ohm's Law page, as a multi-mode calculator (spec issue #54).
  # The four electrical quantities — Voltage (V), Current (I), Resistance (R) and
  # Power (P) — are related by `V = I × R` and `P = V × I`. The user supplies
  # exactly two via a required `mode` (one of the six unordered pairs) and the
  # calculator solves for the other two; all four are echoed/returned in `result`.
  #
  # Only the two inputs named by `mode` are required (the rest are recomputed).
  # Division-by-zero inputs surface as validation errors (422 via the §4 envelope),
  # never exceptions — and `rp` mode guards `P/R >= 0` before its square root.
  class OhmsLaw < Base
    MODES = %w[vi vr vp ir ip rp].freeze

    # Which inputs each mode requires (the two quantities its two letters name).
    REQUIRED_INPUTS = {
      "vi" => %i[voltage current],
      "vr" => %i[voltage resistance],
      "vp" => %i[voltage power],
      "ir" => %i[current resistance],
      "ip" => %i[current power],
      "rp" => %i[resistance power]
    }.freeze

    attribute :mode, :string
    attribute :voltage, :decimal
    attribute :current, :decimal
    attribute :resistance, :decimal
    attribute :power, :decimal

    validates :mode, presence: true, inclusion: { in: MODES }

    validate :required_inputs_present_and_numeric
    validate :no_division_by_zero

    private

    # Presence + numericality, but only for the inputs the selected mode needs.
    # ActiveModel coerces a non-numeric :decimal attribute to nil, so a nil after
    # assignment means "missing" or "not a number" — both a presence-style failure.
    def required_inputs_present_and_numeric
      required_inputs.each do |name|
        errors.add(name, :blank) if public_send(name).nil?
      end
    end

    # Division-by-zero (and the rp square-root domain) guards, per mode —
    # validation failures, never raised. Only runs once the required inputs are
    # present (guards on nil) so it never trips on a separately-reported blank.
    def no_division_by_zero
      case mode
      when "vi" then errors.add(:current, :other_than, count: 0) if current&.zero?
      when "vr" then errors.add(:resistance, :other_than, count: 0) if resistance&.zero?
      when "vp" then errors.add(:voltage, :other_than, count: 0) if voltage&.zero?
      when "ip" then errors.add(:current, :other_than, count: 0) if current&.zero?
      when "rp"
        errors.add(:resistance, :other_than, count: 0) if resistance&.zero?
        errors.add(:power, :greater_than_or_equal_to, count: 0) if power_over_resistance_negative?
      end
    end

    # rp solves `I = √(P / R)`; the radicand `P/R` must be ≥ 0. R = 0 is reported
    # separately (above), so only flag the sign when R is present and non-zero.
    def power_over_resistance_negative?
      resistance && !resistance.zero? && power && (power / resistance).negative?
    end

    def required_inputs = REQUIRED_INPUTS.fetch(mode, [])

    # `mode` is validated into MODES before #compute runs (it only runs when
    # valid?), so dispatching through `send` reaches a defined branch every time.
    def compute = send(:"compute_#{mode}")

    def compute_vi
      { voltage: voltage, current: current, resistance: voltage / current, power: voltage * current }
    end

    def compute_vr
      i = voltage / resistance
      { voltage: voltage, current: i, resistance: resistance, power: voltage * i }
    end

    def compute_vp
      { voltage: voltage, current: power / voltage, resistance: voltage * voltage / power, power: power }
    end

    def compute_ir
      { voltage: current * resistance, current: current, resistance: resistance, power: current * current * resistance }
    end

    def compute_ip
      { voltage: power / current, current: current, resistance: power / (current * current), power: power }
    end

    def compute_rp
      i = (power / resistance).sqrt(SQRT_PRECISION)
      { voltage: i * resistance, current: i, resistance: resistance, power: power }
    end

    # Significant digits for the only irrational branch (rp's square root).
    SQRT_PRECISION = 50
  end
end
