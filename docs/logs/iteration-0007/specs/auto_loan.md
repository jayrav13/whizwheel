<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/auto-loan-calculator.html
**Complexity:** 3
**Tags:** multi-input, tabular-output
**Card description:** An amortized auto loan — fold trade-in, down payment, sales tax and fees into the financed amount and see the monthly payment, total interest, and full repayment schedule.

## Intent
An amortized fixed-rate **auto loan**, built on the **same amortized-payment loan core** as the Loan
and Amortization calculators, extended with the auto-specific adjustments calculator.net's auto-loan
page folds into the **amount financed**: a **trade-in** (which both reduces the cash price and earns a
**sales-tax credit**), a **down payment**, **sales tax** on the price net of trade-in, and **fixed
fees** (title / registration / other). It computes the amount financed, the level **monthly payment**,
the loan totals, and the full month-by-month repayment schedule.

This is single-mode (it always solves for the payment). It reuses Loan's amortized-payment math and
schedule recurrence — build it on that primitive rather than re-deriving.

### Formula (authoritative — confirmed against the Source)
The sales tax is levied on the price **net of trade-in** (the trade-in tax credit), then the financed
amount rolls in tax and fees and nets out the trade-in and down payment:
```
sales_tax       = round_to_cent( (auto_price − trade_in) × sales_tax_rate / 100 )
amount_financed = auto_price − down_payment − trade_in + sales_tax + fees
```
The level monthly payment amortizes `amount_financed` (the Loan/Amortization identity):
```
r = annual_rate / 100 / 12                       # monthly rate
n = term_months
M = amount_financed · r · (1+r)^n / ((1+r)^n − 1)   # r > 0
M = amount_financed / n                             # r = 0 edge
```

### Schedule recurrence (authoritative — produces the table, identical to Loan)
Start `balance = amount_financed`; for each month `k = 1..n` with the level `M` rounded to the cent:
```
interest_k  = round_to_cent(balance × r)
principal_k = (k < n) ? (M − interest_k) : balance     # final row clears the residual
balance     = (k < n) ? (balance − principal_k) : 0
payment_k   = principal_k + interest_k                 # = M except possibly the final row
```
`total_interest = Σ interest_k`; `total_paid = Σ payment_k = amount_financed + total_interest`.

## Inputs
| name           | type    | rules                                                          |
|----------------|---------|----------------------------------------------------------------|
| auto_price     | decimal | presence, numericality (greater than 0)                        |
| term_months    | integer | presence, numericality (greater than 0)                        |
| annual_rate    | decimal | presence, numericality (greater than or equal to 0)            |
| down_payment   | decimal | numericality (greater than or equal to 0); optional, default 0 |
| trade_in       | decimal | numericality (greater than or equal to 0); optional, default 0 |
| sales_tax_rate | decimal | numericality (greater than or equal to 0); optional, default 0 |
| fees           | decimal | numericality (greater than or equal to 0); optional, default 0 |

_Validation: the computed `amount_financed` must be `> 0` (e.g. a trade-in + down payment exceeding the
taxed price leaves nothing to finance) — reject otherwise._

## Outputs
| key                | meaning                                                              |
|--------------------|----------------------------------------------------------------------|
| amount_financed    | auto_price − down_payment − trade_in + sales_tax + fees, money string |
| sales_tax          | (auto_price − trade_in) × sales_tax_rate / 100, money string         |
| monthly_payment    | the level monthly payment amortizing amount_financed                 |
| total_paid         | sum of all payments = amount_financed + total_interest               |
| total_interest     | sum of all monthly interest portions                                 |
| number_of_payments | n = term_months                                                      |
| schedule           | array of month rows (same schema as Loan/Amortization)               |

### `schedule` row schema (the `tabular-output`)
```jsonc
{ "month": 1, "payment": "424.23", "interest": "93.67", "principal": "330.56", "balance": "22149.44" }
```
- `schedule.length == number_of_payments`; the last row's `balance` is `"0.00"`.

## Reference values
_PM-computed at full `BigDecimal` precision with the formulas + schedule recurrence above; the backend
agent must reproduce them exactly. `total_paid` / `total_interest` are the **schedule-reconciled** sums
(Σ over the rows, final row absorbing rounding) — not `monthly_payment × n`. Money rounds to the cent
half-up._

| auto_price | term_months | annual_rate | down_payment | trade_in | sales_tax_rate | fees | sales_tax | amount_financed | monthly_payment | total_paid | total_interest |
|------------|-------------|-------------|--------------|----------|----------------|------|-----------|-----------------|-----------------|------------|----------------|
| 30000      | 60          | 5           | 4000         | 6000     | 7              | 800  | 1680.00   | 22480.00        | 424.23          | 25453.48   | 2973.48        |
| 25000      | 48          | 6           | 3000         | 0        | 8              | 500  | 2000.00   | 24500.00        | 575.38          | 27618.41*  | 3118.41*       |
| 20000      | 36          | 0           | 2000         | 0        | 0              | 0    | 0.00      | 18000.00        | 500.00          | 18000.00   | 0.00           |

_*Row 2's `total_paid` / `total_interest` follow the same schedule-reconciled recurrence (final-row
reconciliation): `amount_financed 24500.00`, `r = 0.06/12 = 0.005`, `n = 48` → raw payment 575.3832… →
**575.38**; summing the 48 schedule rows (with the final row absorbing accumulated rounding to clear the
balance to `0.00`) gives `total_interest = Σ interest = **3118.41**` and `total_paid = amount_financed +
total_interest = **27618.41**`. These are **schedule-reconciled** figures — **not** `monthly_payment × n`
(575.38 × 48 = 27618.24, which would wrongly imply 3118.24 of interest); the cent of difference is the
final-row reconciliation, exactly as the worked row-1 anchor below derives. The authoritative worked anchor
is row 1, where the full schedule was reconciled._

_Worked anchor (row 1, `auto_price 30000, term 60, rate 5%, down 4000, trade-in 6000, tax 7%, fees 800`):
sales_tax = (30000 − 6000) × 7/100 = 24000 × 0.07 = **1680.00**; amount_financed = 30000 − 4000 − 6000 +
1680.00 + 800 = **22480.00**; r = 0.05/12 = 0.0041666…, n = 60 → raw payment 424.2247… → **424.23**;
month-1 interest = 22480.00 × 0.0041666… = **93.67**, principal = 424.23 − 93.67 = **330.56**, new balance
**22149.44**; the final (60th) payment absorbs accumulated rounding, clearing the balance to **0.00**.
Schedule-reconciled sums: `total_interest` = Σ interest = **2973.48**, `total_paid` = amount_financed +
total_interest = **25453.48**. (The `0%` row: amount_financed = 20000 − 2000 = 18000; M = 18000/36 =
500.00 exactly; total_paid = 18000.00, total_interest = 0.00.)_

### Edge / validation cases
| inputs | expected |
|--------|----------|
| auto_price = 0 | invalid (greater than 0) |
| term_months = 0 | invalid (greater than 0) |
| term_months = 60.5 | invalid (fractional integer — Base numeric guard rejects) |
| annual_rate = "x" | invalid (Base numeric guard rejects non-numeric) |
| auto_price 10000, down 5000, trade 6000, tax 0, fees 0 → amount_financed = −1000 | invalid (amount financed must be > 0) |
| down/trade/tax/fees omitted | treated as 0; amount_financed = auto_price, sales_tax = 0.00 |

### Schedule-shape assertions (must also test)
- `schedule.length == number_of_payments`.
- `schedule.first` matches the month-1 breakdown for the row-1 anchor above.
- `schedule.last["balance"] == "0.00"`.
- `Σ schedule[*].interest == total_interest` and `Σ schedule[*].payment == total_paid`.

## Notes
- **Reuse the Loan/Amortization amortized core** — Auto Loan's payment and schedule are the same math as
  Loan's `payment` mode; build it on that primitive. Loan ships first this iteration so Auto Loan inherits
  a proven loan core rather than re-deriving it.
- **No mode picker** — Auto Loan is single-mode (always solves for the payment). The auto-specific inputs
  (trade-in, down payment, sales tax, fees) are ordinary form fields, not a mode.
- Rounding/display: full-precision `BigDecimal` compute; money → 2 dp half-up (§10); `sales_tax` is rounded
  to the cent before it enters `amount_financed`; the schedule is built from the displayed payment and the
  final payment absorbs rounding so the balance lands exactly on `0.00`.
- `:integer` `term_months` — the `Calculators::Base` numeric guard rejects non-numeric / fractional input
  at the cast seam, so **no `only_integer` workaround is needed**.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
