# Per-calculator helper for the Loan calculator (spec issue #185; split per issue #107).
# Holds the field-label map (single source of truth for error phrasing, DESIGN.md §4) and
# the mode table the page + result render read. Auto-included into views; slug `loan` →
# Calculators::LoanHelper::FIELD_LABELS in field_labels_for.
module Calculators
  module LoanHelper
    # The visible label for each Loan input — what the error phrasing reads back
    # (DESIGN.md §4: "phrase each message against the field's visible label"). `mode` is the
    # picker itself, so its label names the selector, not a field.
    FIELD_LABELS = {
      "mode"            => "Solve for",
      "loan_amount"     => "Loan amount",
      "monthly_payment" => "Monthly payment",
      "annual_rate"     => "Annual interest rate",
      "term_months"     => "Loan term"
    }.freeze

    # The three solve-for modes (DESIGN.md §4 "Mode picker"): a single-select posted as
    # inputs[mode]. Each row names what it SOLVES (the bold label) and, on a helper line, the
    # two figures it is GIVEN. Three multi-word labels → the selectable option list, not a
    # segmented control. Order is fixed so the picker always reads the same.
    MODES = [
      { value: "payment", label: "Monthly payment", helper: "Given the loan amount, rate and term" },
      { value: "amount",  label: "Loan amount",     helper: "Given the monthly payment, rate and term" },
      { value: "term",    label: "Term",            helper: "Given the loan amount, monthly payment and rate" }
    ].freeze

    # The three modes, for the mode picker — a method so the view reaches the constant
    # without qualifying it (templates see the module's methods, not its constants).
    def loan_modes = MODES

    # The hero answer for a solved Loan result (DESIGN.md §4 "Hero-result"): the headline
    # figure is whatever the chosen mode SOLVED FOR. Returns the eyebrow + the value (already
    # a delimited display string) + an optional trailing suffix, keyed off the echoed mode.
    #   • payment → the level monthly payment (money, "/ month").
    #   • amount  → the affordable loan amount (money).
    #   • term    → the term in whole months (count, "months").
    def loan_hero(result)
      case result[:mode]
      when "payment"
        { eyebrow: "Monthly payment", value: "$#{money_display(result[:monthly_payment])}", suffix: "/ month" }
      when "amount"
        { eyebrow: "Loan amount", value: "$#{money_display(result[:loan_amount])}", suffix: nil }
      else
        { eyebrow: "Loan term", value: integer_display(result[:term_months]), suffix: "months" }
      end
    end
  end
end
