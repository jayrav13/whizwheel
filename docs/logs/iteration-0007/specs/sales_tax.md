<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/sales-tax-calculator.html
**Complexity:** 2
**Tags:** multi-input, multi-mode
**Card description:** Solve a sales-tax problem from any two of the three figures — before-tax price, tax rate, or after-tax price — and get the tax amount and the missing value.

## Intent
A solve-for-X **sales tax** calculator over three related figures: the **before-tax price**, the
**sales-tax rate (%)**, and the **after-tax price**. Given any **two**, solve for the third (and always
report the **tax amount**). A **mode picker** selects which figure is the unknown. The same
single-formula relationship — `after = before × (1 + rate/100)` — drives all three modes; they differ
only in which variable is isolated.

> **Structural twin of VAT.** This calculator and the VAT calculator are deliberate structural twins —
> identical solve-for-X shape (before/tax/after, three modes), differing only in domain labels (sales
> tax vs. value-added tax). The convergence probe is whether the agents produce parallel structure from
> parallel specs. Keep the two specs aligned.

### Modes (the `mode` input — which figure is unknown)
| mode      | given                       | solves for           |
|-----------|-----------------------------|----------------------|
| `after`   | `before_tax_price`, `rate`  | `after_tax_price`    |
| `before`  | `after_tax_price`, `rate`   | `before_tax_price`   |
| `rate`    | `before_tax_price`, `after_tax_price` | `rate` (%)  |

### Formula (authoritative — confirmed against the Source)
Let `B` = before-tax price, `t` = rate/100, `A` = after-tax price, `tax` = tax amount.
```
tax = B × t                       # the tax amount
A   = B + tax = B × (1 + t)
```
Solved per mode:
- **after**  → `tax = B × rate/100`;  `A = B + tax`.
- **before** → `B = A / (1 + rate/100)`;  `tax = A − B`.
- **rate**   → `tax = A − B`;  `rate = (tax / B) × 100`.

## Inputs
| name              | type    | rules                                                                          |
|-------------------|---------|--------------------------------------------------------------------------------|
| mode              | string  | presence, inclusion in `after`, `before`, `rate`                               |
| before_tax_price  | decimal | numericality (greater than 0); required when `mode` ∈ {`after`, `rate`}         |
| after_tax_price   | decimal | numericality (greater than 0); required when `mode` ∈ {`before`, `rate`}        |
| rate              | decimal | numericality (greater than or equal to 0); required when `mode` ∈ {`after`, `before`} |

_Each mode requires exactly the two figures it is **given**; the field it solves for is left blank. In
`rate` mode, `after_tax_price` must be `≥ before_tax_price` (a non-negative tax)._

## Outputs
| key              | meaning                                          |
|------------------|--------------------------------------------------|
| mode             | echo of the solve-for mode                       |
| before_tax_price | before-tax price (given or solved), money string |
| after_tax_price  | after-tax price (given or solved), money string  |
| rate             | tax rate in percent (given or solved)            |
| tax_amount       | the tax dollar amount = after − before           |

## Reference values
_PM-computed deterministically; the backend agent must reproduce them exactly. Money rounds to the cent
half-up; `rate` is displayed to 4 decimal places half-up._

| mode     | before_tax_price | after_tax_price | rate    | tax_amount |
|----------|------------------|-----------------|---------|------------|
| `after`  | 100.00           | 106.00          | 6       | 6.00       |
| `after`  | 49.99            | 53.61           | 7.25    | 3.62       |
| `before` | 100.00           | 106.00          | 6       | 6.00       |
| `rate`   | 100.00           | 106.00          | 6.0000  | 6.00       |

_Worked anchor (`after`, B=100, rate=6): tax = 100 × 6/100 = **6.00**; after = 100 + 6 = **106.00**.
(`after`, B=49.99, rate=7.25): tax = 49.99 × 0.0725 = 3.624… → **3.62**; after = 49.99 + 3.62 = **53.61**.)
(`before`, A=106, rate=6): B = 106 / 1.06 = **100.00**; tax = 106 − 100 = **6.00**.)
(`rate`, B=100, A=106): tax = 106 − 100 = **6.00**; rate = (6 / 100) × 100 = **6.0000**%._

### Edge / validation cases
| inputs | expected |
|--------|----------|
| `mode=after`, before_tax_price = 0 | invalid (greater than 0) |
| `mode=after`, rate blank | invalid (rate required for this mode) |
| `mode=before`, before_tax_price blank, after_tax_price = 50, rate = 0 | valid → before = 50.00, tax = 0.00 |
| `mode=rate`, before = 100, after = 90 | invalid (after must be ≥ before — negative tax) |
| `mode=rate`, after_tax_price blank | invalid (after required for rate mode) |
| `mode=zzz` | invalid (mode not in inclusion list) |
| `mode=after`, before = "x" | invalid (Base numeric guard rejects non-numeric) |

## Notes
- **Mode picker (`DESIGN.md §4`):** `mode` is a single-select posted as `inputs[mode]` via a native radio
  `<fieldset>`. Three modes — "After-tax price" / "Before-tax price" / "Tax rate" — are short labels (N=3),
  so per the §4 rule the FE renders a **segmented control** (the connected horizontal track), each option's
  helper naming what it solves. The form shows only the two **given** fields for the chosen mode. **Keep
  this presentation parallel to the VAT twin.**
- Rounding/display: full-precision `BigDecimal` compute; money → 2 dp half-up (§10); `rate` → 4 dp half-up.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
