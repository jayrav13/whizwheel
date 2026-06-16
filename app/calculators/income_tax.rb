module Calculators
  # calculator.net's Income Tax page (spec issue #250) — iteration-0007's one
  # deliberate new primitive: PROGRESSIVE BRACKET / PIECEWISE math.
  #
  # Given a taxable income (entered directly, or derived from gross_income −
  # deductions), this applies the pinned 2025 US federal single-filer ordinary-income
  # tax brackets (IRS Rev. Proc. 2024-40) and returns the total tax, the per-bracket
  # breakdown (the tabular-output), the after-tax income, and the effective + marginal
  # rates.
  #
  # ## The primitive — marginal-bracket sum (the brackets are DATA, not a polynomial)
  #
  # Each bracket taxes ONLY the slice of taxable income that falls within its
  # [lower, upper) range (upper-exclusive / lower-inclusive). We iterate the schedule
  # below, and for each bracket the income reaches add `(min(income, upper) − lower) ×
  # rate` to the running total — computed at full BigDecimal precision, rounded to the
  # cent only for display (§10). The schedule is the single source of truth: to change
  # the law you edit BRACKETS, never the arithmetic.
  #
  # ## Input resolution
  #
  # `taxable_income` may be entered directly (the simplest path, which the spec's
  # reference values pin), OR derived from `gross_income − deductions` (floored at 0).
  # If `taxable_income` is given it wins; otherwise `gross_income` is required and
  # `taxable_income = max(0, gross_income − deductions)`. At least one of the two must
  # be present — enforced as a validation (422, never an exception).
  #
  # Precision/rounding (§10): money → 2 dp half-up; rates → 4 dp half-up. total_tax is
  # summed from the un-rounded per-bracket products, then rounded for display, so it
  # reproduces the pinned reference values to the cent.
  class IncomeTax < Base
    HUNDRED = BigDecimal(100)
    MONEY_DP = 2
    RATE_DP = 4

    # The pinned 2025 US federal single-filer ordinary-income brackets (Rev. Proc.
    # 2024-40). `upper: nil` is the unbounded top bracket. Rates are whole-percent
    # integers; the math divides by 100. Ordered low → high; edges are
    # lower-inclusive / upper-exclusive.
    BRACKETS = [
      { rate: 10, lower: BigDecimal(0),      upper: BigDecimal(11_925) },
      { rate: 12, lower: BigDecimal(11_925), upper: BigDecimal(48_475) },
      { rate: 22, lower: BigDecimal(48_475), upper: BigDecimal(103_350) },
      { rate: 24, lower: BigDecimal(103_350), upper: BigDecimal(197_300) },
      { rate: 32, lower: BigDecimal(197_300), upper: BigDecimal(250_525) },
      { rate: 35, lower: BigDecimal(250_525), upper: BigDecimal(626_350) },
      { rate: 37, lower: BigDecimal(626_350), upper: nil }
    ].freeze

    attribute :gross_income, :decimal
    attribute :deductions, :decimal, default: 0
    attribute :taxable_income, :decimal

    validates :gross_income, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :deductions, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :taxable_income, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    validate :income_source_present

    private

    # At least one of `taxable_income` / `gross_income` must be supplied — the
    # calculator has nothing to compute on otherwise.
    def income_source_present
      return if taxable_income.present? || gross_income.present?

      errors.add(:taxable_income, :blank)
    end

    def compute
      income = resolved_taxable_income
      rows   = bracket_rows(income)
      total  = rows.sum(BigDecimal(0)) { |r| r[:tax] }

      {
        taxable_income: money(income),
        total_tax: money(total),
        after_tax_income: money(income - total),
        effective_rate: rate(effective_rate(income, total)),
        marginal_rate: marginal_rate(income).to_s,
        brackets: rows.map { |r| row_to_strings(r) }
      }
    end

    # The income the tax is computed on: the directly-entered taxable_income when
    # present, else max(0, gross_income − deductions). `deductions` defaults to 0
    # (Base coerces a blank to the default), so the subtraction is always defined.
    def resolved_taxable_income
      return taxable_income if taxable_income.present?

      derived = gross_income - deductions
      derived.negative? ? BigDecimal(0) : derived
    end

    # The marginal-bracket sum — the primitive. One row per bracket the income
    # REACHES (lower < income); rows below the marginal bracket are full, the marginal
    # row is partial, brackets above are omitted. Each row's tax is the un-rounded
    # product (rounding happens only at display) so Σ tax reconciles to total_tax.
    def bracket_rows(income)
      BRACKETS.each_with_object([]) do |bracket, rows|
        break rows if income <= bracket[:lower]

        upper = bracket[:upper]
        ceiling = upper.nil? ? income : [ income, upper ].min
        taxed = ceiling - bracket[:lower]
        rate = BigDecimal(bracket[:rate])

        rows << {
          rate: rate,
          lower: bracket[:lower],
          upper: upper,
          taxable_in_bracket: taxed,
          tax: taxed * rate / HUNDRED
        }
      end
    end

    # effective_rate = total_tax / taxable_income × 100, or 0 when income is 0 (no
    # division by zero — a zero-income filer owes nothing at a 0% effective rate).
    def effective_rate(income, total)
      return BigDecimal(0) if income.zero?

      total / income * HUNDRED
    end

    # The rate (whole-percent integer) of the highest bracket whose lower < income —
    # the band the last dollar lands in. At an exact edge the lower bracket has been
    # fully filled and the next not entered, so its rate is the lower bracket's (the
    # `<` comparison handles this). 0 when no bracket is reached (income 0).
    def marginal_rate(income)
      reached = BRACKETS.select { |b| b[:lower] < income }
      reached.empty? ? 0 : reached.last[:rate]
    end

    # A bracket row as the §4 schema: rates/money as strings, the top bracket's upper
    # null (unbounded).
    def row_to_strings(row)
      {
        rate: row[:rate].to_i.to_s,
        lower: money(row[:lower]),
        upper: row[:upper].nil? ? nil : money(row[:upper]),
        taxable_in_bracket: money(row[:taxable_in_bracket]),
        tax: money(row[:tax])
      }
    end

    # Money string, always exactly two decimal places (half-up to the cent).
    def money(value)
      whole, frac = value.round(MONEY_DP, BigDecimal::ROUND_HALF_UP).to_s("F").split(".")
      "#{whole}.#{(frac.to_s + '00')[0, MONEY_DP]}"
    end

    # Rate string, exactly four decimal places (half-up).
    def rate(value)
      whole, frac = value.round(RATE_DP, BigDecimal::ROUND_HALF_UP).to_s("F").split(".")
      "#{whole}.#{(frac.to_s + '0000')[0, RATE_DP]}"
    end
  end
end
