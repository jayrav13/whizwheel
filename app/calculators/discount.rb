module Calculators
  # calculator.net's Discount page (spec issue #244) — a single-formula,
  # multi-input calculator in the shape proven by Percentage: one relationship,
  # a couple of inputs, a `mode` picker selecting how the discount is expressed.
  #
  # Given an original price and a discount, it computes the final (sale) price and
  # the amount saved. The discount is expressed two ways, selected by `mode`:
  #
  #   percent → saved = original_price × percent_off / 100;  final = price − saved
  #   fixed   → saved = amount_off;                          final = price − amount_off
  #
  # Each mode requires exactly the one discount field it uses; the other is left
  # blank. `fixed` additionally requires the amount off to not exceed the original
  # price (a discount cannot make the price negative). All such failures surface as
  # validation errors (422 via the §4 envelope), never exceptions.
  #
  # Precision/rounding (ARCHITECTURE.md §10): money is computed at full BigDecimal
  # precision then rendered as a two-decimal money string (half-up to the cent).
  class Discount < Base
    MODES = %w[percent fixed].freeze
    HUNDRED = BigDecimal(100)
    CENTS = 2

    attribute :mode, :string
    attribute :original_price, :decimal
    attribute :percent_off, :decimal
    attribute :amount_off, :decimal

    validates :mode, presence: true, inclusion: { in: MODES }
    validates :original_price, presence: true, numericality: { greater_than: 0 }

    validate :discount_field_present_and_valid
    validate :amount_off_within_price

    private

    # The one discount field the selected mode uses must be present and in range;
    # the percent field is additionally bounded to [0, 100]. Runs only once `mode`
    # is a known value (validations short-circuit nothing, so guard on MODES).
    def discount_field_present_and_valid
      case mode
      when "percent"
        if percent_off.nil?
          errors.add(:percent_off, :blank)
        elsif percent_off.negative? || percent_off > HUNDRED
          errors.add(:percent_off, :inclusion)
        end
      when "fixed"
        if amount_off.nil?
          errors.add(:amount_off, :blank)
        elsif amount_off.negative?
          errors.add(:amount_off, :greater_than_or_equal_to, count: 0)
        end
      end
    end

    # In `fixed` mode the amount off cannot exceed the original price — otherwise the
    # final price would be negative. Guards on nil first so it never trips on a
    # separately-reported blank/missing input.
    def amount_off_within_price
      return unless mode == "fixed"
      return if amount_off.nil? || original_price.nil?

      errors.add(:amount_off, :less_than_or_equal_to, count: original_price) if amount_off > original_price
    end

    # `mode` is validated into MODES before #compute runs (it only runs when valid?),
    # so this reaches a defined branch every time.
    def compute
      saved = amount_saved
      {
        mode: mode,
        original_price: money(original_price),
        final_price: money(original_price - saved),
        amount_saved: money(saved)
      }
    end

    def amount_saved
      mode == "percent" ? original_price * percent_off / HUNDRED : amount_off
    end

    # Money string, always exactly two decimal places (half-up to the cent).
    def money(value)
      whole, frac = value.round(CENTS, BigDecimal::ROUND_HALF_UP).to_s("F").split(".")
      "#{whole}.#{(frac.to_s + '00')[0, 2]}"
    end
  end
end
