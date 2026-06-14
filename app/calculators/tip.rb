module Calculators
  # calculator.net's tip page, as a single-mode multi-input calculator (spec
  # issue #75). Given a bill and a tip percentage, compute the tip and the grand
  # total; when split among N people, also the per-person tip and total.
  #
  # There is no `mode` picker — `people` defaults to 1, in which case the
  # per-person figures equal the whole-party figures.
  #
  # Money is computed at full BigDecimal precision and rounded to the cent (2dp,
  # half-up, §10) only for the output. Per-person figures derive from the RAW
  # (unrounded) tip/total, then round for display — so the per-person column need
  # not sum exactly to the whole-party column.
  class Tip < Base
    HUNDRED = BigDecimal(100)
    CENTS = 2

    attribute :bill, :decimal
    attribute :tip_percent, :decimal
    attribute :people, :integer, default: 1

    validates :bill, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :tip_percent, presence: true, numericality: { greater_than_or_equal_to: 0 }
    # `people` is an :integer attribute. The spec's "only integer" intent is
    # enforced by Base's coercion guard (#109): a fractional raw value like "2.5"
    # is rejected before validation, not silently truncated. Here we only need to
    # reject < 1 to keep the per-person divisor positive (no division by zero).
    validates :people, numericality: { greater_than_or_equal_to: 1 }

    private

    def compute
      raw_tip = bill * tip_percent / HUNDRED
      raw_total = bill + raw_tip
      {
        tip_amount: money(raw_tip),
        total: money(raw_total),
        tip_per_person: money(raw_tip / people),
        total_per_person: money(raw_total / people)
      }
    end

    def money(value) = value.round(CENTS)
  end
end
