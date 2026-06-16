module Calculators
  # calculator.net's VAT calculator (spec issue #245) — a solve-for-X
  # value-added-tax calculator over three related figures: the NET price
  # (before VAT), the VAT RATE (%), and the GROSS price (after VAT).
  #
  # The single relationship `gross = net × (1 + rate/100)` drives all three
  # modes; a `mode` picker names which figure is the unknown, and the
  # calculator solves for it (always reporting the VAT amount = gross − net):
  #
  #   - `gross` → given net + rate, solve gross:  vat = net × rate/100; gross = net + vat.
  #   - `net`   → given gross + rate, solve net:   net = gross / (1 + rate/100); vat = gross − net.
  #   - `rate`  → given net + gross, solve rate:   vat = gross − net; rate = (vat / net) × 100.
  #
  # Each mode requires exactly the two figures it is GIVEN; the field it solves
  # for is left blank. In `rate` mode the gross must be ≥ net (a non-negative
  # VAT). The result always carries all five keys — the two given echo back, the
  # solved one is computed, plus the VAT amount.
  #
  # This is the deliberate structural twin of the Sales Tax calculator
  # (net/VAT/gross ↔ before/tax/after) — same solve-for-X shape, three modes,
  # differing only in domain labels.
  #
  # Precision/rounding (ARCHITECTURE.md §10): full-precision BigDecimal compute;
  # money (net_price, gross_price, vat_amount) rounds to the cent half-up and is
  # emitted as a two-decimal string; `rate` rounds to 4 dp half-up.
  class Vat < Base
    HUNDRED = BigDecimal(100)
    MONEY_DP = 2
    RATE_DP = 4

    MODES = %w[gross net rate].freeze

    # The two figures each mode is GIVEN (and therefore requires); the third is
    # what the mode solves for.
    REQUIRED_INPUTS = {
      "gross" => %i[net_price rate],
      "net"   => %i[gross_price rate],
      "rate"  => %i[net_price gross_price]
    }.freeze

    attribute :mode, :string
    attribute :net_price, :decimal
    attribute :gross_price, :decimal
    attribute :rate, :decimal

    validates :mode, presence: true, inclusion: { in: MODES }
    validates :net_price, numericality: { greater_than: 0 }, allow_nil: true
    validates :gross_price, numericality: { greater_than: 0 }, allow_nil: true
    validates :rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    # Each mode requires exactly the two figures it is GIVEN.
    validate :required_inputs_present
    # In `rate` mode the VAT (gross − net) must be non-negative.
    validate :gross_not_below_net_in_rate_mode

    private

    # `mode` is validated into MODES before #compute runs (result only computes
    # when valid?), so this dispatch always reaches a defined branch. Each branch
    # returns the full {net, gross, rate, vat} set at full precision; #compute
    # then formats money and rate for display.
    def compute
      net, gross, solved_rate, vat = solve
      {
        mode: mode,
        net_price: money(net),
        gross_price: money(gross),
        rate: rate_display(solved_rate),
        vat_amount: money(vat)
      }
    end

    # Resolve the full [net, gross, rate, vat] tuple at full precision, filling
    # in the one figure the chosen mode solves for. Returns BigDecimals.
    def solve
      case mode
      when "gross" then solve_gross
      when "net"   then solve_net
      else              solve_rate
      end
    end

    # given net + rate → vat = net × rate/100; gross = net + vat.
    def solve_gross
      vat = net_price * rate / HUNDRED
      gross = net_price + vat
      [ net_price, gross, rate, vat ]
    end

    # given gross + rate → net = gross / (1 + rate/100); vat = gross − net.
    def solve_net
      net = gross_price / (1 + rate / HUNDRED)
      vat = gross_price - net
      [ net, gross_price, rate, vat ]
    end

    # given net + gross → vat = gross − net; rate = (vat / net) × 100.
    def solve_rate
      vat = gross_price - net_price
      solved_rate = vat / net_price * HUNDRED
      [ net_price, gross_price, solved_rate, vat ]
    end

    def required_inputs_present
      return unless MODES.include?(mode)

      REQUIRED_INPUTS.fetch(mode).each do |attr|
        errors.add(attr, :blank) if public_send(attr).nil?
      end
    end

    # `rate` mode derives the rate from gross − net, which must be ≥ 0 (no
    # negative VAT). Only checked once both figures are present.
    def gross_not_below_net_in_rate_mode
      return unless mode == "rate"
      return if net_price.nil? || gross_price.nil?
      return if gross_price >= net_price

      errors.add(:gross_price, :greater_than_or_equal_to,
        message: "must be greater than or equal to the net price")
    end

    # Money string, always two decimal places (half-up to the cent).
    def money(value) = fmt(value.round(MONEY_DP), MONEY_DP)

    # Rate string, always four decimal places (half-up).
    def rate_display(value) = fmt(value.round(RATE_DP), RATE_DP)

    # Render a BigDecimal as a fixed-point string padded to exactly +dp+ places.
    # BigDecimal#to_s("F") drops trailing zeros, so pad the fractional part.
    def fmt(value, dp)
      whole, frac = value.to_s("F").split(".")
      "#{whole}.#{(frac.to_s + ('0' * dp))[0, dp]}"
    end
  end
end
