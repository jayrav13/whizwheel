<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/average-return-calculator.html
**Complexity:** 3
**Tags:** multi-input, statistical
**Card description:** Average a series of period returns — get both the simple arithmetic average and the compounded geometric average (the true annualized rate).

## Intent
An **average return** calculator over a **list of periodic returns** (each a percent). It computes the
**arithmetic average return** (the simple mean of the period returns) and the **geometric average return**
(the compounded rate — the rate that, applied each period, reproduces the cumulative growth). The
geometric average is the financially meaningful "average" for multi-period returns because it accounts
for compounding; the arithmetic average overstates it. This reuses the **variable-length list input**
proven by Mean·Median·Mode·Range, applied to the financial geometric-mean formula.

### Formula (authoritative)
Given `n` period returns `r₁, r₂, …, rₙ` (each a percent, e.g. `10` means +10%):
```
arithmetic_average = (Σ rᵢ) / n

# geometric average — the n-th root of the product of growth factors, minus 1:
growth_factor      = Π (1 + rᵢ/100)                      # product over all periods
geometric_average  = ( growth_factor ^ (1/n) − 1 ) × 100
```
A period return may be **negative** (a loss), e.g. `−50` means −50% (growth factor 0.5). A `−100` return
(total loss → growth factor 0) is a degenerate input: the geometric average is then `−100%` regardless of
other periods, and a return **below −100%** is invalid (a growth factor cannot be negative).

## Inputs
| name    | type             | rules                                                                  |
|---------|------------------|------------------------------------------------------------------------|
| returns | list of decimals | presence (at least 1 value); each value numericality, greater than or equal to −100 |

_`returns` is a **variable-length list** (same input pattern as Mean·Median·Mode·Range): the FE collects a
list of period-return percentages and posts them as `inputs[returns][]`. Empty/blank entries are dropped;
at least one value must remain._

## Outputs
| key                | meaning                                                       |
|--------------------|---------------------------------------------------------------|
| count              | number of period returns, integer                             |
| arithmetic_average | the simple mean of the returns, percent                       |
| geometric_average  | the compounded (true) average return, percent                 |

## Reference values
_PM-computed deterministically (real-precision n-th root); the backend agent must reproduce them exactly.
Percentages display to **4 decimal places** (half-up)._

| returns          | count | arithmetic_average | geometric_average |
|------------------|-------|--------------------|-------------------|
| [10, 20, −5, 15] | 4     | 10.0000            | 9.5844            |
| [5, 5, 5, 5]     | 4     | 5.0000             | 5.0000            |
| [100, −50]       | 2     | 25.0000            | 0.0000            |
| [10, −10]        | 2     | 0.0000             | −0.5013           |

_Worked anchor (`[10, 20, −5, 15]`): arithmetic = (10 + 20 − 5 + 15) / 4 = 40 / 4 = **10.0000**%; growth
factor = 1.10 × 1.20 × 0.95 × 1.15 = 1.44210; geometric = (1.44210^(1/4) − 1) × 100 = **9.5844**%.
(`[100, −50]`): arithmetic = (100 − 50)/2 = **25.0000**%; growth factor = 2.0 × 0.5 = 1.0, geometric =
(1.0^(1/2) − 1) × 100 = **0.0000**% — the classic illustration that a +100%/−50% sequence nets zero growth
yet shows a +25% arithmetic average. (`[10, −10]`): arithmetic = **0.0000**%; growth factor = 1.10 × 0.90 =
0.99, geometric = (0.99^(1/2) − 1) × 100 = **−0.5013**% — the arithmetic-zero case still loses ground
geometrically.)_

### Edge / validation cases
| inputs | expected |
|--------|----------|
| returns = [] (all blank) | invalid (at least one value required) |
| returns = [10] | valid → arithmetic = 10.0000, geometric = 10.0000 (single period: both equal) |
| returns = [−100] | valid → growth factor 0 → geometric_average = −100.0000 |
| returns = [−150] | invalid (a return below −100% is impossible — growth factor < 0) |
| returns = [10, "x", 20] | invalid (Base numeric guard rejects the non-numeric entry) |

## Notes
- **Variable-length list input (no mode picker):** reuse the Mean·Median·Mode·Range list-input pattern —
  the FE collects period returns and posts `inputs[returns][]`; the backend parses the list, drops blanks,
  and validates ≥ 1 remains. There is **no** mode picker; both averages are always reported side by side.
- **Stat-grid output:** the two averages (+ count) render in the shared **`.stat-grid`** component
  (`DESIGN.md §4`), not a hand-rolled grid. Magnitudes are small percentages → the default 9.5rem track
  (not `--wide`).
- Rounding/display: full-precision `BigDecimal`; the geometric mean's n-th root computed at `BigDecimal`
  precision (e.g. `BigMath`-style root), **not** float; percentages → 4 dp half-up. Geometric and arithmetic
  averages may be **negative** — render the sign.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
