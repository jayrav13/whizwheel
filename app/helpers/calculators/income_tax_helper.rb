# Per-calculator helper for the Income Tax calculator (spec issue #260; split per issue
# #107). Holds the field-label map (single source of truth for error phrasing, DESIGN.md
# §4) and the income-mode table the page reads. Auto-included into views; slug `income_tax`
# → Calculators::IncomeTaxHelper::FIELD_LABELS in field_labels_for.
module Calculators
  module IncomeTaxHelper
    # The visible label for each Income Tax input — what the error phrasing reads back
    # (DESIGN.md §4: "phrase each message against the field's visible label"). `taxable_income`
    # is the field the spec's :blank validation lands on when neither income source is given,
    # so its label must read sensibly as a whole-form requirement; the message itself
    # ("can't be blank") still pairs with the field label.
    FIELD_LABELS = {
      "taxable_income" => "Taxable income",
      "gross_income"   => "Gross income",
      "deductions"     => "Deductions"
    }.freeze

    # The two income-entry modes (DESIGN.md §4 "Mode picker"). The backend resolves the
    # taxable income from EITHER a directly-entered `taxable_income` OR `gross_income −
    # deductions` (taxable_income wins if present). The frontend turns that either/or into a
    # picker: a native radio <fieldset>/<legend> posting a single-select inputs[mode]. The
    # backend ignores the `mode` key (it isn't a declared attribute), so `mode` is purely a
    # frontend convenience for WHICH fields to show and post — the Stimulus controller
    # disables the inactive mode's inputs so only one income source is ever sent. Both labels
    # read as multi-word, so per the §4 rule (N ≥ 4 OR any multi-word label) the picker is the
    # selectable option list (.mode-option), not a segmented control. Order is fixed.
    MODES = [
      { value: "taxable", label: "Taxable income",      helper: "Enter your taxable income directly",        field: "taxable" },
      { value: "gross",   label: "Gross income & deductions", helper: "We subtract deductions to find it",   field: "gross"   }
    ].freeze

    # The two income modes, for the mode picker — a method so the view reaches the constant
    # without qualifying it (templates see the module's methods, not its constants).
    def income_tax_modes = MODES

    # The per-bracket breakdown rows from the solved calculator's envelope (ARCHITECTURE.md
    # §4 — the `brackets` tabular-output). Each row is a string Hash with rate/lower/upper/
    # taxable_in_bracket/tax (the top bracket's `upper` is nil → unbounded). Returned verbatim;
    # the result partial renders the data table.
    def income_tax_brackets(calc) = calc.result[:brackets]

    # A row's taxed range as a display string for the breakdown table's "Range" column. The
    # lower bound and (when present) the upper bound, money-delimited; the unbounded top
    # bracket reads "$626,350 and up". Whole-dollar (no cents) — bracket edges are round
    # thousands and read cleaner without ".00". Accepts a row with either symbol keys (the raw
    # `compute` hash a view renders) or string keys (a JSON round-trip), so the partial and a
    # parsed-envelope caller both work.
    def income_tax_bracket_range(row)
      lower = income_tax_whole_dollars(row[:lower] || row["lower"])
      upper = row[:upper] || row["upper"]
      return "$#{lower} and up" if upper.nil?

      "$#{lower} – $#{income_tax_whole_dollars(upper)}"
    end

    private

    # A money string ("103350.00") as whole delimited dollars ("103,350") — bracket edges are
    # exact thousands, so the cents are noise in the range column. Drops the fractional part and
    # delimits the whole part.
    def income_tax_whole_dollars(money_string)
      number_with_delimiter(money_string.split(".").first)
    end
  end
end
