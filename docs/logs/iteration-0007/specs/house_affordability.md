<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/house-affordability-calculator.html
**Complexity:** 4
**Tags:** multi-input
**Card description:** How much house can you afford — from your income, debts, down payment, and DTI limits, get the maximum monthly payment, loan amount, and home price.

## Intent
A **house affordability** calculator: runs the mortgage math **in reverse**. Instead of a home price → a
payment, it takes your **income**, **recurring monthly debts**, **down payment**, **rate/term**, and the
lender's **debt-to-income (DTI) ratios**, derives the **maximum monthly housing payment** you can support,
then inverts the amortization formula to get the **maximum loan amount** and **maximum home price**. It is
the mortgage calculator's amortization identity solved for principal given a payment ceiling.

### Formula (authoritative — confirmed against the Source's DTI method)
The DTI ratios cap the monthly housing payment two ways; the **binding** (smaller) cap wins:
```
gross_monthly_income = annual_income / 12

front_end_cap = gross_monthly_income × front_dti / 100               # housing alone
back_end_cap  = gross_monthly_income × back_dti  / 100 − monthly_debts  # housing + other debts
max_monthly_housing = min(front_end_cap, back_end_cap)
```
The housing payment includes the recurring ownership costs (entered as **fixed monthly** figures), so
back out P&I:
```
max_pi = max_monthly_housing − monthly_property_tax − monthly_home_insurance − monthly_hoa
```
Invert the amortized-payment identity (the same core as Mortgage/Loan) to get the loan principal that
`max_pi` supports, then add the down payment:
```
r = annual_rate / 100 / 12
n = loan_term_years × 12
max_loan_amount = max_pi × ((1+r)^n − 1) / (r · (1+r)^n)     # r > 0
max_loan_amount = max_pi × n                                  # r = 0 edge
max_home_price  = max_loan_amount + down_payment
```

> **Non-iterative model (deliberate):** property tax / insurance / HOA are entered as **fixed monthly
> dollar figures** (exactly how the Source treats insurance and HOA in its worked example), so the maximum
> price computes in **one pass** — no iterating tax-as-a-%-of-the-as-yet-unknown-price. This keeps the
> reference values deterministic and the math a clean mortgage-in-reverse, the way the iteration scopes it.

## Inputs
| name                  | type    | rules                                                                |
|-----------------------|---------|----------------------------------------------------------------------|
| annual_income         | decimal | presence, numericality (greater than 0)                              |
| monthly_debts         | decimal | numericality (greater than or equal to 0); optional, default 0       |
| down_payment          | decimal | numericality (greater than or equal to 0); optional, default 0       |
| annual_rate           | decimal | presence, numericality (greater than or equal to 0)                  |
| loan_term_years       | integer | presence, numericality (greater than 0)                              |
| front_dti             | decimal | presence, numericality (greater than 0, less than or equal to 100)   |
| back_dti              | decimal | presence, numericality (greater than 0, less than or equal to 100)   |
| monthly_property_tax  | decimal | numericality (greater than or equal to 0); optional, default 0       |
| monthly_home_insurance| decimal | numericality (greater than or equal to 0); optional, default 0       |
| monthly_hoa           | decimal | numericality (greater than or equal to 0); optional, default 0       |

_Validation: the resulting `max_pi` must be `> 0` (if monthly debts + tax/ins/HOA already exhaust the DTI
ceiling, no home is affordable) — reject otherwise. Defaults: a conventional **28 / 36** is a natural pair
but the values are entered, not hard-coded._

## Outputs
| key                  | meaning                                                                |
|----------------------|------------------------------------------------------------------------|
| gross_monthly_income | annual_income / 12, money string                                       |
| max_monthly_housing  | the binding DTI cap on the housing payment = min(front, back), money    |
| max_pi               | max_monthly_housing − tax − insurance − hoa (principal & interest room) |
| max_loan_amount      | the loan principal max_pi supports over the term, money string          |
| max_home_price       | max_loan_amount + down_payment, money string                            |

## Reference values
_PM-computed at full `BigDecimal` precision; the backend agent must reproduce them exactly. Money rounds to
the cent half-up._

| annual_income | monthly_debts | down_payment | annual_rate | loan_term_years | front_dti | back_dti | monthly_property_tax | monthly_home_insurance | monthly_hoa | gross_monthly_income | max_monthly_housing | max_pi  | max_loan_amount | max_home_price |
|---------------|---------------|--------------|-------------|-----------------|-----------|----------|----------------------|------------------------|-------------|----------------------|---------------------|---------|-----------------|----------------|
| 120000        | 500           | 60000        | 6           | 30              | 28        | 36       | 250                  | 100                    | 0           | 10000.00             | 2800.00             | 2450.00 | 408639.46       | 468639.46      |
| 90000         | 300           | 40000        | 7           | 30              | 28        | 36       | 200                  | 80                     | 0           | 7500.00              | 2100.00             | 1820.00 | 273559.77       | 313559.77      |

_Worked anchor (row 1, `income 120000, debts 500, down 60000, 6%/30y, 28/36 DTI, tax 250, ins 100, hoa 0`):
gross_monthly_income = 120000/12 = **10000.00**; front_end_cap = 10000 × 28/100 = **2800.00**; back_end_cap
= 10000 × 36/100 − 500 = 3600 − 500 = **3100.00**; max_monthly_housing = min(2800, 3100) = **2800.00**
(front-end binds); max_pi = 2800 − 250 − 100 − 0 = **2450.00**; r = 0.06/12 = 0.005, n = 360 → max_loan =
2450 × ((1.005^360 − 1)/(0.005 × 1.005^360)) = **408639.46**; max_home_price = 408639.46 + 60000 =
**468639.46**._

### Edge / validation cases
| inputs | expected |
|--------|----------|
| annual_income = 0 | invalid (greater than 0) |
| loan_term_years = 0 | invalid (greater than 0) |
| loan_term_years = 29.5 | invalid (fractional integer — Base numeric guard rejects) |
| front_dti = 0 | invalid (greater than 0) |
| back_dti = 150 | invalid (≤ 100) |
| debts/tax/ins/hoa exhaust DTI (e.g. income 30000, debts 2000, 28/36, tax 800, ins 200) → max_pi ≤ 0 | invalid (no home affordable at these constraints) |
| annual_rate = "x" | invalid (Base numeric guard rejects non-numeric) |

## Notes
- **Reuse the Mortgage/Loan amortized core, inverted** — `max_loan_amount` from `max_pi` is the same
  amortized-payment identity solved for principal (the inverse of Loan's `payment` mode, identical to
  Loan's `amount` mode). Build it on that primitive; House Affordability sequences **after Auto Loan** so
  the loan core is re-established at this iteration's pinned agents first.
- **No mode picker** — single computation. The DTI ratios are ordinary numeric inputs (a future variant
  could offer named DTI presets — conventional 28/36, FHA 31/43 — as a picker, but this spec takes them as
  entered values to keep the reference math deterministic).
- **Stat-grid output:** the five output figures render in the shared **`.stat-grid`** component
  (`DESIGN.md §4`). The home-price / loan-amount figures are **7-digit money**, so use the **`.stat-grid--wide`**
  modifier (13rem track) per the §4 selection criteria, not the default 9.5rem.
- Rounding/display: full-precision `BigDecimal`; the loan-amount inversion uses the same `(1+r)^n` term as
  Mortgage; money → 2 dp half-up (§10).
- `:integer` `loan_term_years` — the `Calculators::Base` numeric guard rejects non-numeric / fractional
  input at the cast seam, so **no `only_integer` workaround is needed**.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
