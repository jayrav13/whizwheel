<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/vat-calculator.html
**Complexity:** 2
**Tags:** multi-input, multi-mode
**Card description:** Solve a value-added-tax problem from any two of the three figures — net price, VAT rate, or gross price — and get the VAT amount and the missing value.

## Intent
A solve-for-X **value-added tax (VAT)** calculator over three related figures: the **net price** (before
VAT), the **VAT rate (%)**, and the **gross price** (after VAT). Given any **two**, solve for the third
(and always report the **VAT amount**). A **mode picker** selects which figure is the unknown. The same
single-formula relationship — `gross = net × (1 + rate/100)` — drives all three modes; they differ only
in which variable is isolated.

> **Structural twin of Sales Tax.** This calculator and the Sales Tax calculator are deliberate
> structural twins — identical solve-for-X shape (before/tax/after ↔ net/VAT/gross, three modes),
> differing only in domain labels. The convergence probe is whether the agents produce parallel
> structure from parallel specs. Keep the two specs aligned.

### Modes (the `mode` input — which figure is unknown)
| mode    | given                   | solves for      |
|---------|-------------------------|-----------------|
| `gross` | `net_price`, `rate`     | `gross_price`   |
| `net`   | `gross_price`, `rate`   | `net_price`     |
| `rate`  | `net_price`, `gross_price` | `rate` (%)   |

### Formula (authoritative — confirmed against the Source)
Let `N` = net price, `t` = rate/100, `G` = gross price, `vat` = VAT amount.
```
vat = N × t                       # the VAT amount
G   = N + vat = N × (1 + t)
```
Solved per mode:
- **gross** → `vat = N × rate/100`;  `G = N + vat`.
- **net**   → `N = G / (1 + rate/100)`;  `vat = G − N`.
- **rate**  → `vat = G − N`;  `rate = (vat / N) × 100`.

## Inputs
| name        | type    | rules                                                                       |
|-------------|---------|-----------------------------------------------------------------------------|
| mode        | string  | presence, inclusion in `gross`, `net`, `rate`                               |
| net_price   | decimal | numericality (greater than 0); required when `mode` ∈ {`gross`, `rate`}      |
| gross_price | decimal | numericality (greater than 0); required when `mode` ∈ {`net`, `rate`}        |
| rate        | decimal | numericality (greater than or equal to 0); required when `mode` ∈ {`gross`, `net`} |

_Each mode requires exactly the two figures it is **given**; the field it solves for is left blank. In
`rate` mode, `gross_price` must be `≥ net_price` (a non-negative VAT)._

## Outputs
| key         | meaning                                    |
|-------------|--------------------------------------------|
| mode        | echo of the solve-for mode                 |
| net_price   | net price (given or solved), money string  |
| gross_price | gross price (given or solved), money string|
| rate        | VAT rate in percent (given or solved)      |
| vat_amount  | the VAT dollar amount = gross − net        |

## Reference values
_PM-computed deterministically; the backend agent must reproduce them exactly. Money rounds to the cent
half-up; `rate` is displayed to 4 decimal places half-up._

| mode    | net_price | gross_price | rate    | vat_amount |
|---------|-----------|-------------|---------|------------|
| `gross` | 10.00     | 11.00       | 10      | 1.00       |
| `gross` | 49.99     | 53.61       | 7.25    | 3.62       |
| `net`   | 10.00     | 11.00       | 10      | 1.00       |
| `rate`  | 10.00     | 11.00       | 10.0000 | 1.00       |

_Worked anchor (`gross`, N=10, rate=10): vat = 10 × 10/100 = **1.00**; gross = 10 + 1 = **11.00** (the
Source's coffee example). (`gross`, N=49.99, rate=7.25): vat = 49.99 × 0.0725 = 3.624… → **3.62**; gross =
49.99 + 3.62 = **53.61** — the twin of the Sales Tax row.) (`net`, G=11, rate=10): N = 11 / 1.10 =
**10.00**; vat = 11 − 10 = **1.00**.) (`rate`, N=10, G=11): vat = 11 − 10 = **1.00**; rate = (1 / 10) ×
100 = **10.0000**%._

### Edge / validation cases
| inputs | expected |
|--------|----------|
| `mode=gross`, net_price = 0 | invalid (greater than 0) |
| `mode=gross`, rate blank | invalid (rate required for this mode) |
| `mode=net`, gross_price = 50, rate = 0 | valid → net = 50.00, vat = 0.00 |
| `mode=rate`, net = 10, gross = 9 | invalid (gross must be ≥ net — negative VAT) |
| `mode=rate`, gross_price blank | invalid (gross required for rate mode) |
| `mode=zzz` | invalid (mode not in inclusion list) |
| `mode=gross`, net = "x" | invalid (Base numeric guard rejects non-numeric) |

## Notes
- **Mode picker (`DESIGN.md §4`):** `mode` is a single-select posted as `inputs[mode]` via a native radio
  `<fieldset>`. Three modes — "Gross price" / "Net price" / "VAT rate" — are short labels (N=3), so per the
  §4 rule the FE renders a **segmented control** (the connected horizontal track), each option's helper
  naming what it solves. The form shows only the two **given** fields for the chosen mode. **Keep this
  presentation parallel to the Sales Tax twin.**
- Rounding/display: full-precision `BigDecimal` compute; money → 2 dp half-up (§10); `rate` → 4 dp half-up.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
