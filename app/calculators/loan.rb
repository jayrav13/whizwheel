module Calculators
  # calculator.net's Loan calculator (spec issue #184) — a fixed-rate amortizing
  # loan with a solve-for **mode picker**, generalizing Amortization.
  #
  # The three modes share the amortized-payment identity and differ only in which of
  # {monthly payment, loan amount, term} is the unknown:
  #
  #   - `payment` → solve the level monthly payment from amount + rate + term.
  #   - `amount`  → solve the affordable loan amount from payment + rate + term.
  #   - `term`    → solve the term (whole months, rounded UP) from amount + payment
  #     + rate; requires the payment to exceed the first month's interest (P·r) or
  #     the loan never amortizes.
  #
  # Once P, r, n and the level payment M (rounded to the cent) are known, the schedule
  # is built exactly as Amortization does: month-by-month from the DISPLAYED payment,
  # the final row absorbing accumulated rounding so the balance lands on 0.00. The
  # summary totals are the schedule-reconciled sums (Σ over the rows), not M × n.
  #
  # Precision/rounding (ARCHITECTURE.md §10): full-precision BigDecimal compute; money
  # rounds to the cent half-up; the solved term rounds UP to the next whole month.
  class Loan < Base
    MONTHS_PER_YEAR = 12
    HUNDRED = BigDecimal(100)
    # Significant digits for the (1+r)^n exponentiation (the only place full-precision
    # power matters). Generous so the raw figures are exact far past the cent.
    POW_PRECISION = 50

    MODES = %w[payment amount term].freeze

    attribute :mode, :string
    attribute :loan_amount, :decimal
    attribute :monthly_payment, :decimal
    attribute :annual_rate, :decimal
    attribute :term_months, :integer

    validates :mode, presence: true, inclusion: { in: MODES }
    validates :annual_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :loan_amount, numericality: { greater_than: 0 }, allow_nil: true
    validates :monthly_payment, numericality: { greater_than: 0 }, allow_nil: true
    validates :term_months, numericality: { greater_than: 0 }, allow_nil: true

    # The two of the three loan figures each mode is GIVEN must be present; the field
    # the mode solves for is left blank. (`mode` itself and `annual_rate` are always
    # required and handled above.)
    validate :required_fields_for_mode
    # `term` mode is only solvable when the payment outpaces the first month's
    # interest (M > P·r); otherwise the balance never shrinks.
    validate :payment_amortizes_for_term_mode

    private

    def compute
      p, m, n = solve
      payment_display = m.round(2)
      schedule = build_schedule(p, payment_display, n)
      total_interest = schedule.sum { |row| row[:interest] }
      total_paid     = schedule.sum { |row| row[:payment] }

      {
        mode: mode,
        monthly_payment: fmt(payment_display),
        loan_amount: fmt(p),
        term_months: n,
        total_paid: fmt(total_paid),
        total_interest: fmt(total_interest),
        number_of_payments: n,
        schedule: schedule.map { |row| row_to_strings(row) }
      }
    end

    # Resolve the full [loan_amount P, monthly_payment M, term_months n] triple at full
    # precision, filling in the one figure the chosen mode solves for. M and P stay raw
    # here; the cent-rounding happens in #compute. n is always an Integer.
    def solve
      case mode
      when "payment" then [ loan_amount, raw_payment(loan_amount, term_months), term_months ]
      when "amount"  then [ raw_amount(monthly_payment, term_months), monthly_payment, term_months ]
      else                solve_term
      end
    end

    # payment mode: M = P·r·(1+r)^n / ((1+r)^n − 1); r = 0 edge → P / n.
    def raw_payment(p, n)
      r = monthly_rate
      return p / n if r.zero?

      growth = (1 + r).power(n, POW_PRECISION)
      p * r * growth / (growth - 1)
    end

    # amount mode: P = M·((1+r)^n − 1) / (r·(1+r)^n); r = 0 edge → M · n.
    def raw_amount(m, n)
      r = monthly_rate
      return m * n if r.zero?

      growth = (1 + r).power(n, POW_PRECISION)
      m * (growth - 1) / (r * growth)
    end

    # term mode: n = ln(M / (M − P·r)) / ln(1+r), rounded UP to a whole month; r = 0
    # edge → n = P / M (also rounded up). Then the schedule is recomputed from the
    # integer n with the GIVEN payment. (#payment_amortizes_for_term_mode has already
    # guaranteed M > P·r for r > 0, so the log argument is positive and finite.)
    def solve_term
      p = loan_amount
      m = monthly_payment
      r = monthly_rate
      n =
        if r.zero?
          (p / m).ceil
        else
          ratio = m / (m - p * r)
          (Math.log(ratio) / Math.log(1 + r)).ceil
        end
      [ p, m, n ]
    end

    def monthly_rate = annual_rate / HUNDRED / MONTHS_PER_YEAR

    # Walk the schedule month by month from the DISPLAYED (cent-rounded) payment.
    # Returns an array of BigDecimal-valued row hashes (stringified for the envelope).
    # The final month sets principal to the exact residual so the balance clears to
    # 0.00 and the last payment absorbs accumulated rounding.
    def build_schedule(p, payment, n)
      r = monthly_rate
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

    def required_fields_for_mode
      return unless MODES.include?(mode)

      required_attributes_for(mode).each do |attr|
        errors.add(attr, :blank) if public_send(attr).nil?
      end
    end

    # The two figures the mode is GIVEN (the third is what it solves for).
    def required_attributes_for(selected_mode)
      case selected_mode
      when "payment" then %i[loan_amount term_months]
      when "amount"  then %i[monthly_payment term_months]
      else                %i[loan_amount monthly_payment]
      end
    end

    # Reject a term-mode loan whose payment never amortizes the principal: for r > 0
    # the payment must exceed the first month's interest (M > P·r), else the balance
    # only grows. (r = 0 always amortizes — every payment is pure principal.)
    def payment_amortizes_for_term_mode
      return unless mode == "term"
      return if loan_amount.nil? || monthly_payment.nil?

      r = monthly_rate
      return if r.zero?
      return if monthly_payment > loan_amount * r

      errors.add(:monthly_payment, :too_small_to_amortize,
        message: "is too small to ever repay the loan at this rate")
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
