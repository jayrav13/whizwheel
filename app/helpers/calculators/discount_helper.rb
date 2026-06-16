# Per-calculator helper for the Discount calculator (spec issue #254; split per issue #107).
# Holds the field-label map (single source of truth for error phrasing, DESIGN.md §4) and the
# mode table the page reads. Auto-included into views; slug `discount` →
# Calculators::DiscountHelper::FIELD_LABELS in field_labels_for.
module Calculators
  module DiscountHelper
    # The visible label for each Discount input — what the error phrasing reads back
    # (DESIGN.md §4: "phrase each message against the field's visible label"). `mode` is the
    # picker itself, so its label names the selector, not a field.
    FIELD_LABELS = {
      "mode"           => "Discount type",
      "original_price" => "Original price",
      "percent_off"    => "Percent off",
      "amount_off"     => "Amount off"
    }.freeze

    # The two discount modes (DESIGN.md §4 "Mode picker"): a single-select posted as
    # inputs[mode]. Both labels read as multi-word ("Percent off" / "Fixed amount off"), so per
    # the §4 rule (N ≥ 4 OR any multi-word label) the picker is the selectable option list
    # (.mode-option), not a segmented control. Each row names HOW the discount is expressed (the
    # bold label) and, on a helper line, the one field it uses. Order is fixed so the picker
    # always reads the same. `field` is the input block the mode reveals.
    MODES = [
      { value: "percent", label: "Percent off",       helper: "Take a percentage off the price",  field: "percent" },
      { value: "fixed",   label: "Fixed amount off",  helper: "Take a fixed dollar amount off",   field: "amount"  }
    ].freeze

    # The two modes, for the mode picker — a method so the view reaches the constant without
    # qualifying it (templates see the module's methods, not its constants).
    def discount_modes = MODES

    # A short human sentence describing the discount that was applied, shown under the hero
    # final price so the answer reads in context. Reads the echoed mode + the figures off the
    # solved calculator. `percent` → "10% off $45.00"; `fixed` → "$15.00 off $80.00".
    def discount_detail(calc)
      price = money_display(calc.result[:original_price])
      if calc.mode == "percent"
        "#{percentage_display(calc.percent_off)}% off $#{price}"
      else
        "$#{money_display(calc.result[:amount_saved])} off $#{price}"
      end
    end
  end
end
