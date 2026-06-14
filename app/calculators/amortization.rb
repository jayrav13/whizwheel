module Calculators
  # calculator.net's Amortization page (spec issue #83) — the project's first
  # tabular-output + charts calculator.
  #
  # Given a loan `principal`, an `annual_rate` (percent) and a `years` term, this
  # computes a fixed-payment amortizing loan: the level monthly payment, the totals,
  # and the full month-by-month amortization schedule.
  #
  # Precision/rounding (ARCHITECTURE.md §10): the monthly payment is computed at full
  # BigDecimal precision, then rounded to the cent for display. The schedule is then
  # built from that DISPLAYED (rounded) payment — which is how calculator.net produces
  # rows that reconcile to the penny. The FINAL month sets its principal to the exact
  # remaining balance (rather than `payment − interest`), so the last balance lands on
  # 0.00 and the final payment absorbs the accumulated rounding.
  class Amortization < Base
    CENT = BigDecimal("0.01")
    MONTHS_PER_YEAR = 12
    HUNDRED = BigDecimal(100)
    # Significant digits for the (1+r)^n exponentiation (the only place full-precision
    # power matters). Generous so the raw payment is exact to far past the cent.
    POW_PRECISION = 50

    attribute :principal, :decimal
    attribute :annual_rate, :decimal
    attribute :years, :integer

    validates :principal, presence: true, numericality: { greater_than: 0 }
    validates :annual_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :years, presence: true,
      numericality: { only_integer: true, greater_than: 0 }

    private

    def compute
      payment  = monthly_payment
      schedule = build_schedule(payment)
      total_interest = schedule.sum { |row| row[:interest] }
      total_paid     = schedule.sum { |row| row[:payment] }

      {
        monthly_payment: fmt(payment),
        total_paid: fmt(total_paid),
        total_interest: fmt(total_interest),
        number_of_payments: number_of_payments,
        schedule: schedule.map { |row| row_to_strings(row) },
        chart: chart(total_interest, schedule)
      }
    end

    # Monthly rate r and number of payments n.
    def monthly_rate = annual_rate / HUNDRED / MONTHS_PER_YEAR
    def number_of_payments = years * MONTHS_PER_YEAR

    # Level monthly payment, rounded to the cent for display. The r = 0 edge case
    # (no-interest loan) is the straight P / n; otherwise the standard amortization
    # formula P × r × (1+r)^n / ((1+r)^n − 1).
    def monthly_payment
      n = number_of_payments
      r = monthly_rate
      raw =
        if r.zero?
          principal / n
        else
          growth = (1 + r).power(n, POW_PRECISION)
          principal * r * growth / (growth - 1)
        end
      raw.round(2)
    end

    # Walk the schedule month by month from the DISPLAYED payment. Returns an array
    # of BigDecimal-valued row hashes (stringified later for the envelope).
    def build_schedule(payment)
      r = monthly_rate
      n = number_of_payments
      balance = principal
      schedule = []

      (1..n).each do |month|
        interest = (balance * r).round(2)
        if month < n
          principal_part = payment - interest
          balance -= principal_part
        else
          # Final month: clear the residual exactly so the balance lands on 0.00.
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

    # The chart series the FE renders without doing any math (ARCHITECTURE.md §4):
    # the donut (principal vs. total interest) and the remaining-balance-over-time
    # curve. The curve carries the month-0 starting balance, every yearly sample, and
    # the final month — enough density for the FE to draw it directly.
    def chart(total_interest, schedule)
      {
        principal: fmt(principal),
        total_interest: fmt(total_interest),
        balance_curve: balance_curve(schedule)
      }
    end

    # month 0 (starting balance = principal) + every 12th month. Because the term is
    # always a whole number of years, `n = years × 12` is itself a multiple of 12, so
    # the yearly samples already include the final month (balance 0.00) — no separate
    # endpoint append needed.
    def balance_curve(schedule)
      points = [ { month: 0, balance: fmt(principal) } ]
      schedule.each do |row|
        month = row[:month]
        points << { month: month, balance: fmt(row[:balance]) } if (month % MONTHS_PER_YEAR).zero?
      end
      points
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

    # BigDecimal#to_s("F") drops trailing zeros ("0.0", "599.5"); pad to two dp so
    # every money string is exactly N.NN (the schema's contract).
    def ensure_two_dp(str)
      whole, frac = str.split(".")
      "#{whole}.#{(frac.to_s + '00')[0, 2]}"
    end
  end
end
