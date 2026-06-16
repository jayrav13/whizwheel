<!-- spec:v1 -->
**Category:** Math
**Source:** https://www.calculator.net/pythagorean-theorem-calculator.html
**Complexity:** 2
**Tags:** geometry, multi-mode
**Card description:** Solve a right triangle's third side with the Pythagorean theorem — give two sides and get the missing one, plus a labeled figure.

## Intent
A focused **Pythagorean theorem** calculator: given **two of the three sides** of a right triangle, solve
for the **missing side** using `a² + b² = c²` (where `c` is the hypotenuse). A **mode picker** selects
which side is unknown — either both legs are known (solve the hypotenuse) or one leg and the hypotenuse
are known (solve the other leg). It is a **subset** of the existing Right Triangle calculator (sides only,
no angles/area), paired with an **inline SVG figure** of the labeled triangle.

> This is a deliberately leaner sibling of Right Triangle — it isolates the side-solving core. The FE
> renders a small **inline SVG figure** of the right triangle with its sides labeled (the figure is
> static illustration, **not** a charting-library chart — DESIGN §4's "never hand-roll a chart" rule is
> about data charts; a labeled geometric diagram is fine as inline SVG).

### Modes (the `mode` input — which side is unknown)
| mode        | given  | solves for                    |
|-------------|--------|-------------------------------|
| `hypotenuse`| `a`, `b` | `c = √(a² + b²)`            |
| `leg`       | `a`, `c` | `b = √(c² − a²)`            |

_In `leg` mode the hypotenuse `c` must be **strictly greater than** the known leg `a` (else no real
triangle)._

### Formula (authoritative — the Pythagorean theorem)
```
c = √(a² + b²)        # hypotenuse mode
b = √(c² − a²)        # leg mode   (requires c > a)
```

## Inputs
| name | type    | rules                                                                       |
|------|---------|-----------------------------------------------------------------------------|
| mode | string  | presence, inclusion in `hypotenuse`, `leg`                                  |
| a    | decimal | presence, numericality (greater than 0) — leg `a`, required in both modes   |
| b    | decimal | numericality (greater than 0); required when `mode` = `hypotenuse`           |
| c    | decimal | numericality (greater than 0); required when `mode` = `leg`; must be > a     |

_Each mode requires exactly the two sides it is **given**; the side it solves for is left blank._

## Outputs
| key  | meaning                                  |
|------|------------------------------------------|
| mode | echo of the solve-for mode               |
| a    | leg a (given), number string             |
| b    | leg b (given or solved), number string   |
| c    | hypotenuse (given or solved), number string |

## Reference values
_PM-computed deterministically; the backend agent must reproduce them exactly. Sides are displayed to
**6 decimal places** (half-up); see Notes._

| mode         | a | b         | c         | (solved)       |
|--------------|---|-----------|-----------|----------------|
| `hypotenuse` | 3 | 4         | 5.000000  | c = 5.000000   |
| `hypotenuse` | 5 | 12        | 13.000000 | c = 13.000000  |
| `hypotenuse` | 8 | 15        | 17.000000 | c = 17.000000  |
| `hypotenuse` | 1 | 1         | 1.414214  | c = 1.414214   |
| `leg`        | 5 | 12.000000 | 13        | b = 12.000000  |
| `leg`        | 6 | 8.000000  | 10        | b = 8.000000   |

_Worked anchor (`hypotenuse`, a=3, b=4): c = √(3² + 4²) = √(9 + 16) = √25 = **5.000000**. (`hypotenuse`,
a=1, b=1): c = √2 = **1.414214** (6 dp, half-up). (`leg`, a=5, c=13): b = √(13² − 5²) = √(169 − 25) =
√144 = **12.000000**.)_

### Edge / validation cases
| inputs | expected |
|--------|----------|
| `mode=hypotenuse`, a = 0 | invalid (greater than 0) |
| `mode=hypotenuse`, b blank | invalid (b required for hypotenuse mode) |
| `mode=leg`, a = 5, c = 5 | invalid (hypotenuse must be > leg) |
| `mode=leg`, a = 8, c = 6 | invalid (hypotenuse must be > leg) |
| `mode=leg`, c blank | invalid (c required for leg mode) |
| `mode=xyz` | invalid (mode not in inclusion list) |
| `mode=hypotenuse`, a = "x" | invalid (Base numeric guard rejects non-numeric) |

## Notes
- **Mode picker (`DESIGN.md §4`):** `mode` is a single-select posted as `inputs[mode]` via a native radio
  `<fieldset>`. Two modes — "Solve the hypotenuse (legs a, b)" / "Solve a leg (a, hypotenuse c)" — read as
  **multi-word**, so per the §4 rule the FE renders the **`.mode-option` option list** (each option's helper
  names which side it solves). The form shows only the two **given** side fields for the chosen mode.
- **Inline SVG figure:** the FE draws a small static labeled right-triangle diagram (sides a, b, c marked) —
  this is illustrative inline SVG, **not** a data chart (the DESIGN §4 charting-library rule does not apply).
  Right Triangle (#192/#215) ships such a figure; reuse that approach. (Note the known clip on extreme
  values — #215 — but Pythagorean's plain side outputs are lower-risk.)
- Rounding/display: √ computed at `BigDecimal` precision (e.g. `BigDecimal#sqrt`); sides **displayed to 6
  decimal places** (half-up), matching Right Triangle.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
