module Calculators
  # calculator.net's percentage page, as a multi-mode calculator (spec issue #30).
  #
  # Its core identity is `P × V1 = V2` (P = percent, V1 = the value it modifies,
  # V2 = the result), exposed solved for each unknown, plus the page's two
  # independent extras — percentage difference and percentage change. A required
  # `mode` selects the operation; the required inputs and the `result` key(s)
  # depend on that mode:
  #
  #   percent_of      → value   = v1 × percent / 100          (needs v1, percent)
  #   what_percent    → percent = v1 / v2 × 100               (needs v1, v2)
  #   percent_of_what → base    = v1 / (percent / 100)        (needs v1, percent)
  #   difference      → percent = |v1 − v2| / ((v1+v2)/2)×100 (needs v1, v2)
  #   change          → value   = v1 × (1 ± percent/100)      (needs v1, percent, direction)
  #
  # Only the inputs the selected mode names are required (the rest are ignored).
  # Division-by-zero inputs — `what_percent` v2 = 0, `percent_of_what` percent = 0,
  # `difference` v1 + v2 = 0 — surface as validation errors (422 via the §4
  # envelope), never exceptions.
  class Percentage < Base
    MODES = %w[percent_of what_percent percent_of_what difference change].freeze
    DIRECTIONS = %w[increase decrease].freeze

    HUNDRED = BigDecimal(100)

    # The decimal inputs each mode requires (presence + numericality).
    REQUIRED_INPUTS = {
      "percent_of" => %i[v1 percent],
      "what_percent" => %i[v1 v2],
      "percent_of_what" => %i[v1 percent],
      "difference" => %i[v1 v2],
      "change" => %i[v1 percent]
    }.freeze

    attribute :mode, :string
    attribute :v1, :decimal
    attribute :v2, :decimal
    attribute :percent, :decimal
    attribute :direction, :string

    validates :mode, presence: true, inclusion: { in: MODES }

    validate :required_inputs_present_and_numeric
    validate :direction_present_and_valid
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

    # `change` additionally requires a direction in [increase, decrease].
    def direction_present_and_valid
      return unless mode == "change"

      if direction.blank?
        errors.add(:direction, :blank)
      elsif DIRECTIONS.exclude?(direction)
        errors.add(:direction, :inclusion)
      end
    end

    # Division-by-zero guards, per mode — validation failures, never raised. Each
    # guards on nil first so it never trips on a separately-reported blank input.
    def no_division_by_zero
      case mode
      when "what_percent"
        errors.add(:v2, :other_than, count: 0) if v2&.zero?
      when "percent_of_what"
        errors.add(:percent, :other_than, count: 0) if percent&.zero?
      when "difference"
        # Neither v1 nor v2 alone is at fault — their *sum* is zero — so this is a
        # whole-record (:base) error, which the §4 envelope surfaces unprefixed.
        errors.add(:base, :other_than, count: 0) if v1 && v2 && (v1 + v2).zero?
      end
    end

    def required_inputs = REQUIRED_INPUTS.fetch(mode, [])

    # `mode` is validated into MODES before #compute runs (it only runs when
    # valid?), so dispatching through `send` reaches a defined branch every time.
    def compute = send(:"compute_#{mode}")

    def compute_percent_of      = { value: v1 * percent / HUNDRED }
    def compute_what_percent    = { percent: v1 / v2 * HUNDRED }
    def compute_percent_of_what = { base: v1 / (percent / HUNDRED) }
    def compute_difference      = { percent: (v1 - v2).abs / ((v1 + v2) / 2) * HUNDRED }
    def compute_change          = { value: v1 * change_factor }

    def change_factor
      direction == "increase" ? (1 + percent / HUNDRED) : (1 - percent / HUNDRED)
    end
  end
end
