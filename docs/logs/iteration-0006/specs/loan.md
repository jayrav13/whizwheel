<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/loan-calculator.html
**Complexity:** 4
**Tags:** multi-input, multi-mode, tabular-output
**Card description:** An amortized fixed-rate loan — solve for the monthly payment, the loan amount you can afford, or the term, and see the full repayment schedule.

## Intent
A fixed-rate **amortizing loan**, generalizing the Amortization calculator with a **solve-for mode
picker**. Given any one of three unknowns to solve for, plus the other loan parameters, compute the
amortized result and the full month-by-month repayment schedule. The three modes share the **same
amortized-payment math**; they differ only in which variable is the unknown.

### Modes (the `mode` input — see Notes)
| mode | solves for | given |
|------|-----------|-------|
| `payment` | the level **monthly payment** | `loan_amount`, `annual_rate`, `term_months` |
| `amount`  | the affordable **loan amount** | `monthly_payment`, `annual_rate`, `term_months` |
| `term`    | the **term in months** to repay | `loan_amount`, `monthly_payment`, `annual_rate` |

### Formula (authoritative)
Let `r = annual_rate / 100 / 12` (monthly rate), `n = term_months`, `P = loan_amount`, `M =
monthly_payment`. The amortized-loan identity:
```
M = P · r · (1+r)^n / ((1+r)^n − 1)            # r > 0
M = P / n                                       # r = 0 edge
```
Solved per mode:
- **payment** → `M` from the identity above (the Amortization formula).
- **amount**  → `P = M · ((1+r)^n − 1) / (r · (1+r)^n)`  (r > 0);  `P = M · n` (r = 0).
- **term**    → `n = ln(M / (M − P·r)) / ln(1+r)`  (r > 0, requires `M > P·r` or it never amortizes);
  `n = P / M` (r = 0). Round `n` **up** to the next whole month (the last payment is smaller). Then
  recompute the schedule from the integer `n`.

### Schedule recurrence (authoritative — produces the table)
Once `P`, `r`, `n`, and the level `M` (rounded to the cent) are known, build the schedule exactly as
Amortization does. Start `balance = P`; for each month `k = 1..n`:
```
interest_k  = round_to_cent(balance × r)
principal_k = (k < n) ? (M − interest_k) : balance     # final row clears the residual
balance     = (k < n) ? (balance − principal_k) : 0
payment_k   = principal_k + interest_k                 # = M except possibly the final row
```
`total_interest = Σ interest_k`; `total_paid = Σ payment_k = (the solved P) + total_interest`.

## Inputs
| name            | type    | rules                                                                    |
|-----------------|---------|--------------------------------------------------------------------------|
| mode            | string  | presence, inclusion in `payment`, `amount`, `term`                       |
| loan_amount     | decimal | numericality (greater than 0); required when `mode` ∈ {`payment`,`term`} |
| monthly_payment | decimal | numericality (greater than 0); required when `mode` ∈ {`amount`,`term`}  |
| annual_rate     | decimal | presence, numericality (greater than or equal to 0)                      |
| term_months     | integer | numericality (greater than 0); required when `mode` ∈ {`payment`,`amount`} |

_Note: each mode requires exactly the two of the three loan figures it is **given**; the field it
solves for is left blank. The backend validates that the required-for-mode fields are present._

## Outputs
| key                | meaning                                                                  |
|--------------------|--------------------------------------------------------------------------|
| mode               | echo of the solved-for mode                                              |
| monthly_payment    | the level monthly payment (solved or given), money string               |
| loan_amount        | the loan amount (solved or given), money string                         |
| term_months        | the term in whole months (solved or given), integer                     |
| total_paid         | sum of all payments = loan_amount + total_interest                       |
| total_interest     | sum of all monthly interest portions                                     |
| number_of_payments | n = term_months                                                          |
| schedule           | array of row objects, one per month (same schema as Amortization)        |

### `schedule` row schema (the `tabular-output`)
```jsonc
{ "month": 1, "payment": "471.78", "interest": "104.17", "principal": "367.61", "balance": "24632.39" }
```
- `month` — 1-based payment number (integer).
- `payment` / `interest` / `principal` / `balance` — money strings rounded to the cent.
- `schedule.length == number_of_payments`; the last row's `balance` is `"0.00"`.

## Reference values
_PM-computed at full `BigDecimal` precision with the authoritative formulas + schedule recurrence
above; the backend agent must reproduce them exactly. Money rounds to the cent half-up._

### Mode `payment` — solve for monthly payment
_`total_paid` / `total_interest` are the **schedule-reconciled** sums (Σ over the rows, final row
absorbing rounding) — not `monthly_payment × n` (which can differ by a few cents)._
| loan_amount | annual_rate | term_months | monthly_payment | total_paid | total_interest |
|-------------|-------------|-------------|-----------------|------------|----------------|
| 200000      | 6           | 360         | 1199.10         | 431677.04  | 231677.04      |
| 25000       | 5           | 60          | 471.78          | 28306.88   | 3306.88        |
| 10000       | 0           | 24          | 416.67          | 10000.00   | 0.00           |

_Worked anchor (`25000 @ 5%/60mo`): r = 0.05/12 = 0.0041666…, n = 60 → raw payment 471.7794…
→ **471.78**; month-1 interest = 25000 × 0.0041666… = **104.17**, principal = 471.78 − 104.17 =
**367.61**, new balance **24632.39**. `total_paid` = Σ payments = **28306.88** (the final payment
absorbs accumulated rounding). The `0%` row's final row absorbs the level-payment rounding so the
total is exactly **10000.00** and the balance clears to 0.00._

### Mode `amount` — solve for affordable loan amount
_This mode is pinned by the **solved `loan_amount`** (the mode-defining figure, the exact inverse of
the payment identity). `total_paid`/`total_interest` are then the schedule-reconciled sums for that
solved amount — they follow the same recurrence as the payment mode and are not separately pinned
here (the payment-mode rows above pin the schedule-total reconciliation authoritatively)._
| monthly_payment | annual_rate | term_months | loan_amount (solved) |
|-----------------|-------------|-------------|----------------------|
| 1199.10         | 6           | 360         | 199999.82            |
| 471.78          | 5           | 60          | 24999.96             |

_Worked anchor (`1199.10 @ 6%/360`): P = M·((1+r)^n − 1)/(r·(1+r)^n) = **199999.82** (the inverse of
the payment row, off by 18¢ because the input payment was itself rounded to the cent). (`471.78 @
5%/60` → P = **24999.96**, again the cent-rounding inverse of 25000.)_

### Mode `term` — solve for term in months
| loan_amount | monthly_payment | annual_rate | term_months | note |
|-------------|-----------------|-------------|-------------|------|
| 25000       | 471.78          | 5           | 60          | exact inverse of the payment row |
| 10000       | 500.00          | 0           | 20          | r = 0 → n = P/M = 20 |

_Worked anchor (`25000, 471.78 @ 5%`): n = ln(M/(M − P·r)) / ln(1+r), r = 0.0041666…, P·r = 104.166…,
n = 59.99… → rounded **up** to **60** whole months._

### Edge / validation cases
| inputs | expected |
|--------|----------|
| `mode=payment`, loan_amount=0 | invalid (loan_amount must be > 0) |
| `mode=payment`, term_months blank | invalid (term required for this mode) |
| `mode=term`, monthly_payment ≤ loan_amount·r (e.g. 100000, 400 @ 6%) | invalid (payment never amortizes the loan) |
| `mode=zzz` | invalid (mode not in inclusion list) |
| `mode=payment`, term_months=3.5 | invalid (fractional integer — Base numeric guard rejects it) |

### Schedule-shape assertions (must also test)
- `schedule.length == number_of_payments`.
- `schedule.first` matches the month-1 breakdown for the `25000 @ 5%/60` anchor above.
- `schedule.last["balance"] == "0.00"`.
- `Σ schedule[*].interest == total_interest` and `Σ schedule[*].payment == total_paid`.

## Notes
- **Mode picker (`DESIGN.md §4`):** `mode` is a single-select posted as `inputs[mode]` via a native
  radio `<fieldset>`. Three short-ish modes (Monthly payment / Loan amount / Term) — the FE applies
  the §4 rule (N=3; if labels read short → segmented, else option list); each option's helper names
  what it solves for. The form shows/asks only the two **given** fields for the chosen mode.
- Rounding/display: full-precision `BigDecimal` compute; money → 2 dp half-up (§10); the schedule is
  built from the **displayed** payment and the **final** payment absorbs rounding so the balance
  lands exactly on `0.00`. The solved **term** rounds **up** to the next whole month.
- `:integer` `term_months` — the `Calculators::Base` numeric guard now rejects non-numeric and
  **fractional** input at the cast seam, so **no `only_integer` workaround is needed** in the
  calculator; just declare `:integer` with `greater than 0`.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
