<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/roi-calculator.html
**Complexity:** 2
**Tags:** multi-input
**Card description:** Return on investment — enter the amount invested and the amount returned (with an optional holding period) to get the total gain, ROI %, and annualized ROI.

## Intent
A **return on investment (ROI)** calculator: given the **amount invested** and the **amount returned**,
compute the **total gain** and the **ROI percentage**. If an optional **investment period (in years)** is
supplied, also compute the **annualized ROI** (the compound annual growth rate over that period). This is
a single-formula multi-input calculator (Percentage-shaped) with an optional time dimension.

### Formula (authoritative — confirmed against the Source)
```
total_gain  = amount_returned − amount_invested
roi_percent = (total_gain / amount_invested) × 100

# annualized ROI (CAGR), only when investment_years is supplied and > 0:
annualized_roi_percent = ((amount_returned / amount_invested) ^ (1 / investment_years) − 1) × 100
```
The annualized ROI is the constant yearly rate that compounds `amount_invested` into `amount_returned`
over `investment_years`. When `investment_years` is blank, `annualized_roi` is omitted (null).

## Inputs
| name             | type    | rules                                                                |
|------------------|---------|----------------------------------------------------------------------|
| amount_invested  | decimal | presence, numericality (greater than 0)                              |
| amount_returned  | decimal | presence, numericality (greater than or equal to 0)                  |
| investment_years | decimal | numericality (greater than 0); optional — annualized ROI only when present |

_`amount_returned` may be less than `amount_invested` (a loss → negative gain and ROI). `investment_years`
is a `:decimal` (fractional years like 1.5 are allowed)._

## Outputs
| key             | meaning                                                          |
|-----------------|------------------------------------------------------------------|
| amount_invested | echo of the amount invested, money string                        |
| amount_returned | echo of the amount returned, money string                        |
| total_gain      | amount_returned − amount_invested (may be negative), money string |
| roi_percent     | (total_gain / amount_invested) × 100                             |
| annualized_roi_percent | the CAGR over investment_years; **null** when no period given |

## Reference values
_PM-computed deterministically (CAGR via real-precision root); the backend agent must reproduce them
exactly. Money rounds to the cent half-up; percentages display to 4 decimal places half-up._

| amount_invested | amount_returned | investment_years | total_gain | roi_percent | annualized_roi_percent |
|-----------------|-----------------|------------------|------------|-------------|------------------------|
| 50000.00        | 70000.00        | 5                | 20000.00   | 40.0000     | 6.9610                 |
| 1000.00         | 1500.00         | 3                | 500.00     | 50.0000     | 14.4714                |
| 10000.00        | 8000.00         | —                | −2000.00   | −20.0000    | (null)                 |

_Worked anchor (`invested 50000, returned 70000, 5 years`): total_gain = 70000 − 50000 = **20000.00**;
roi = (20000 / 50000) × 100 = **40.0000**% (the Source's sheep-farm example); annualized = ((70000/50000)
^ (1/5) − 1) × 100 = (1.4^0.2 − 1) × 100 = **6.9610**%. (`1000 → 1500, 3 years`): roi = 50.0000%;
annualized = (1.5^(1/3) − 1) × 100 = **14.4714**%. (`10000 → 8000, no period`): total_gain = **−2000.00**,
roi = **−20.0000**%, annualized_roi **null**.)_

### Edge / validation cases
| inputs | expected |
|--------|----------|
| amount_invested = 0 | invalid (greater than 0 — division by zero) |
| amount_returned blank | invalid (presence) |
| investment_years = 0 | invalid (greater than 0 when supplied) |
| investment_years blank | valid → annualized_roi_percent is null |
| amount_invested = "x" | invalid (Base numeric guard rejects non-numeric) |
| amount_returned < amount_invested | valid → negative total_gain and roi_percent |

## Notes
- **No mode picker** — single computation; the only branch is whether `investment_years` was supplied
  (which adds the annualized figure). The annualized ROI requires a fractional power (CAGR root) — compute
  it at `BigDecimal` precision (e.g. `BigMath`-style root), not float.
- Rounding/display: full-precision `BigDecimal` compute; money → 2 dp half-up (§10); percentages → 4 dp
  half-up. `total_gain` and `roi_percent` may be **negative** — render the sign.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
