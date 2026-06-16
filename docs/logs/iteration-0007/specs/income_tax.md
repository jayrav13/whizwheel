<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/tax-calculator.html
**Complexity:** 5
**Tags:** multi-input, tabular-output
**Card description:** US federal income tax on your taxable income — progressive 2024 single-filer brackets, with the per-bracket breakdown plus your effective and marginal rates.

## Intent
A **progressive income tax** calculator — the iteration's **one new primitive: bracket / piecewise math.**
Given a **taxable income** (and, optionally, gross income and deductions that derive it), apply the
**2024 US federal single-filer ordinary-income tax brackets** (pinned below) to compute the **total tax**,
the **per-bracket breakdown** (the `tabular-output`), the **after-tax income**, the **effective tax rate**
(total tax ÷ taxable income), and the **marginal tax rate** (the rate of the top bracket the income
reaches).

> **Scope (deliberate, citable):** calculator.net's full income-tax page models filing statuses, dependents,
> many income types, deductions, and credits. This calculator implements the **core progressive-bracket
> primitive only**, against a **single, pinned, citable bracket schedule** — the 2024 US federal
> single-filer ordinary-income brackets — so the math is unambiguous and fully reproducible. The bracket
> schedule is **stated in this spec** and is the authoritative reference for the calculator; the backend
> reproduces it verbatim (it has no web access). Filing status / credits / multiple income types are out of
> scope for this build.

### Bracket schedule (authoritative — 2024 US federal, filing status = single)
Each bracket taxes only the portion of taxable income that falls **within** its range (the marginal
structure). The brackets, in order:

| bracket | taxable income range            | rate |
|---------|---------------------------------|------|
| 1       | $0 – $11,600                    | 10%  |
| 2       | $11,600 – $47,150               | 12%  |
| 3       | $47,150 – $100,525              | 22%  |
| 4       | $100,525 – $191,950             | 24%  |
| 5       | $191,950 – $243,725             | 32%  |
| 6       | $243,725 – $609,350             | 35%  |
| 7       | over $609,350                   | 37%  |

(Edges are upper-exclusive / lower-inclusive: income exactly at $11,600 has fully filled bracket 1 and not
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
{ "rate": "22", "lower": "47150.00", "upper": "100525.00", "taxable_in_bracket": "53375.00", "tax": "11742.50" }
```
- One row per bracket the income **reaches** (rows below the income's marginal bracket are full; the
  marginal bracket's row is partial; brackets above the income are omitted).
- The top bracket's `upper` is null / "—" (unbounded).
- `Σ brackets[*].tax == total_tax`; `Σ brackets[*].taxable_in_bracket == taxable_income`.

## Reference values
_PM-computed deterministically against the pinned 2024 single-filer schedule above; the backend agent must
reproduce them exactly. Money rounds to the cent half-up; rates display to 4 decimal places half-up. **The
marginal-rate reference cases are chosen to sit clearly INSIDE a bracket (never on a bracket edge), so the
marginal rate is unambiguous** (per `ARCHITECTURE.md §3.2`)._

| taxable_income | total_tax  | after_tax_income | effective_rate | marginal_rate |
|----------------|------------|------------------|----------------|---------------|
| 10000.00       | 1000.00    | 9000.00          | 10.0000        | 10            |
| 50000.00       | 6053.00    | 43947.00         | 12.1060        | 22            |
| 100000.00      | 17053.00   | 82947.00         | 17.0530        | 22            |
| 250000.00      | 57874.75   | 192125.25        | 23.1499        | 35            |
| 700000.00      | 217187.75  | 482812.25        | 31.0268        | 37            |
| 0.00           | 0.00       | 0.00             | 0.0000         | (none / 0)    |

_Worked anchor (`taxable_income = 250000`), per-bracket breakdown — the `brackets` table:_
| rate | lower    | upper    | taxable_in_bracket | tax       |
|------|----------|----------|--------------------|-----------|
| 10%  | 0        | 11600    | 11600.00           | 1160.00   |
| 12%  | 11600    | 47150    | 35550.00           | 4266.00   |
| 22%  | 47150    | 100525   | 53375.00           | 11742.50  |
| 24%  | 100525   | 191950   | 91425.00           | 21942.00  |
| 32%  | 191950   | 243725   | 51775.00           | 16568.00  |
| 35%  | 243725   | 609350   | 6275.00            | 2196.25   |

_Σ tax = 1160.00 + 4266.00 + 11742.50 + 21942.00 + 16568.00 + 2196.25 = **57874.75** = `total_tax`;
Σ taxable_in_bracket = 11600 + 35550 + 53375 + 91425 + 51775 + 6275 = **250000** = `taxable_income`.
effective_rate = 57874.75 / 250000 × 100 = **23.1499**%; the last dollar lands in bracket 6 (243725–609350)
so marginal_rate = **35**%. (`taxable_income = 50000`): brackets 1–3, total = 1160 + 4266 + (50000 −
47150) × 0.22 = 1160 + 4266 + 627 = **6053.00**; effective = 6053/50000 × 100 = **12.1060**%; the last
dollar is in bracket 3 → marginal = **22**%. (`taxable_income = 0`): no bracket reached → total_tax 0.00,
effective 0.0000%, marginal 0 (no bracket).)_

### Edge / validation cases
| inputs | expected |
|--------|----------|
| taxable_income = 0 | valid → total_tax 0.00, effective 0.0000, marginal 0, empty brackets array |
| taxable_income = 11600 (exact edge) | total_tax = 1160.00 (bracket 1 exactly filled); marginal = 10% (lower bracket at an edge) |
| gross_income = 60000, deductions = 14600 | taxable_income = 45400 → tax computed on 45400 |
| gross_income = 10000, deductions = 15000 | taxable_income = max(0, −5000) = 0 → total_tax 0.00 |
| neither taxable_income nor gross_income given | invalid (one is required) |
| taxable_income = −100 | invalid (greater than or equal to 0) |
| taxable_income = "x" | invalid (Base numeric guard rejects non-numeric) |

### Breakdown-shape assertions (must also test)
- `Σ brackets[*].tax == total_tax`.
- `Σ brackets[*].taxable_in_bracket == taxable_income`.
- `brackets.length` equals the number of brackets the income reaches (e.g. 6 for 250000, 3 for 50000, 0 for 0).
- The `brackets` rows for the `taxable_income = 250000` anchor match the per-bracket table above exactly.

## Notes
- **The new primitive is bracket / piecewise math** — implement the marginal-bracket sum generally (iterate
  the pinned schedule, taxing each band), not as a hard-coded six-term polynomial; the brackets are data.
  This is the rigor point of the iteration: the schedule above is the single source of truth and the math
  must reproduce the reference values to the cent.
- **`tabular-output`:** the per-bracket `brackets` array is the breakdown table (`DESIGN.md §4` Data table —
  thin rules, right-aligned `tabular-nums`, a hard total row). No charts required for this build (a future
  variant could add a bracket-stack chart; not in scope here).
- **Marginal rate at an edge:** income exactly at a bracket boundary has fully filled the lower bracket and
  not entered the next, so its marginal rate is the **lower** bracket's. The reference table's marginal
  cases (50000→22, 100000→22, 250000→35, 700000→37) all sit **inside** a bracket to avoid this ambiguity;
  the edge case (11600→10%) is listed explicitly in the validation table.
- Rounding/display: full-precision `BigDecimal`; money → 2 dp half-up (§10); rates → 4 dp half-up. Compute
  `total_tax` from the un-rounded per-bracket products, then round for display (the pinned reference values
  are exact at the cent).
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
