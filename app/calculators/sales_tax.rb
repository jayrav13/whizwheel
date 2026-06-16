module Calculators
  # calculator.net's sales-tax page, as a single solve-for-X calculator
  # (ARCHITECTURE.md §3.2, spec issue #242). Three related figures — the
  # before-tax price (B), the sales-tax rate (% , t = rate/100) and the
  # after-tax price (A) — sit on one relationship:
  #
  #   tax = B × t              # the tax dollar amount
  #   A   = B + tax = B × (1 + t)
  #
  # The user supplies exactly TWO of the figures; `mode` names which one is the
  # unknown, and the calculator solves for it (and always reports the tax amount).
  # The `result` always carries all five keys — `mode`, the two given echoed back,
  # the one solved, and `tax_amount`.
  #
  #   mode      given                                  solves for
  #   after     before_tax_price, rate                 after_tax_price
  #   before    after_tax_price, rate                  before_tax_price
  #   rate      before_tax_price, after_tax_price      rate (%)
  #
  # Only the two inputs the mode names are required (the third is left blank and
  # computed). A non-positive given price, a negative rate, and — in `rate` mode —
  # an after-tax price below the before-tax price (which would be a negative tax)
  # surface as validation errors (422 via the §4 envelope), never exceptions. The
  # math is exact BigDecimal; rounding is for display only (§10): money to the cent
  # (2 dp half-up), the rate to 4 dp half-up.
  #
  # NOTE: structural twin of the VAT calculator (#245) — identical solve-for-X
  # shape, differing only in domain labels. Keep the two implementations parallel.
  class SalesTax < Base
    MODES = %w[after before rate].freeze

    HUNDRED = BigDecimal(100)
    ONE = BigDecimal(1)
    CENTS = 2       # money: 2 dp half-up (§10)
    RATE_DP = 4     # rate displayed to 4 dp half-up

    # Which two figures each mode supplies (and therefore requires). The third —
    # the one the mode solves for — is left blank.
    REQUIRED_INPUTS = {
      "after" => %i[before_tax_price rate],
      "before" => %i[after_tax_price rate],
      "rate" => %i[before_tax_price after_tax_price]
    }.freeze

    attribute :mode, :string
    attribute :before_tax_price, :decimal
    attribute :after_tax_price, :decimal
    attribute :rate, :decimal

    validates :mode, presence: true, inclusion: { in: MODES }

    # Range rules apply to whichever figures the mode actually supplies (a blank,
    # mode-irrelevant field must not trip its own range check). `allow_nil` defers
    # the "missing" report to #required_inputs_present below.
    validates :before_tax_price, numericality: { greater_than: 0 }, allow_nil: true
    validates :after_tax_price, numericality: { greater_than: 0 }, allow_nil: true
    validates :rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    validate :required_inputs_present
    validate :after_not_below_before

    private

    # Presence for only the two figures the selected mode supplies. ActiveModel
    # coerces a blank/non-numeric :decimal to nil (the Base coercion guard already
    # rejected genuine garbage), so a nil after assignment is the "missing" case.
    def required_inputs_present
      required_inputs.each do |name|
        errors.add(name, :blank) if public_send(name).nil?
      end
    end

    # In `rate` mode the tax is A − B, which must be non-negative — so the given
    # after-tax price cannot fall below the given before-tax price. Only checked
    # once both figures are present (their blanks are reported above).
    def after_not_below_before
      return unless mode == "rate"
      return if before_tax_price.nil? || after_tax_price.nil?

      if after_tax_price < before_tax_price
        errors.add(:after_tax_price, :greater_than_or_equal_to, count: before_tax_price)
      end
    end

    def required_inputs
      REQUIRED_INPUTS.fetch(mode, [])
    end

    # `mode` is validated into MODES before #compute runs (it only runs when
    # valid?), so this dispatch always reaches a defined branch. Each branch
    # returns the full five-key result: mode echoed, the three figures (two given,
    # one solved) and the tax amount, money/rate rounded for display (§10).
    def compute
      send(:"compute_#{mode}")
    end

    # given B, rate → tax = B × rate/100; A = B + tax.
    def compute_after
      tax = before_tax_price * rate / HUNDRED
      after = before_tax_price + tax
      envelope(before: before_tax_price, after: after, rate: rate, tax: tax)
    end

    # given A, rate → B = A / (1 + rate/100); tax = A − B.
    def compute_before
      before = after_tax_price / (ONE + rate / HUNDRED)
      tax = after_tax_price - before
      envelope(before: before, after: after_tax_price, rate: rate, tax: tax)
    end

    # given B, A → tax = A − B; rate = (tax / B) × 100.
    def compute_rate
      tax = after_tax_price - before_tax_price
      rate = tax / before_tax_price * HUNDRED
      envelope(before: before_tax_price, after: after_tax_price, rate: rate, tax: tax)
    end

    # Assemble the five-key result from raw (full-precision) figures, rounding for
    # display: money to the cent, the rate to 4 dp (both half-up, §10).
    def envelope(before:, after:, rate:, tax:)
      {
        mode: mode,
        before_tax_price: money(before),
        after_tax_price: money(after),
        rate: rate.round(RATE_DP),
        tax_amount: money(tax)
      }
    end

    def money(value) = value.round(CENTS)
  end
end
