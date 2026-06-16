# Per-calculator helper for the Sales Tax calculator (spec issue #252; split per issue #107).
# Holds the field-label map (single source of truth for error phrasing, DESIGN.md §4) and the
# mode table the page reads. Auto-included into views; slug `sales_tax` →
# Calculators::SalesTaxHelper::FIELD_LABELS in field_labels_for.
#
# Structural twin of the VAT calculator (#255) — identical solve-for-X shape (before/tax/after,
# three modes), differing only in domain labels. Keep the two helpers parallel.
module Calculators
  module SalesTaxHelper
    # The visible label for each Sales Tax input — what the error phrasing reads back
    # (DESIGN.md §4: "phrase each message against the field's visible label"). `mode` is the
    # picker itself, so its label names the selector, not a field.
    FIELD_LABELS = {
      "mode"             => "Solve for",
      "before_tax_price" => "Before-tax price",
      "after_tax_price"  => "After-tax price",
      "rate"             => "Tax rate"
    }.freeze

    # The three solve-for modes (DESIGN.md §4 "Mode picker"): a single-select posted as
    # inputs[mode]. Three SHORT labels (N = 3), so per the §4 rule the picker is the SEGMENTED
    # CONTROL (the connected horizontal track), not the option list. `label` rides on the
    # segment; `helper` is the one-line description shown under the active segment naming what it
    # solves; `fields` are the two given inputs that mode reveals (the third is solved). Order is
    # fixed so the picker always reads the same.
    MODES = [
      { value: "after",  label: "After-tax price",  helper: "Add tax to a price — give the before-tax price and the tax rate.",   fields: %w[before_tax_price rate] },
      { value: "before", label: "Before-tax price", helper: "Strip tax out of a total — give the after-tax price and the tax rate.", fields: %w[after_tax_price rate] },
      { value: "rate",   label: "Tax rate",         helper: "Find the rate — give the before-tax and after-tax prices.",          fields: %w[before_tax_price after_tax_price] }
    ].freeze

    # The three modes, for the segmented mode picker — a method so the view reaches the constant
    # without qualifying it (templates see the module's methods, not its constants).
    def sales_tax_modes = MODES

    # The rate echoed back, formatted to 4 decimal places half-up (the spec's rate display, §10).
    # The backend already rounds the result's `rate` to 4 dp; this trims it to a clean fixed-4dp
    # string for the result, delimited for large rates. Accepts the BigDecimal off the envelope.
    def sales_tax_rate_display(value)
      number_with_delimiter(format("%.4f", value))
    end

    # The hero answer for the result — the figure the chosen mode SOLVED FOR (the unknown). Each
    # mode's eyebrow + formatted value, so the headline reads as the answer to the question asked:
    #   after  → the after-tax price;  before → the before-tax price;  rate → the tax rate.
    # Returns the eyebrow label and the display string (money prefixed with $, rate suffixed %).
    def sales_tax_hero(calc)
      r = calc.result
      case calc.mode
      when "after"
        { eyebrow: "After-tax price", value: "$#{money_display(r[:after_tax_price])}" }
      when "before"
        { eyebrow: "Before-tax price", value: "$#{money_display(r[:before_tax_price])}" }
      else
        { eyebrow: "Tax rate", value: "#{sales_tax_rate_display(r[:rate])}%" }
      end
    end
  end
end
