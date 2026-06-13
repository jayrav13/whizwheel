module Calculators
  # calculator.net's percentage page, as a single multi-mode calculator
  # (ARCHITECTURE.md §1, spec issue #30). Its core identity is `P × V1 = V2`
  # solved for each unknown, plus the page's two independent extras (percentage
  # difference and percentage change).
  #
  # A required `mode` selects the operation; only the inputs that mode needs are
  # required, and `result` carries only that mode's output key(s). Division-by-zero
  # inputs surface as validation errors (422 via the §4 envelope), never exceptions.
  class Percentage < Base
    MODES = %w[percent_of what_percent percent_of_what difference change].freeze
    DIRECTIONS = %w[increase decrease].freeze

    # Which inputs each mode requires.
    REQUIRED_INPUTS = {
      "percent_of"      => %i[v1 percent],
      "what_percent"    => %i[v1 v2],
      "percent_of_what" => %i[v1 percent],
      "difference"      => %i[v1 v2],
      "change"          => %i[v1 percent direction]
    }.freeze

    HUNDRED = BigDecimal(100)

    attribute :mode, :string
    attribute :v1, :decimal
    attribute :v2, :decimal
    attribute :percent, :decimal
    attribute :direction, :string

    validates :mode, presence: true, inclusion: { in: MODES }

    validate :required_inputs_present_and_numeric
    validate :direction_valid_for_change
    validate :no_division_by_zero

    private

    # Presence + numericality, but only for the inputs the selected mode needs.
    # ActiveModel already coerces a non-numeric :decimal attribute to nil, so a
    # nil after assignment means either "missing" or "not a number" — both are a
    # presence-style failure for the required set.
    def required_inputs_present_and_numeric
      required_decimal_inputs.each do |name|
        errors.add(name, :blank) if public_send(name).nil?
      end
    end

    # `direction` is required and constrained only in `change` mode.
    def direction_valid_for_change
      return unless mode == "change"

      if direction.blank?
        errors.add(:direction, :blank)
      elsif DIRECTIONS.exclude?(direction)
        errors.add(:direction, :inclusion)
      end
    end

    # Division-by-zero guards, per mode — validation failures, never raised.
    def no_division_by_zero
      case mode
      when "what_percent"
        errors.add(:v2, :other_than, count: 0) if v2&.zero?
      when "percent_of_what"
        errors.add(:percent, :other_than, count: 0) if percent&.zero?
      when "difference"
        errors.add(:base, :other_than, count: 0) if v1 && v2 && (v1 + v2).zero?
      end
    end

    def required_decimal_inputs
      REQUIRED_INPUTS.fetch(mode, []).select { |name| name != :direction }
    end

    # `mode` is validated into MODES before #compute runs (it only runs when
    # valid?), so dispatching through this table has no unreachable fallback the
    # way a `case` without `else` would.
    def compute
      send(:"compute_#{mode}")
    end

    def compute_percent_of      = { value: v1 * percent / HUNDRED }
    def compute_what_percent    = { percent: v1 / v2 * HUNDRED }
    def compute_percent_of_what = { base: v1 / (percent / HUNDRED) }
    def compute_difference      = { percent: (v1 - v2).abs / ((v1 + v2) / 2) * HUNDRED }
    def compute_change          = { value: change_value }

    def change_value
      factor = direction == "increase" ? (1 + percent / HUNDRED) : (1 - percent / HUNDRED)
      v1 * factor
    end
  end
end
