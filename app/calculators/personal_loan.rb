module Calculators
  # calculator.net's Personal Loan calculator (spec issue #246) — the plain loan-core
  # skin of the loan cluster. A straightforward fixed-rate **amortizing personal loan**:
  # given a loan amount, an annual rate, and a term in months, solve the level monthly
  # payment, the loan totals, and the full month-by-month repayment schedule.
  #
  # It is the **single-mode** member of the cluster — always solves for the payment, with
  # no auto/mortgage add-ons and no mode picker. It reuses the *same* amortized-payment
  # identity and schedule recurrence as the Loan calculator's `payment` mode (the loan
  # core); the personal-loan specifics are simply "no extra fields, no mode picker".
  #
  #   M = P · r · (1+r)^n / ((1+r)^n − 1)     # r > 0  (the amortized-payment identity)
  #   M = P / n                                # r = 0 edge
  #
  # Once P, r, n and the level payment M (rounded to the cent) are known, the schedule is
  # built month-by-month from the DISPLAYED payment, the final row absorbing accumulated
  # rounding so the balance lands exactly on 0.00. The summary totals are the schedule-
  # reconciled sums (Σ over the rows), not M × n.
  #
  # Precision/rounding (ARCHITECTURE.md §10): full-precision BigDecimal compute; money
  # rounds to the cent half-up. The `:integer` term_months is guarded against non-numeric
  # / fractional input by Calculators::Base's numeric coercion guard at the cast seam, so
  # no `only_integer` workaround is needed here.
  class PersonalLoan < Base
    MONTHS_PER_YEAR = 12
    HUNDRED = BigDecimal(100)
    # Significant digits for the (1+r)^n exponentiation — the only place full-precision
    # power matters. Generous so the raw payment is exact far past the cent.
    POW_PRECISION = 50

    attribute :loan_amount, :decimal
    attribute :annual_rate, :decimal
    attribute :term_months, :integer

    validates :loan_amount, presence: true, numericality: { greater_than: 0 }
    validates :annual_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :term_months, presence: true, numericality: { greater_than: 0 }

    private

    def compute
      payment_display = raw_payment.round(2)
      schedule = build_schedule(payment_display)
      total_interest = schedule.sum { |row| row[:interest] }
      total_paid     = schedule.sum { |row| row[:payment] }

      {
        loan_amount: fmt(loan_amount),
        monthly_payment: fmt(payment_display),
        total_paid: fmt(total_paid),
        total_interest: fmt(total_interest),
        number_of_payments: term_months,
        schedule: schedule.map { |row| row_to_strings(row) }
      }
    end

    # The level monthly payment at full precision:
    #   M = P·r·(1+r)^n / ((1+r)^n − 1); r = 0 edge → P / n.
    def raw_payment
      r = monthly_rate
      return loan_amount / term_months if r.zero?

      growth = (1 + r).power(term_months, POW_PRECISION)
      loan_amount * r * growth / (growth - 1)
    end

    def monthly_rate = annual_rate / HUNDRED / MONTHS_PER_YEAR

    # Walk the schedule month by month from the DISPLAYED (cent-rounded) payment.
    # Returns an array of BigDecimal-valued row hashes. The final month sets principal
    # to the exact residual so the balance clears to 0.00 and the last payment absorbs
    # accumulated rounding.
    def build_schedule(payment)
      r = monthly_rate
      balance = loan_amount
      n = term_months
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
