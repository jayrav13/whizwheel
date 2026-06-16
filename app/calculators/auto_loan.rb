module Calculators
  # calculator.net's Auto Loan calculator (spec issue #241) — an amortized fixed-rate
  # auto loan built on the **same amortized-payment loan core** as Loan/Amortization,
  # extended with the auto-specific adjustments the calculator.net page folds into the
  # amount financed: a trade-in (which both reduces the cash price AND earns a sales-tax
  # credit), a down payment, sales tax levied on the price net of trade-in, and fixed
  # fees (title / registration / other).
  #
  # It is **single-mode** — it always solves for the level monthly payment. The flow:
  #
  #   sales_tax       = round_to_cent( (auto_price − trade_in) × sales_tax_rate / 100 )
  #   amount_financed = auto_price − down_payment − trade_in + sales_tax + fees   (> 0)
  #
  # then the level monthly payment amortizes `amount_financed` with the Loan/Amortization
  # identity (r > 0 → M = P·r·(1+r)^n / ((1+r)^n − 1); r = 0 → P / n), and the schedule is
  # built month-by-month from the DISPLAYED (cent-rounded) payment exactly as Loan does —
  # the final row absorbing accumulated rounding so the balance clears to 0.00. The
  # summary totals are the schedule-reconciled sums (Σ over the rows), not M × n.
  #
  # Precision/rounding (ARCHITECTURE.md §10): full-precision BigDecimal compute; money
  # rounds to the cent half-up. `sales_tax` is rounded to the cent BEFORE it enters
  # `amount_financed`. The integer term_months is guarded against fractional/non-numeric
  # input by Calculators::Base's numeric guard (no only_integer workaround needed).
  class AutoLoan < Base
    MONTHS_PER_YEAR = 12
    HUNDRED = BigDecimal(100)
    # Significant digits for the (1+r)^n exponentiation (the only place full-precision
    # power matters). Generous so the raw figures are exact far past the cent.
    POW_PRECISION = 50

    attribute :auto_price, :decimal
    attribute :term_months, :integer
    attribute :annual_rate, :decimal
    attribute :down_payment, :decimal, default: 0
    attribute :trade_in, :decimal, default: 0
    attribute :sales_tax_rate, :decimal, default: 0
    attribute :fees, :decimal, default: 0

    validates :auto_price, presence: true, numericality: { greater_than: 0 }
    validates :term_months, presence: true, numericality: { greater_than: 0 }
    validates :annual_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :down_payment, :trade_in, :sales_tax_rate, :fees,
      numericality: { greater_than_or_equal_to: 0 }

    # A trade-in + down payment exceeding the taxed price leaves nothing to finance —
    # the amount financed must be strictly positive or the loan is meaningless.
    validate :amount_financed_positive

    private

    def compute
      financed = amount_financed
      payment_display = raw_payment(financed).round(2)
      schedule = build_schedule(financed, payment_display)
      total_interest = schedule.sum { |row| row[:interest] }
      total_paid     = schedule.sum { |row| row[:payment] }

      {
        amount_financed: fmt(financed),
        sales_tax: fmt(sales_tax),
        monthly_payment: fmt(payment_display),
        total_paid: fmt(total_paid),
        total_interest: fmt(total_interest),
        number_of_payments: term_months,
        schedule: schedule.map { |row| row_to_strings(row) }
      }
    end

    # Sales tax on the price net of trade-in (the trade-in tax credit), rounded to the
    # cent before it rolls into the financed amount.
    def sales_tax
      ((auto_price - trade_in) * sales_tax_rate / HUNDRED).round(2)
    end

    # auto_price − down_payment − trade_in + sales_tax + fees, at full precision
    # (sales_tax is already cent-rounded).
    def amount_financed
      auto_price - down_payment - trade_in + sales_tax + fees
    end

    # The level monthly payment amortizing P: M = P·r·(1+r)^n / ((1+r)^n − 1);
    # r = 0 edge → P / n. (Identical to Loan's payment-mode identity.)
    def raw_payment(p)
      r = monthly_rate
      n = term_months
      return p / n if r.zero?

      growth = (1 + r).power(n, POW_PRECISION)
      p * r * growth / (growth - 1)
    end

    def monthly_rate = annual_rate / HUNDRED / MONTHS_PER_YEAR

    # Walk the schedule month by month from the DISPLAYED (cent-rounded) payment.
    # Returns an array of BigDecimal-valued row hashes. The final month sets principal
    # to the exact residual so the balance clears to 0.00 and the last payment absorbs
    # accumulated rounding. (Identical recurrence to Loan/Amortization.)
    def build_schedule(p, payment)
      r = monthly_rate
      n = term_months
      balance = p
      schedule = []

      (1..n).each do |month|
        interest = (balance * r).round(2)
        if month < n
          principal_part = payment - interest
          balance -= principal_part
        else
          principal_part = balance
          balance = BigDecimal(0)
        end
        schedule << {
          month: month,
          payment: principal_part + interest,
          interest: interest,
          principal: principal_part,
          balance: balance
        }
      end

      schedule
    end

    def amount_financed_positive
      # Only meaningful once the figures it depends on are present and numeric — let the
      # presence / numericality validations own those cases first.
      return unless [ auto_price, down_payment, trade_in, sales_tax_rate, fees ].all?(&:present?)

      return if amount_financed.positive?

      errors.add(:base, "amount financed must be greater than 0")
    end

    # A schedule row as money strings for the JSON envelope.
    def row_to_strings(row)
      {
        month: row[:month],
        payment: fmt(row[:payment]),
        interest: fmt(row[:interest]),
        principal: fmt(row[:principal]),
        balance: fmt(row[:balance])
      }
    end

    # Money string, always two decimal places (half-up to the cent).
    def fmt(value) = value.round(2).to_s("F").then { |s| ensure_two_dp(s) }

    # BigDecimal#to_s("F") drops trailing zeros; pad to exactly N.NN.
    def ensure_two_dp(str)
      whole, frac = str.split(".")
      "#{whole}.#{(frac.to_s + '00')[0, 2]}"
    end
  end
end
