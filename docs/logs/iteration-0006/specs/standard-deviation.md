<!-- spec:v1 -->
**Category:** Math
**Source:** https://www.calculator.net/standard-deviation-calculator.html
**Complexity:** 3
**Tags:** statistical, multi-mode, text-output
**Card description:** Standard deviation, variance and mean of a data set — choose population or sample.

## Intent
Given a list of numbers and a choice of **population** or **sample**, compute the **mean**, the
**variance**, the **standard deviation**, plus the **count** and **sum** of the data set. This is a
variable-length list-input calculator (like Mean·Median·Mode·Range) with a **population/sample mode
picker** that selects the variance denominator.

### Formula (authoritative)
Let the data be `x₁ … xₙ`, `n = count`, `mean = (Σ xᵢ) / n`, and `SS = Σ (xᵢ − mean)²` (sum of
squared deviations from the mean).
```
population:  variance = SS / n          standard_deviation = √(SS / n)
sample:      variance = SS / (n − 1)    standard_deviation = √(SS / (n − 1))
```
The **sample** mode requires `n ≥ 2` (else the `(n − 1)` denominator is zero). Population is defined
for `n ≥ 1`.

## Inputs
| name   | type   | rules                                                                                         |
|--------|--------|-----------------------------------------------------------------------------------------------|
| values | string | presence; parses to a list of numbers (comma- and/or whitespace-separated); each token numeric |
| mode   | string | presence, inclusion in `population`, `sample`                                                   |

_`values` is a `:string` parsed to a `BigDecimal` list (the MMR pattern): split on commas/whitespace,
reject any non-numeric token with a label-based error ("Values must be a list of numbers"). `sample`
mode additionally requires at least 2 values._

## Outputs
| key                | meaning                                            |
|--------------------|----------------------------------------------------|
| mode               | echo of the chosen mode (`population` / `sample`)   |
| count              | n, the number of values (integer)                  |
| sum                | Σ xᵢ                                               |
| mean               | (Σ xᵢ) / n                                         |
| variance           | SS / n  (population)  or  SS / (n − 1)  (sample)   |
| standard_deviation | √variance                                          |

## Reference values
_PM-computed deterministically; the backend agent must reproduce them exactly. Non-money statistical
outputs are displayed to **6 decimal places** (see Notes); `count` is an integer and `sum` is exact.
Both modes are shown for the primary data set so the denominator difference is pinned._

Primary data set: `10, 12, 23, 23, 16, 23, 21, 16`  (n = 8, sum = 144, mean = 18)

| values                          | mode         | count | sum | mean      | variance   | standard_deviation |
|---------------------------------|--------------|-------|-----|-----------|------------|--------------------|
| `10,12,23,23,16,23,21,16`       | `population` | 8     | 144 | 18.000000 | 24.000000  | 4.898979           |
| `10,12,23,23,16,23,21,16`       | `sample`     | 8     | 144 | 18.000000 | 27.428571  | 5.237229           |
| `2,4,6,8`                       | `population` | 4     | 20  | 5.000000  | 5.000000   | 2.236068           |
| `2,4,6,8`                       | `sample`     | 4     | 20  | 5.000000  | 6.666667   | 2.581989           |
| `5,5,5`                         | `population` | 3     | 15  | 5.000000  | 0.000000   | 0.000000           |
| `5,5,5`                         | `sample`     | 3     | 15  | 5.000000  | 0.000000   | 0.000000           |

_Worked anchor (`10,12,23,23,16,23,21,16`, population): mean = 144/8 = **18**; SS = Σ(xᵢ−18)² =
64+36+25+25+4+25+9+4 = **192**; population variance = 192/8 = **24** → SD = √24 = **4.898979**; sample
variance = 192/7 = **27.428571** → SD = √27.428571 = **5.237229**. The all-equal set `5,5,5` has SS = 0
→ variance and SD both **0.000000** in either mode._

### Edge / validation cases
| inputs | expected |
|--------|----------|
| values = "" | invalid (presence) |
| values = `5`, mode = `sample` | invalid (sample needs n ≥ 2) |
| values = `5`, mode = `population` | valid: count 1, sum 5, mean 5.000000, variance 0.000000, SD 0.000000 |
| values = `1, two, 3` | invalid ("Values must be a list of numbers") |
| mode = `pop` | invalid (not in inclusion list) |

## Notes
- **Mode picker (`DESIGN.md §4`):** `mode` is a single-select posted as `inputs[mode]` via a native
  radio `<fieldset>`. Two short labels (Population / Sample, N=2) → per the §4 rule (N≤3, short) the
  FE renders a **segmented control**; each option may carry a one-line helper ("÷ n" vs "÷ n−1").
- Rounding/display: statistical outputs (mean, variance, standard_deviation) are computed at full
  `BigDecimal` precision and **displayed to 6 decimal places** (half-up); `count` is an integer; `sum`
  is exact (no forced decimals). `text-output` — the result is a small stat grid, not money.
- The √ is computed at `BigDecimal` precision (e.g. `BigDecimal#sqrt` with sufficient precision) and
  then rounded for display.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
