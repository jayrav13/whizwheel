module Calculators
  # calculator.net's Mortgage page (spec issue #186) — a fixed-rate home mortgage
  # built on the same amortized-payment primitive as the Loan/Amortization calculator,
  # extended with the recurring ownership costs the mortgage page rolls into the
  # monthly payment: property tax, home insurance and HOA fee.
  #
  # It computes the principal-and-interest (P&I) payment, the total monthly payment
  # (P&I + tax + insurance + HOA), the loan totals over the term, the full P&I
  # amortization schedule, and a `chart` envelope key carrying the payment-component
  # donut + the balance-over-time curve so the FE draws both without doing math.
  #
  # Precision/rounding (ARCHITECTURE.md §10): the P&I payment is computed at full
  # BigDecimal precision then rounded to the cent for display; the schedule is built
  # from that DISPLAYED payment so rows reconcile to the penny, and the FINAL month
  # sets its principal to the exact remaining balance so the last balance lands on
  # 0.00 and the final payment absorbs the accumulated rounding. The annual tax and
  # insurance figures are divided by 12 then rounded to the cent for display; HOA is
  # already a monthly figure.
  class Mortgage < Base
    MONTHS_PER_YEAR = 12
    HUNDRED = BigDecimal(100)
    # Significant digits for the (1+r)^n exponentiation — generous so the raw P&I
    # payment is exact to far past the cent.
    POW_PRECISION = 50

    attribute :home_price, :decimal
    attribute :down_payment, :decimal
    attribute :annual_rate, :decimal
    attribute :loan_term_years, :integer
    attribute :annual_property_tax, :decimal, default: 0
    attribute :annual_home_insurance, :decimal, default: 0
    attribute :monthly_hoa, :decimal, default: 0

    validates :home_price, presence: true, numericality: { greater_than: 0 }
    validates :down_payment, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :annual_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
    # `loan_term_years` is an :integer attribute; the spec's "only integer" intent is
    # enforced by Base's coercion guard (#109) — a fractional raw value is rejected
    # before validation, never truncated — so `only_integer` here would be an
    # unreachable branch. We keep just `greater_than: 0`.
    validates :loan_term_years, presence: true, numericality: { greater_than: 0 }
    validates :annual_property_tax, numericality: { greater_than_or_equal_to: 0 }
    validates :annual_home_insurance, numericality: { greater_than_or_equal_to: 0 }
    validates :monthly_hoa, numericality: { greater_than_or_equal_to: 0 }

    # The loan amount must be positive — the down payment cannot equal or exceed the
    # home price (a fully-cash purchase has no loan to amortize).
    validate :down_payment_below_home_price

    private

    def compute
      pi = pi_monthly
      schedule = build_schedule(pi)
      total_interest = schedule.sum { |row| row[:interest] }
      total_of_pi    = schedule.sum { |row| row[:payment] }

      tax = (annual_property_tax / MONTHS_PER_YEAR).round(2)
      insurance = (annual_home_insurance / MONTHS_PER_YEAR).round(2)
      hoa = monthly_hoa.round(2)
      total_monthly = pi + tax + insurance + hoa

      {
        loan_amount: fmt(loan_amount),
        pi_monthly: fmt(pi),
        tax_monthly: fmt(tax),
        insurance_monthly: fmt(insurance),
        hoa_monthly: fmt(hoa),
        total_monthly: fmt(total_monthly),
        total_interest: fmt(total_interest),
        total_of_pi: fmt(total_of_pi),
        number_of_payments: number_of_payments,
        schedule: schedule.map { |row| row_to_strings(row) },
        chart: chart(pi, tax, insurance, hoa, schedule)
      }
    end

    # The amount financed: home price minus the down payment.
    def loan_amount = home_price - down_payment

    def monthly_rate = annual_rate / HUNDRED / MONTHS_PER_YEAR
    def number_of_payments = loan_term_years * MONTHS_PER_YEAR

    # Principal & interest payment, rounded to the cent for display. The r = 0 edge
    # (no-interest loan) is the straight loan_amount / n; otherwise the standard
    # amortization formula loan_amount × r × (1+r)^n / ((1+r)^n − 1).
    def pi_monthly
      n = number_of_payments
      r = monthly_rate
      raw =
        if r.zero?
          loan_amount / n
        else
          growth = (1 + r).power(n, POW_PRECISION)
          loan_amount * r * growth / (growth - 1)
        end
      raw.round(2)
    end

    # Walk the P&I schedule month by month from the DISPLAYED payment (tax/insurance/
    # HOA do not amortize the loan). Returns an array of BigDecimal-valued row hashes.
    def build_schedule(payment)
      r = monthly_rate
      n = number_of_payments
      balance = loan_amount
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

    # The chart series the FE renders without any math (ARCHITECTURE.md §4): the
    # monthly-payment-component donut (P&I vs. tax vs. insurance vs. HOA) and the
    # remaining-balance-over-time curve.
    def chart(pi, tax, insurance, hoa, schedule)
      {
        payment_components: [
          { label: "Principal & interest", amount: fmt(pi) },
          { label: "Property tax",         amount: fmt(tax) },
          { label: "Home insurance",       amount: fmt(insurance) },
          { label: "HOA",                  amount: fmt(hoa) }
        ],
        balance_curve: balance_curve(schedule)
      }
    end

    # month 0 (starting balance = loan_amount) + every 12th month. Because the term is
    # always a whole number of years, n = loan_term_years × 12 is itself a multiple of
    # 12, so the yearly samples already include the final month (balance 0.00).
    def balance_curve(schedule)
      points = [ { month: 0, balance: fmt(loan_amount) } ]
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

    def down_payment_below_home_price
      return if home_price.blank? || down_payment.blank?
      return if down_payment < home_price

      errors.add(:down_payment, :less_than, count: home_price, message: "must be less than the home price")
    end
  end
end
