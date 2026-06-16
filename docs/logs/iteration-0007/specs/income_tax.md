<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/tax-calculator.html
**Complexity:** 5
**Tags:** multi-input, tabular-output
**Card description:** US federal income tax on your taxable income — progressive 2025 single-filer brackets, with the per-bracket breakdown plus your effective and marginal rates.

## Intent
A **progressive income tax** calculator — the iteration's **one new primitive: bracket / piecewise math.**
Given a **taxable income** (and, optionally, gross income and deductions that derive it), apply the
**2025 US federal single-filer ordinary-income tax brackets** (pinned below) to compute the **total tax**,
the **per-bracket breakdown** (the `tabular-output`), the **after-tax income**, the **effective tax rate**
(total tax ÷ taxable income), and the **marginal tax rate** (the rate of the top bracket the income
reaches).

> **Scope (deliberate, citable):** calculator.net's full income-tax page models filing statuses, dependents,
> many income types, deductions, and credits. This calculator implements the **core progressive-bracket
> primitive only**, against a **single, pinned, citable bracket schedule** — the **2025 US federal
> single-filer ordinary-income brackets** (IRS Rev. Proc. 2024-40, tax year 2025) — so the math is
> unambiguous and fully reproducible. The bracket schedule is **stated in this spec** and is the
> authoritative reference for the calculator; the backend reproduces it verbatim (it has no web access).
> Filing status / credits / multiple income types are out of scope for this build.

### Bracket schedule (authoritative — 2025 US federal, filing status = single)
**Source / year:** IRS **Rev. Proc. 2024-40** — inflation adjustments for **tax year 2025**, single /
unmarried individuals. Each bracket taxes only the portion of taxable income that falls **within** its range
(the marginal structure). The brackets, in order:

| bracket | taxable income range            | rate |
|---------|---------------------------------|------|
| 1       | $0 – $11,925                    | 10%  |
| 2       | $11,925 – $48,475               | 12%  |
| 3       | $48,475 – $103,350              | 22%  |
| 4       | $103,350 – $197,300             | 24%  |
| 5       | $197,300 – $250,525             | 32%  |
| 6       | $250,525 – $626,350             | 35%  |
| 7       | over $626,350                   | 37%  |

(Edges are upper-exclusive / lower-inclusive: income exactly at $11,925 has fully filled bracket 1 and not
yet entered bracket 2.)

### Formula (authoritative — piecewise sum across brackets)
```
taxable_income = max(0, gross_income − deductions)        # when gross/deductions are the inputs
                 (or taxable_income entered directly)

# total tax — sum the tax owed in each bracket the income reaches:
for each bracket [lo, hi) at rate p:
    if taxable_income <= lo: stop
    taxed_in_bracket = min(taxable_income, hi) − lo        # hi = ∞ for the top bracket
    tax_in_bracket   = taxed_in_bracket × p
total_tax = Σ tax_in_bracket

after_tax_income = taxable_income − total_tax
effective_rate   = total_tax / taxable_income × 100        # 0 when taxable_income = 0
marginal_rate    = the rate p of the highest bracket whose lo < taxable_income
                   (i.e. the bracket the last dollar lands in; at an exact edge, the lower bracket)
```

## Inputs
This calculator accepts **either** a directly-entered `taxable_income` **or** `gross_income` + `deductions`
(from which `taxable_income = max(0, gross_income − deductions)` is derived). Provide `taxable_income`
directly for the simplest path; the reference values below pin the direct-entry case.

| name           | type    | rules                                                                    |
|----------------|---------|--------------------------------------------------------------------------|
| gross_income   | decimal | numericality (greater than or equal to 0); optional                      |
| deductions     | decimal | numericality (greater than or equal to 0); optional, default 0           |
| taxable_income | decimal | numericality (greater than or equal to 0); required if `gross_income` absent |

_Resolution rule: if `taxable_income` is given, use it. Else require `gross_income` and compute
`taxable_income = max(0, gross_income − deductions)`. At least one of `taxable_income` / `gross_income`
must be present._

## Outputs
| key              | meaning                                                              |
|------------------|----------------------------------------------------------------------|
| taxable_income   | the taxable income the tax was computed on, money string             |
| total_tax        | the total federal income tax, money string                           |
| after_tax_income | taxable_income − total_tax, money string                             |
| effective_rate   | total_tax / taxable_income × 100 (percent)                           |
| marginal_rate    | the top bracket rate the income reaches (percent)                    |
| brackets         | array of per-bracket rows (the `tabular-output` breakdown)           |

### `brackets` row schema (the `tabular-output`)
```jsonc
{ "rate": "22", "lower": "48475.00", "upper": "103350.00", "taxable_in_bracket": "54875.00", "tax": "12072.50" }
```
- One row per bracket the income **reaches** (rows below the income's marginal bracket are full; the
  marginal bracket's row is partial; brackets above the income are omitted).
- The top bracket's `upper` is null / "—" (unbounded).
- `Σ brackets[*].tax == total_tax`; `Σ brackets[*].taxable_in_bracket == taxable_income`.

## Reference values
_PM-computed deterministically against the pinned 2025 single-filer schedule above; the backend agent must
reproduce them exactly. Money rounds to the cent half-up; rates display to 4 decimal places half-up. **The
marginal-rate reference cases are chosen to sit clearly INSIDE a bracket (never on a bracket edge), so the
marginal rate is unambiguous** (per `ARCHITECTURE.md §3.2`)._

| taxable_income | total_tax  | after_tax_income | effective_rate | marginal_rate |
|----------------|------------|------------------|----------------|---------------|
| 10000.00       | 1000.00    | 9000.00          | 10.0000        | 10            |
| 50000.00       | 5914.00    | 44086.00         | 11.8280        | 22            |
| 100000.00      | 16914.00   | 83086.00         | 16.9140        | 22            |
| 250000.00      | 57063.00   | 192937.00        | 22.8252        | 32            |
| 700000.00      | 216020.25  | 483979.75        | 30.8600        | 37            |
| 0.00           | 0.00       | 0.00             | 0.0000         | (none / 0)    |

_Worked anchor (`taxable_income = 250000`), per-bracket breakdown — the `brackets` table:_
| rate | lower    | upper    | taxable_in_bracket | tax       |
|------|----------|----------|--------------------|-----------|
| 10%  | 0        | 11925    | 11925.00           | 1192.50   |
| 12%  | 11925    | 48475    | 36550.00           | 4386.00   |
| 22%  | 48475    | 103350   | 54875.00           | 12072.50  |
| 24%  | 103350   | 197300   | 93950.00           | 22548.00  |
| 32%  | 197300   | 250525   | 52700.00           | 16864.00  |

_Σ tax = 1192.50 + 4386.00 + 12072.50 + 22548.00 + 16864.00 = **57063.00** = `total_tax`;
Σ taxable_in_bracket = 11925 + 36550 + 54875 + 93950 + 52700 = **250000** = `taxable_income`.
effective_rate = 57063.00 / 250000 × 100 = **22.8252**%; the last dollar lands in bracket 5 (197300–250525,
and 250000 < 250525) so marginal_rate = **32**%. (`taxable_income = 50000`): brackets 1–3, total = 1192.50 +
4386.00 + (50000 − 48475) × 0.22 = 1192.50 + 4386.00 + 335.50 = **5914.00**; effective = 5914/50000 × 100 =
**11.8280**%; the last dollar is in bracket 3 → marginal = **22**%. (`taxable_income = 0`): no bracket reached
→ total_tax 0.00, effective 0.0000%, marginal 0 (no bracket).)_

### Edge / validation cases
| inputs | expected |
|--------|----------|
| taxable_income = 0 | valid → total_tax 0.00, effective 0.0000, marginal 0, empty brackets array |
| taxable_income = 11925 (exact edge) | total_tax = 1192.50 (bracket 1 exactly filled); marginal = 10% (lower bracket at an edge) |
| gross_income = 60000, deductions = 14600 | taxable_income = 45400 → tax computed on 45400 (total_tax = 5209.50) |
| gross_income = 10000, deductions = 15000 | taxable_income = max(0, −5000) = 0 → total_tax 0.00 |
| neither taxable_income nor gross_income given | invalid (one is required) |
| taxable_income = −100 | invalid (greater than or equal to 0) |
| taxable_income = "x" | invalid (Base numeric guard rejects non-numeric) |

### Breakdown-shape assertions (must also test)
- `Σ brackets[*].tax == total_tax`.
- `Σ brackets[*].taxable_in_bracket == taxable_income`.
- `brackets.length` equals the number of brackets the income reaches (e.g. 5 for 250000, 3 for 50000, 0 for 0).
- The `brackets` rows for the `taxable_income = 250000` anchor match the per-bracket table above exactly.

## Notes
- **The new primitive is bracket / piecewise math** — implement the marginal-bracket sum generally (iterate
  the pinned schedule, taxing each band), not as a hard-coded seven-term polynomial; the brackets are data.
  This is the rigor point of the iteration: the schedule above is the single source of truth and the math
  must reproduce the reference values to the cent.
- **`tabular-output`:** the per-bracket `brackets` array is the breakdown table (`DESIGN.md §4` Data table —
  thin rules, right-aligned `tabular-nums`, a hard total row). No charts required for this build (a future
  variant could add a bracket-stack chart; not in scope here).
- **Marginal rate at an edge:** income exactly at a bracket boundary has fully filled the lower bracket and
  not entered the next, so its marginal rate is the **lower** bracket's. The reference table's marginal
  cases (50000→22, 100000→22, 250000→32, 700000→37) all sit **inside** a bracket to avoid this ambiguity;
  the edge case (11925→10%) is listed explicitly in the validation table.
- Rounding/display: full-precision `BigDecimal`; money → 2 dp half-up (§10); rates → 4 dp half-up. Compute
  `total_tax` from the un-rounded per-bracket products, then round for display (the pinned reference values
  are exact at the cent).
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
