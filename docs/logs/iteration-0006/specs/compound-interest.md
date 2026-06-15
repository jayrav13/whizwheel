<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/compound-interest-calculator.html
**Complexity:** 4
**Tags:** multi-input, multi-mode, charts
**Card description:** Grow a principal with compound interest — pick how often it compounds (annually to daily) and see the future value, total interest, and a growth curve.

## Intent
Given a starting **principal**, an **annual interest rate**, a **time in years**, and a **compounding
frequency**, compute the **future value** (final balance) under compound interest, the **total
interest** earned, and a **year-by-year growth series** for the FE to chart. The compounding frequency
is a **mode picker** selecting how many times per year interest is added.

### Formula (authoritative — confirmed against the Source)
```
A = P × (1 + r/m)^(m·t)
```
where `P = principal`, `r = annual_rate / 100`, `m = periods per year` (from the compounding mode),
`t = years`. `total_interest = A − P`. Compute at full `BigDecimal` precision; round to the cent for
display.

### Compounding modes (the `compounding` input → m)
| compounding   | m (periods/year) |
|---------------|------------------|
| `annually`    | 1                |
| `semiannually`| 2                |
| `quarterly`   | 4                |
| `monthly`     | 12               |
| `daily`       | 365              |

### Growth series (for the chart)
The backend emits a year-by-year balance series so the FE draws the growth curve without doing math:
`balance` at the **end of each year** `y = 0..ceil(t)` (and at `t` itself if fractional):
`balance_y = P × (1 + r/m)^(m·y)`, rounded to the cent.

## Inputs
| name        | type    | rules                                                                                     |
|-------------|---------|-------------------------------------------------------------------------------------------|
| principal   | decimal | presence, numericality (greater than 0)                                                   |
| annual_rate | decimal | presence, numericality (greater than or equal to 0)                                       |
| years       | decimal | presence, numericality (greater than 0)                                                   |
| compounding | string  | presence, inclusion in `annually`, `semiannually`, `quarterly`, `monthly`, `daily`        |

_`years` is `:decimal` (fractional terms like 2.5 years are valid); the exponent `m·t` is taken at
full precision._

## Outputs
| key              | meaning                                                            |
|------------------|-------------------------------------------------------------------|
| future_value     | A = P × (1 + r/m)^(m·t), money string                              |
| total_interest   | A − P, money string                                               |
| principal        | echo of the entered principal, money string                       |
| periods_per_year | m, the compounding periods/year for the chosen mode (integer)     |
| compounding      | echo of the chosen mode                                           |
| growth_series    | array of `{ "year": y, "balance": "…" }` for the chart (below)    |

### `growth_series` schema (the `charts` series — DESIGN §4 "Charts", FE renders)
```jsonc
[
  { "year": 0,  "balance": "20000.00" },
  { "year": 1,  "balance": "21023.24" },
  /* … one row per whole year … */
  { "year": 10, "balance": "32940.19" }
]
```
The FE draws a balance-over-time curve from this series (DESIGN §4 "Charts": importmap JS charting
library, hover/tooltip, no-JS data-table fallback retained). It may also draw a principal-vs-interest
donut from `principal` + `total_interest` (largest slice green, then coral).

## Reference values
_PM-computed at full `BigDecimal` precision with `A = P(1 + r/m)^(m·t)`; the backend agent must
reproduce them exactly. Money rounds to the cent half-up. (The `20000 @ 5% monthly 10y` row matches
the Source's worked example, ~$32,940.)_

| principal | annual_rate | years | compounding   | m   | future_value | total_interest |
|-----------|-------------|-------|---------------|-----|--------------|----------------|
| 20000     | 5           | 10    | `monthly`     | 12  | 32940.19     | 12940.19       |
| 10000     | 6           | 5     | `annually`    | 1   | 13382.26     | 3382.26        |
| 5000      | 8           | 3     | `quarterly`   | 4   | 6341.21      | 1341.21        |
| 15000     | 4.5         | 2     | `daily`       | 365 | 16412.52     | 1412.52        |
| 1000      | 0           | 5     | `monthly`     | 12  | 1000.00      | 0.00           |

_Worked anchor (`20000 @ 5% monthly 10y`): r = 0.05, m = 12, t = 10 → A = 20000 × (1 + 0.05/12)^120 =
20000 × 1.6470096… = **32940.19**; total_interest = 32940.19 − 20000 = **12940.19**. The `0%` row is the
no-growth edge: A = P, interest = 0.00._

### Edge / validation cases
| inputs | expected |
|--------|----------|
| principal = 0 | invalid (greater than 0) |
| years = 0 | invalid (greater than 0) |
| compounding = `weekly` | invalid (not in inclusion list) |
| annual_rate = "abc" | invalid (Base numeric guard rejects non-numeric) |

## Notes
- **Mode picker (`DESIGN.md §4`):** `compounding` is a single-select posted as `inputs[mode]`-style
  `inputs[compounding]` via a native radio `<fieldset>`. Five modes, several **multi-word**
  (Semiannually, Quarterly) → per the §4 rule (N≥4 or any multi-word) the FE renders it as the
  **`.mode-option` option list** (each option's helper can name the periods/year, e.g. "12 times a
  year"). Not a raw `<select>`.
- Rounding/display: full-precision `BigDecimal` compute (the exponent `m·t` and the power computed
  exactly); money → 2 dp half-up (§10). The growth series balances are each rounded to the cent for
  display.
- `growth_series` exists so the FE renders the growth curve **without doing math** — the backend owns
  all numbers (`CLAUDE.md`; ARCHITECTURE §4).
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
