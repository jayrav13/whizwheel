<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/personal-loan-calculator.html
**Complexity:** 3
**Tags:** multi-input, tabular-output
**Card description:** An amortized personal loan — enter the loan amount, rate, and term to see the monthly payment, total interest, total cost, and full repayment schedule.

## Intent
A straightforward fixed-rate **amortizing personal loan** — the plain loan-core skin of the loan
cluster. Given a loan amount, an annual interest rate, and a term in months, compute the level
**monthly payment**, the loan totals, and the full month-by-month repayment schedule. It reuses the
**same amortized-payment math and schedule recurrence** as the Loan calculator's `payment` mode — build
it on that primitive rather than re-deriving.

This is the simplest member of the loan cluster: single-mode, no auto/mortgage add-ons.

### Formula (authoritative)
Let `r = annual_rate / 100 / 12` (monthly rate), `n = term_months`, `P = loan_amount`:
```
M = P · r · (1+r)^n / ((1+r)^n − 1)     # r > 0   (the amortized-payment identity)
M = P / n                                # r = 0 edge
```

### Schedule recurrence (authoritative — produces the table, identical to Loan)
Start `balance = P`; for each month `k = 1..n` with the level `M` rounded to the cent:
```
interest_k  = round_to_cent(balance × r)
principal_k = (k < n) ? (M − interest_k) : balance     # final row clears the residual
balance     = (k < n) ? (balance − principal_k) : 0
payment_k   = principal_k + interest_k                 # = M except possibly the final row
```
`total_interest = Σ interest_k`; `total_paid = Σ payment_k = loan_amount + total_interest`.

## Inputs
| name        | type    | rules                                               |
|-------------|---------|-----------------------------------------------------|
| loan_amount | decimal | presence, numericality (greater than 0)             |
| annual_rate | decimal | presence, numericality (greater than or equal to 0) |
| term_months | integer | presence, numericality (greater than 0)             |

## Outputs
| key                | meaning                                                    |
|--------------------|------------------------------------------------------------|
| loan_amount        | echo of the loan amount, money string                      |
| monthly_payment    | the level monthly payment, money string                    |
| total_paid         | sum of all payments = loan_amount + total_interest         |
| total_interest     | sum of all monthly interest portions                       |
| number_of_payments | n = term_months                                            |
| schedule           | array of month rows (same schema as Loan/Amortization)     |

### `schedule` row schema (the `tabular-output`)
```jsonc
{ "month": 1, "payment": "463.16", "interest": "87.50", "principal": "375.66", "balance": "14624.34" }
```
- `schedule.length == number_of_payments`; the last row's `balance` is `"0.00"`.

## Reference values
_PM-computed at full `BigDecimal` precision with the formula + schedule recurrence above; the backend
agent must reproduce them exactly. `total_paid` / `total_interest` are the **schedule-reconciled** sums
(Σ over the rows, final row absorbing rounding) — not `monthly_payment × n`. Money rounds to the cent
half-up._

| loan_amount | annual_rate | term_months | monthly_payment | total_paid | total_interest |
|-------------|-------------|-------------|-----------------|------------|----------------|
| 15000       | 7           | 36          | 463.16          | 16673.61   | 1673.61        |
| 8000        | 11          | 24          | 372.86          | 8948.73    | 948.73         |
| 5000        | 0           | 12          | 416.67          | 5000.00    | 0.00           |

_Worked anchor (`15000 @ 7%/36`): r = 0.07/12 = 0.0058333…, n = 36 → raw payment 463.1559… → **463.16**;
month-1 interest = 15000 × 0.0058333… = **87.50**, principal = 463.16 − 87.50 = **375.66**, new balance
**14624.34**; the final (36th) payment absorbs accumulated rounding, clearing the balance to **0.00**.
Schedule-reconciled sums: `total_interest` = Σ interest = **1673.61**, `total_paid` = loan_amount +
total_interest = **16673.61**. (The `0%` row: M = 5000/12 = 416.666… → **416.67**; the final payment
absorbs the rounding so total_paid is exactly **5000.00** and total_interest **0.00**.)_

### Edge / validation cases
| inputs | expected |
|--------|----------|
| loan_amount = 0 | invalid (greater than 0) |
| term_months = 0 | invalid (greater than 0) |
| term_months = 36.5 | invalid (fractional integer — Base numeric guard rejects) |
| annual_rate = "x" | invalid (Base numeric guard rejects non-numeric) |
| loan_amount blank | invalid (presence) |

### Schedule-shape assertions (must also test)
- `schedule.length == number_of_payments`.
- `schedule.first` matches the month-1 breakdown for the `15000 @ 7%/36` anchor above.
- `schedule.last["balance"] == "0.00"`.
- `Σ schedule[*].interest == total_interest` and `Σ schedule[*].payment == total_paid`.

## Notes
- **Reuse the Loan/Amortization amortized core** — Personal Loan's payment and schedule are exactly the
  Loan `payment`-mode math; build it on that primitive (Loan ships first this iteration for this reason).
  Personal Loan is the loan-core skin with no extra fields and no mode picker.
- **No mode picker** — single-mode (always solves for the payment).
- Rounding/display: full-precision `BigDecimal` compute; money → 2 dp half-up (§10); the schedule is built
  from the displayed payment and the final payment absorbs rounding so the balance lands exactly on `0.00`.
- `:integer` `term_months` — the `Calculators::Base` numeric guard rejects non-numeric / fractional input
  at the cast seam, so **no `only_integer` workaround is needed**.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
