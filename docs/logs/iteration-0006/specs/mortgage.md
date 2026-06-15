<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/mortgage-calculator.html
**Complexity:** 5
**Tags:** multi-input, tabular-output, charts
**Card description:** A full home-mortgage estimate — principal & interest plus property tax, insurance and HOA — with the monthly payment breakdown, total cost, and amortization schedule.

## Intent
A fixed-rate **home mortgage**, built on the same amortized-payment primitive as the Loan calculator
but extended with the **recurring ownership costs** calculator.net's mortgage page rolls into the
monthly payment: **property tax**, **home insurance**, and **HOA fee**. It computes the
**principal-and-interest (P&I)** payment, the **total monthly payment** (P&I + tax + insurance + HOA),
the loan totals over the term, and the full amortization schedule — plus a `chart` envelope key so
the FE can draw the **monthly-payment-component donut** (P&I vs. tax vs. insurance vs. HOA) and the
**balance-over-time curve** without doing math.

This is the project's first calculator combining **tabular-output + charts + a multi-component
payment breakdown**, and the second member of the loan cluster (it inherits Loan's amortized core).

### Formula (authoritative)
The loan amount is the **home price minus the down payment**:
```
loan_amount = home_price − down_payment
r = annual_rate / 100 / 12          # monthly rate
n = loan_term_years × 12            # number of months
```
**Principal & interest** (the amortized payment), as in Loan/Amortization:
```
pi_monthly = loan_amount · r · (1+r)^n / ((1+r)^n − 1)     # r > 0
pi_monthly = loan_amount / n                                # r = 0 edge
```
**Recurring monthly add-ons** (annual figures spread evenly over 12 months; HOA is already monthly):
```
tax_monthly       = annual_property_tax / 12
insurance_monthly = annual_home_insurance / 12
hoa_monthly       = monthly_hoa                          # entered as a monthly figure
total_monthly     = pi_monthly + tax_monthly + insurance_monthly + hoa_monthly
```
The **amortization schedule** is computed from `loan_amount`, `r`, `n`, and the **P&I** payment only
(tax/insurance/HOA do not amortize the loan) — identical recurrence to Loan/Amortization. Loan totals:
`total_interest = Σ interest_k`, `total_of_pi = loan_amount + total_interest`.

### Schedule recurrence (authoritative)
Start `balance = loan_amount`; for each month `k = 1..n`:
```
interest_k  = round_to_cent(balance × r)
principal_k = (k < n) ? (pi_monthly − interest_k) : balance
balance     = (k < n) ? (balance − principal_k) : 0
payment_k   = principal_k + interest_k                 # the P&I payment (excludes tax/ins/HOA)
```

## Inputs
| name                 | type    | rules                                                          |
|----------------------|---------|----------------------------------------------------------------|
| home_price           | decimal | presence, numericality (greater than 0)                        |
| down_payment         | decimal | presence, numericality (greater than or equal to 0)            |
| annual_rate          | decimal | presence, numericality (greater than or equal to 0)            |
| loan_term_years      | integer | presence, numericality (greater than 0)                        |
| annual_property_tax  | decimal | numericality (greater than or equal to 0); optional, default 0 |
| annual_home_insurance| decimal | numericality (greater than or equal to 0); optional, default 0 |
| monthly_hoa          | decimal | numericality (greater than or equal to 0); optional, default 0 |

_Validation: `down_payment` must be `< home_price` (the loan amount must be positive)._

## Outputs
| key                | meaning                                                                  |
|--------------------|--------------------------------------------------------------------------|
| loan_amount        | home_price − down_payment, money string                                  |
| pi_monthly         | principal & interest portion of the monthly payment                      |
| tax_monthly        | property tax / 12                                                        |
| insurance_monthly  | home insurance / 12                                                      |
| hoa_monthly        | the entered monthly HOA fee                                              |
| total_monthly      | pi_monthly + tax_monthly + insurance_monthly + hoa_monthly              |
| total_interest     | sum of all monthly interest portions over the term                       |
| total_of_pi        | loan_amount + total_interest (total of all P&I payments)                 |
| number_of_payments | n = loan_term_years × 12                                                 |
| schedule           | array of month rows (P&I schedule; same schema as Amortization/Loan)     |
| chart              | object with the payment-component donut + balance-curve series (below)   |

### `schedule` row schema (the `tabular-output`)
```jsonc
{ "month": 1, "payment": "1995.91", "interest": "1750.00", "principal": "245.91", "balance": "299754.09" }
```
- `payment` here is the **P&I** payment (the schedule amortizes only the loan).
- `schedule.length == number_of_payments`; the last row's `balance` is `"0.00"`.

### `chart` schema (the `charts` series — DESIGN §4 "Charts", FE renders, no math in view)
```jsonc
{
  "payment_components": [
    { "label": "Principal & interest", "amount": "1995.91" },
    { "label": "Property tax",         "amount": "291.67" },
    { "label": "Home insurance",       "amount": "100.00" },
    { "label": "HOA",                  "amount": "50.00" }
  ],
  "balance_curve": [
    { "month": 0,   "balance": "300000.00" },
    { "month": 12,  "balance": "296...." },
    { "month": 360, "balance": "0.00" }
  ]
}
```
The donut compares the **monthly-payment components** (largest slice — P&I — green, then coral, amber,
… per DESIGN §4). `balance_curve` is the remaining-balance-over-time series; the backend emits at
least the endpoints + yearly samples (it may emit the full per-month balance) so the FE draws the
curve without recomputing math.

## Reference values
_PM-computed at full `BigDecimal` precision; the backend agent must reproduce them exactly._

_`total_of_pi` / `total_interest` are the **schedule-reconciled** sums (Σ over the P&I rows, final row
absorbing rounding) — not `pi_monthly × n`._
| home_price | down_payment | annual_rate | loan_term_years | annual_property_tax | annual_home_insurance | monthly_hoa | loan_amount | pi_monthly | tax_monthly | insurance_monthly | hoa_monthly | total_monthly | total_interest | total_of_pi |
|------------|--------------|-------------|-----------------|---------------------|------------------------|-------------|-------------|------------|-------------|-------------------|-------------|---------------|----------------|-------------|
| 360000     | 60000        | 7           | 30              | 3500                | 1200                   | 50          | 300000.00   | 1995.91    | 291.67      | 100.00            | 50.00       | 2437.58       | 418524.05      | 718524.05   |
| 250000     | 50000        | 6           | 15              | 0                   | 0                      | 0           | 200000.00   | 1687.71    | 0.00        | 0.00              | 0.00        | 1687.71       | 103788.82      | 303788.82   |
| 200000     | 200000       | 5           | 30              | 0                   | 0                      | 0           | 0.00        | —          | —           | —                 | —           | —             | —              | —           |

_Worked anchor (row 1): loan_amount = 360000 − 60000 = **300000**; r = 0.07/12, n = 360 → raw P&I
1995.9087… → **1995.91**; month-1 interest = 300000 × 0.07/12 = **1750.00**, principal = 1995.91 −
1750.00 = **245.91**, new balance **299754.09**; tax_monthly = 3500/12 = **291.67** (291.666… → half-up
291.67), insurance_monthly = 1200/12 = **100.00**, hoa = **50.00**; total_monthly = 1995.91 + 291.67 +
100.00 + 50.00 = **2437.58**. `total_of_pi` = Σ of the 360 P&I payments with final-row reconciliation
= **718524.05**, `total_interest = total_of_pi − loan_amount` = **418524.05**. Row 3 (down_payment ==
home_price → loan_amount 0) is the **validation edge** — `down_payment` must be strictly `<
home_price`, so this row is **invalid**._

### Edge / validation cases
| inputs | expected |
|--------|----------|
| down_payment == home_price | invalid (loan amount must be > 0) |
| down_payment > home_price | invalid |
| loan_term_years = 0 | invalid (greater than 0) |
| loan_term_years = 29.5 | invalid (fractional integer — Base numeric guard rejects) |
| tax/insurance/HOA omitted | treated as 0; total_monthly = pi_monthly |

### Schedule-shape assertions (must also test)
- `schedule.length == number_of_payments`.
- `schedule.first` matches the month-1 P&I breakdown for row 1 above.
- `schedule.last["balance"] == "0.00"`.
- `Σ schedule[*].interest == total_interest`; `Σ schedule[*].payment == total_of_pi`.

## Notes
- **No mode picker** — Mortgage is single-mode (fixed-rate, full breakdown). It is the loan cluster's
  charts-bearing member: the FE renders the payment-component **donut** + the **balance curve** per
  `DESIGN.md §4` "Charts" (importmap JS charting library, hover/tooltip, no-JS data-table/legend
  fallback retained), reading only the `chart` envelope key — **no math in the view**.
- **Reuse the Loan/Amortization amortized core** — Mortgage's P&I and schedule are the same math as
  Loan's `payment` mode; build it on that primitive rather than re-deriving (Loan ships first this
  iteration for exactly this reason).
- Rounding/display: full-precision `BigDecimal`; money → 2 dp half-up (§10); annual tax/insurance
  divided by 12 then rounded to the cent for display; the schedule's final payment absorbs rounding so
  the balance clears to `0.00`.
- `:integer` `loan_term_years` — the `Calculators::Base` numeric guard rejects non-numeric /
  fractional input at the cast seam, so **no `only_integer` workaround is needed**.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
