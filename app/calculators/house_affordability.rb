module Calculators
  # calculator.net's House Affordability page (spec issue #249) — the mortgage math
  # run IN REVERSE. Instead of a home price → a monthly payment, it takes income,
  # recurring monthly debts, a down payment, rate/term and the lender's debt-to-income
  # (DTI) ratios, derives the maximum monthly housing payment the income supports, then
  # inverts the amortized-payment identity to recover the maximum loan principal and
  # maximum home price.
  #
  # The DTI ratios cap the housing payment two ways and the BINDING (smaller) cap wins:
  #   front_end_cap = gross_monthly_income × front_dti / 100               (housing alone)
  #   back_end_cap  = gross_monthly_income × back_dti  / 100 − monthly_debts (housing + debts)
  #   max_monthly_housing = min(front_end_cap, back_end_cap)
  #
  # The housing payment includes the recurring ownership costs (entered here as FIXED
  # MONTHLY dollar figures — the deliberate non-iterative model, so the price computes
  # in one pass), so back out principal & interest then invert amortization:
  #   max_pi          = max_monthly_housing − tax − insurance − hoa
  #   max_loan_amount = max_pi × ((1+r)^n − 1) / (r·(1+r)^n)   (r > 0; = max_pi × n at r = 0)
  #   max_home_price  = max_loan_amount + down_payment
  #
  # This `max_loan_amount = payment × ((1+r)^n − 1)/(r·(1+r)^n)` is the same amortized
  # core as Mortgage/Loan, solved for principal instead of payment.
  #
  # Precision/rounding (ARCHITECTURE.md §10): all math is full-precision BigDecimal; the
  # (1+r)^n term uses the same generous exponentiation precision as Mortgage; the five
  # output figures are rounded to the cent half-up for display.
  class HouseAffordability < Base
    MONTHS_PER_YEAR = 12
    HUNDRED = BigDecimal(100)
    # Significant digits for the (1+r)^n exponentiation — generous so the inverted
    # loan principal is exact to far past the cent.
    POW_PRECISION = 50

    attribute :annual_income, :decimal
    attribute :monthly_debts, :decimal, default: 0
    attribute :down_payment, :decimal, default: 0
    attribute :annual_rate, :decimal
    attribute :loan_term_years, :integer
    attribute :front_dti, :decimal
    attribute :back_dti, :decimal
    attribute :monthly_property_tax, :decimal, default: 0
    attribute :monthly_home_insurance, :decimal, default: 0
    attribute :monthly_hoa, :decimal, default: 0

    validates :annual_income, presence: true, numericality: { greater_than: 0 }
    validates :monthly_debts, numericality: { greater_than_or_equal_to: 0 }
    validates :down_payment, numericality: { greater_than_or_equal_to: 0 }
    validates :annual_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
    # `loan_term_years` is an :integer attribute; the spec's whole-number intent is
    # enforced by Base's coercion guard (#109) — a fractional raw value is rejected
    # before validation, never truncated — so `only_integer` here would be an
    # unreachable branch. We keep just `greater_than: 0`.
    validates :loan_term_years, presence: true, numericality: { greater_than: 0 }
    validates :front_dti, presence: true,
                          numericality: { greater_than: 0, less_than_or_equal_to: 100 }
    validates :back_dti, presence: true,
                         numericality: { greater_than: 0, less_than_or_equal_to: 100 }
    validates :monthly_property_tax, numericality: { greater_than_or_equal_to: 0 }
    validates :monthly_home_insurance, numericality: { greater_than_or_equal_to: 0 }
    validates :monthly_hoa, numericality: { greater_than_or_equal_to: 0 }

    # If recurring debts + tax/insurance/HOA already exhaust the DTI ceiling, there is
    # no principal-and-interest room left and no home is affordable — reject.
    validate :affordable_pi_room

    private

    def compute
      pi = max_pi

      {
        gross_monthly_income: fmt(gross_monthly_income),
        max_monthly_housing: fmt(max_monthly_housing),
        max_pi: fmt(pi),
        max_loan_amount: fmt(max_loan_amount),
        max_home_price: fmt(max_home_price)
      }
    end

    def gross_monthly_income = annual_income / MONTHS_PER_YEAR

    # The binding DTI cap on the monthly housing payment: the smaller of the front-end
    # (housing alone) and back-end (housing + other debts) ceilings.
    def max_monthly_housing
      front = gross_monthly_income * front_dti / HUNDRED
      back  = gross_monthly_income * back_dti / HUNDRED - monthly_debts
      [ front, back ].min
    end

    # The principal & interest room: housing cap less the fixed monthly ownership costs.
    def max_pi
      max_monthly_housing - monthly_property_tax - monthly_home_insurance - monthly_hoa
    end

    def monthly_rate = annual_rate / HUNDRED / MONTHS_PER_YEAR
    def number_of_payments = loan_term_years * MONTHS_PER_YEAR

    # Invert the amortized-payment identity: the loan principal that `max_pi` supports
    # over the term. The r = 0 edge (no-interest loan) is the straight max_pi × n;
    # otherwise principal = payment × ((1+r)^n − 1) / (r·(1+r)^n).
    def max_loan_amount
      n = number_of_payments
      r = monthly_rate
      if r.zero?
        max_pi * n
      else
        growth = (1 + r).power(n, POW_PRECISION)
        max_pi * (growth - 1) / (r * growth)
      end
    end

    def max_home_price = max_loan_amount + down_payment

    # Guard the inversion: the housing payment must leave positive P&I room, else the
    # constraints admit no affordable home (and dividing-back a non-positive payment is
    # meaningless). Skip while any input the computation depends on is still invalid, so
    # the field-level errors own those messages.
    def affordable_pi_room
      return if [ annual_income, front_dti, back_dti, monthly_debts,
                 monthly_property_tax, monthly_home_insurance, monthly_hoa ].any?(&:blank?)
      return if max_pi > 0

      errors.add(:base, "No home is affordable at these income, debt, and DTI constraints")
    end

    # Money string, always two decimal places (half-up to the cent).
    def fmt(value) = value.round(2).to_s("F").then { |s| ensure_two_dp(s) }

    # BigDecimal#to_s("F") drops trailing zeros ("0.0", "2800.5"); pad to two dp so
    # every money string is exactly N.NN.
    def ensure_two_dp(str)
      whole, frac = str.split(".")
      "#{whole}.#{(frac.to_s + '00')[0, 2]}"
    end
  end
end
