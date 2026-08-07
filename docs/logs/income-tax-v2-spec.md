<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/tax-calculator.html
**Complexity:** 5
**Tags:** multi-input, multi-mode, tabular-output
**Card description:** US federal income tax for any filing status — applies your 2025 standard deduction, then the progressive 2025 brackets for that status, with the per-bracket breakdown plus your effective and marginal rates.

## Intent
A **progressive US federal income tax** calculator — **v2**, widening iteration-0007's single-filer build to the
**moderate completeness band** (`PRODUCT.md`). Given a **gross income** and a **filing status**, the calculator
applies the **2025 standard deduction** for that status, derives **taxable income**, then applies the **2025 US
federal ordinary-income tax brackets** for the selected status (all pinned below) to compute the **total tax**, the
**per-bracket breakdown** (the `tabular-output`), the **effective tax rate**, and the **marginal tax rate**.

```
standard_deduction = the 2025 standard deduction for the selected filing_status (table below)
taxable_income     = max(0, gross_income − standard_deduction)
```

> **Scope (deliberate, citable) — the completeness band.** calculator.net's full income-tax page models filing
> statuses, dependents, many income types, itemized deductions, and dozens of credits. iteration-0007 shipped the
> **minimal** end of that (federal, **single filer only**, ordinary income, taxable income entered directly), which
> the operator judged **too thin**. This **v2** moves it to the **moderate band** (`PRODUCT.md` *"The completeness
> band"*): it covers the **four common filing statuses** every taxpayer picks from **plus the standard deduction** —
> meaningfully more than the toy version — while still **deferring** the maximal page's itemized deductions,
> tax credits, multiple income types, dependents, and state tax (rare/expert configurations). The bracket schedules
> and standard deductions are **stated in this spec** and are the authoritative reference; the backend reproduces
> them verbatim (it has no web access).

### Filing statuses (the `multi-mode` knob)
A single required **`filing_status`** selects which standard deduction and which bracket schedule apply. The four
values, **with their acronym expansions** (`ARCHITECTURE.md §3.2` — never ship an unexplained acronym):

| value    | label                       | expansion / who it's for                                              |
|----------|-----------------------------|-----------------------------------------------------------------------|
| `single` | **Single**                  | unmarried / does not qualify for another status                       |
| `mfj`    | **Married Filing Jointly (MFJ)**   | a married couple filing one combined return                    |
| `mfs`    | **Married Filing Separately (MFS)** | a married person filing their own separate return             |
| `hoh`    | **Head of Household (HoH)** | unmarried and paying >½ the cost of a home for a qualifying dependent  |

### 2025 standard deduction (authoritative — IRS Rev. Proc. 2024-40, tax year 2025)
| filing_status | standard_deduction |
|---------------|--------------------|
| `single`      | $15,000            |
| `mfj`         | $30,000            |
| `mfs`         | $15,000            |
| `hoh`         | $22,500            |

### Bracket schedules (authoritative — 2025 US federal ordinary-income brackets, IRS Rev. Proc. 2024-40, tax year 2025)
Each bracket taxes only the portion of **taxable income** that falls **within** its range (the marginal structure).
Edges are **upper-exclusive / lower-inclusive**: income exactly at a boundary has fully filled the lower bracket and
not yet entered the next. One schedule per filing status:

**`single` — Single:**
| bracket | taxable income range  | rate |
|---------|-----------------------|------|
| 1 | $0 – $11,925               | 10%  |
| 2 | $11,925 – $48,475          | 12%  |
| 3 | $48,475 – $103,350         | 22%  |
| 4 | $103,350 – $197,300        | 24%  |
| 5 | $197,300 – $250,525        | 32%  |
| 6 | $250,525 – $626,350        | 35%  |
| 7 | over $626,350              | 37%  |

**`mfj` — Married Filing Jointly:**
| bracket | taxable income range  | rate |
|---------|-----------------------|------|
| 1 | $0 – $23,850               | 10%  |
| 2 | $23,850 – $96,950          | 12%  |
| 3 | $96,950 – $206,700         | 22%  |
| 4 | $206,700 – $394,600        | 24%  |
| 5 | $394,600 – $501,050        | 32%  |
| 6 | $501,050 – $751,600        | 35%  |
| 7 | over $751,600              | 37%  |

**`mfs` — Married Filing Separately:**
| bracket | taxable income range  | rate |
|---------|-----------------------|------|
| 1 | $0 – $11,925               | 10%  |
| 2 | $11,925 – $48,475          | 12%  |
| 3 | $48,475 – $103,350         | 22%  |
| 4 | $103,350 – $197,300        | 24%  |
| 5 | $197,300 – $250,525        | 32%  |
| 6 | $250,525 – $375,800        | 35%  |
| 7 | over $375,800              | 37%  |

**`hoh` — Head of Household:**
| bracket | taxable income range  | rate |
|---------|-----------------------|------|
| 1 | $0 – $17,000               | 10%  |
| 2 | $17,000 – $64,850          | 12%  |
| 3 | $64,850 – $103,350         | 22%  |
| 4 | $103,350 – $197,300        | 24%  |
| 5 | $197,300 – $250,500        | 32%  |
| 6 | $250,500 – $626,350        | 35%  |
| 7 | over $626,350              | 37%  |

_(Note the two status-specific subtleties the backend must honor, not hard-code away: **MFS** diverges from Single
only at the top two brackets — its 35% band is $250,525–$375,800 and 37% starts at $375,800 (half the MFJ figures);
**HoH**'s 32% band ends at **$250,500**, $25 below Single's $250,525. The schedules are **data**, one per status.)_

### Formula (authoritative — piecewise sum across the selected status's schedule)
```
standard_deduction = lookup(filing_status)                      # from the table above
taxable_income     = max(0, gross_income − standard_deduction)

# total tax — sum the tax owed in each bracket the income reaches, in the selected status's schedule:
for each bracket [lo, hi) at rate p:
    if taxable_income <= lo: stop
    taxed_in_bracket = min(taxable_income, hi) − lo             # hi = ∞ for the top bracket
    tax_in_bracket   = taxed_in_bracket × p
total_tax = Σ tax_in_bracket

effective_rate = total_tax / taxable_income × 100              # 0 when taxable_income = 0
marginal_rate  = the rate p of the highest bracket whose lo < taxable_income
                 (the bracket the last taxable dollar lands in; at an exact edge, the lower bracket)
```

## Inputs
| name           | type    | rules                                                                                 |
|----------------|---------|---------------------------------------------------------------------------------------|
| filing_status  | string  | presence; inclusion in `{single, mfj, mfs, hoh}`                                       |
| gross_income   | decimal | presence; numericality (greater than or equal to 0)                                   |

_`filing_status` is the `multi-mode` selector (the four statuses above; render as a select / option list since the
labels are multi-word, `DESIGN.md §4`). `gross_income` is the only money input — the standard deduction is applied
automatically from the status, not entered. **Help text (per `ARCHITECTURE.md §3.2`, surfaced as the §4 envelope's
field `help`):** `gross_income` → "Your total income before any deductions"; `filing_status` → the four acronym
expansions in the Filing-statuses table above (MFJ / MFS / HoH)._

## Outputs
| key                | meaning                                                                       |
|--------------------|-------------------------------------------------------------------------------|
| filing_status      | the selected status, echoed back                                              |
| standard_deduction | the 2025 standard deduction applied for that status, money string             |
| taxable_income     | max(0, gross_income − standard_deduction), money string                       |
| total_tax          | the total federal income tax, money string                                    |
| effective_rate     | total_tax / taxable_income × 100 (percent, 4 dp)                               |
| marginal_rate      | the top bracket rate the taxable income reaches (percent, integer)            |
| brackets           | array of per-bracket rows (the `tabular-output` breakdown)                    |

### `brackets` row schema (the `tabular-output`)
```jsonc
{ "rate": "22", "lower": "48475.00", "upper": "103350.00", "taxable_in_bracket": "36525.00", "tax": "8035.50" }
```
- One row per bracket the income **reaches** (rows below the marginal bracket are full; the marginal bracket's row is
  partial; brackets above the income are omitted).
- The top bracket's `upper` is null / "—" (unbounded).
- `Σ brackets[*].tax == total_tax`; `Σ brackets[*].taxable_in_bracket == taxable_income`.

## Reference values
_PM-computed deterministically against the pinned 2025 schedules + standard deductions above; the backend agent must
reproduce them exactly. Money rounds to the cent half-up; `effective_rate` displays to **4 decimal places** half-up;
`marginal_rate` is the integer bracket percent. **Every income point below is chosen so the last taxable dollar sits
clearly INSIDE a bracket (never on a bracket edge), so the marginal rate is unambiguous** (`ARCHITECTURE.md §3.2`).
`effective_rate` is defined on **taxable income** (continuing the v1 definition — see Notes for the operator flag)._

**`single` — Single (standard deduction $15,000):**
| gross_income | taxable_income | total_tax  | effective_rate | marginal_rate |
|--------------|----------------|------------|----------------|---------------|
| 50000.00     | 35000.00       | 3961.50    | 11.3186        | 12            |
| 100000.00    | 85000.00       | 13614.00   | 16.0165        | 22            |
| 250000.00    | 235000.00      | 52263.00   | 22.2396        | 32            |

**`mfj` — Married Filing Jointly (standard deduction $30,000):**
| gross_income | taxable_income | total_tax  | effective_rate | marginal_rate |
|--------------|----------------|------------|----------------|---------------|
| 50000.00     | 20000.00       | 2000.00    | 10.0000        | 10            |
| 100000.00    | 70000.00       | 7923.00    | 11.3186        | 12            |
| 250000.00    | 220000.00      | 38494.00   | 17.4973        | 24            |

**`hoh` — Head of Household (standard deduction $22,500):**
| gross_income | taxable_income | total_tax  | effective_rate | marginal_rate |
|--------------|----------------|------------|----------------|---------------|
| 50000.00     | 27500.00       | 2960.00    | 10.7636        | 12            |
| 100000.00    | 77500.00       | 10225.00   | 13.1935        | 22            |
| 250000.00    | 227500.00      | 48124.00   | 21.1534        | 32            |

**`mfs` — Married Filing Separately (standard deduction $15,000)** — one high-income point chosen to exercise the
MFS-specific top brackets (35% band $250,525–$375,800, 37% over $375,800):
| gross_income | taxable_income | total_tax  | effective_rate | marginal_rate |
|--------------|----------------|------------|----------------|---------------|
| 400000.00    | 385000.00      | 104481.25  | 27.1380        | 37            |

### Worked anchors (per-bracket breakdown — the `brackets` table)

_**`single`, gross_income = 250,000** → taxable_income = 250,000 − 15,000 = 235,000:_
| rate | lower    | upper    | taxable_in_bracket | tax       |
|------|----------|----------|--------------------|-----------|
| 10%  | 0        | 11925    | 11925.00           | 1192.50   |
| 12%  | 11925    | 48475    | 36550.00           | 4386.00   |
| 22%  | 48475    | 103350   | 54875.00           | 12072.50  |
| 24%  | 103350   | 197300   | 93950.00           | 22548.00  |
| 32%  | 197300   | 250525   | 37700.00           | 12064.00  |

_Σ tax = 1192.50 + 4386.00 + 12072.50 + 22548.00 + 12064.00 = **52263.00** = `total_tax`; Σ taxable_in_bracket =
11925 + 36550 + 54875 + 93950 + 37700 = **235000** = `taxable_income`. effective_rate = 52263.00 / 235000 × 100 =
**22.2396**%; the last taxable dollar lands in bracket 5 (197300–250525, and 235000 < 250525) → marginal_rate =
**32**%; **5** bracket rows._

_**`hoh`, gross_income = 250,000** → taxable_income = 250,000 − 22,500 = 227,500:_
| rate | lower    | upper    | taxable_in_bracket | tax       |
|------|----------|----------|--------------------|-----------|
| 10%  | 0        | 17000    | 17000.00           | 1700.00   |
| 12%  | 17000    | 64850    | 47850.00           | 5742.00   |
| 22%  | 64850    | 103350   | 38500.00           | 8470.00   |
| 24%  | 103350   | 197300   | 93950.00           | 22548.00  |
| 32%  | 197300   | 250500   | 30200.00           | 9664.00   |

_Σ tax = 1700.00 + 5742.00 + 8470.00 + 22548.00 + 9664.00 = **48124.00** = `total_tax`; Σ taxable_in_bracket =
17000 + 47850 + 38500 + 93950 + 30200 = **227500** = `taxable_income`. effective_rate = 48124.00 / 227500 × 100 =
**21.1534**%; last dollar in bracket 5 (197300–250500, 227500 < 250500) → marginal = **32**%; **5** rows._

_**`mfj`, gross_income = 250,000** → taxable_income = 250,000 − 30,000 = 220,000:_
| rate | lower    | upper    | taxable_in_bracket | tax       |
|------|----------|----------|--------------------|-----------|
| 10%  | 0        | 23850    | 23850.00           | 2385.00   |
| 12%  | 23850    | 96950    | 73100.00           | 8772.00   |
| 22%  | 96950    | 206700   | 109750.00          | 24145.00  |
| 24%  | 206700   | 394600   | 13300.00           | 3192.00   |

_Σ tax = 2385.00 + 8772.00 + 24145.00 + 3192.00 = **38494.00** = `total_tax`; Σ taxable_in_bracket = 23850 + 73100 +
109750 + 13300 = **220000** = `taxable_income`. effective_rate = 38494.00 / 220000 × 100 = **17.4973**%; last dollar
in bracket 4 (206700–394600, 220000 < 394600) → marginal = **24**%; **4** rows._

### Edge / validation cases
| inputs | expected |
|--------|----------|
| filing_status = `mfj`, gross_income = 25000 | taxable_income = max(0, 25000 − 30000) = 0 → total_tax 0.00, effective 0.0000, marginal 0, **empty** brackets array |
| filing_status = `single`, gross_income = 15000 | taxable_income = 0 (gross exactly equals the deduction) → total_tax 0.00, effective 0.0000, marginal 0, empty brackets |
| filing_status = `single`, gross_income = 26925 | taxable_income = 11925 (exact bracket-1 edge) → total_tax = 1192.50 (bracket 1 exactly filled); marginal = **10**% (lower bracket at an edge) |
| filing_status = `hoh`, gross_income = 0 | taxable_income = 0 → total_tax 0.00, effective 0.0000, marginal 0, empty brackets |
| filing_status absent | invalid (presence) |
| filing_status = `joint` (not a recognized value) | invalid (inclusion in {single, mfj, mfs, hoh}) |
| gross_income absent | invalid (presence) |
| gross_income = −100 | invalid (greater than or equal to 0) |
| gross_income = "x" | invalid (Base numeric guard rejects non-numeric) |

### Breakdown-shape assertions (must also test)
- `Σ brackets[*].tax == total_tax`.
- `Σ brackets[*].taxable_in_bracket == taxable_income`.
- `brackets.length` equals the number of brackets the taxable income reaches (5 for single 250k, 4 for mfj 250k, 0 when taxable_income = 0).
- The `brackets` rows for each worked anchor above match exactly.
- The correct **per-status** schedule is used (e.g. an `mfj` 250k computes against the MFJ thresholds, not Single's) — assert at least the single/mfj/hoh 250k anchors land on different total_tax.

## Notes
- **The bracket/piecewise primitive is unchanged from v1; what's new is status-parameterization.** Implement the
  marginal-bracket sum generally (iterate the selected status's pinned schedule, taxing each band) — the schedules
  and standard deductions are **data keyed by `filing_status`**, never four hard-coded polynomials. This is the
  rigor point: the four schedules + four deductions above are the single source of truth and the math must reproduce
  every reference value to the cent.
- **Scope = the `PRODUCT.md` completeness band.** This v2 deliberately covers the four common filing statuses + the
  standard deduction and **defers** itemized deductions, credits, dependents, multiple income types, and state tax —
  the moderate middle, not the maximal page (`PRODUCT.md` *"The completeness band"*; `ARCHITECTURE.md §3.2` *"Scope
  to the completeness band"*). The v1 single-filer-only build was the minimal end the operator judged too thin.
- **`effective_rate` denominator — operator flag.** Defined here as `total_tax / taxable_income` (continuing the
  iteration-0007 v1 definition; it's the rate directly tied to the bracket math). **Judgment call for operator
  review:** with `gross_income` now the primary input, the operator may prefer `effective_rate` over **gross income**
  instead (the more intuitive "share of my paycheck" reading) — e.g. single 50k would read 7.9230% (3961.50/50000)
  rather than 11.3186%. If so, change this one definition in the spec and re-pin the reference column; flagged before
  build so the choice is deliberate.
- **`marginal_rate` at an edge:** income exactly at a bracket boundary has fully filled the lower bracket and not
  entered the next, so its marginal rate is the **lower** bracket's. Every reference income above sits **inside** a
  bracket to avoid this ambiguity; the edge case (single, taxable 11925 → 10%) is listed explicitly in the validation
  table.
- **Compare on calculator.net.** This calculator's page links back to its **Source** (`https://www.calculator.net/tax-calculator.html`)
  via the §4 envelope's `source_url` so a user can verify side by side (`PRODUCT.md` *"Every calculator links back to
  its source"*; `ARCHITECTURE.md §4`). Keep the spec `Source` and `INVENTORY.md`'s `source_url` in sync.
- Rounding/display: full-precision `BigDecimal`; money → 2 dp half-up (§10); `effective_rate` → 4 dp half-up;
  `marginal_rate` is the integer bracket percent. Compute `total_tax` from the un-rounded per-bracket products, then
  round for display (the pinned reference values are exact at the cent).
- Calculator-rewrite task — **regenerate from this spec, not from prior code.** This **v2** supersedes the
  iteration-0007 single-filer Income Tax spec for the next build (per the append-only/deprecate-never-delete ethos,
  the v1 version remains for historical comparability).
