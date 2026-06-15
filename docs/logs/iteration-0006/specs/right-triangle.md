<!-- spec:v1 -->
**Category:** Math
**Source:** https://www.calculator.net/right-triangle-calculator.html
**Complexity:** 3
**Tags:** geometry, multi-mode
**Card description:** Solve a right triangle from two known sides — get the third side, both acute angles, area, perimeter, and altitude.

## Intent
Given **two known sides** of a right triangle (the two legs, or one leg and the hypotenuse), solve for
**all remaining values**: the third side, both acute angles (degrees), the **area**, the
**perimeter**, and the **altitude** to the hypotenuse. A **solve-from mode picker** selects which two
sides are the knowns. (Sides: `a` and `b` are the two legs; `c` is the hypotenuse, opposite the right
angle. `α` is the angle opposite `a`; `β` is the angle opposite `b`.)

### Modes (the `mode` input — which two sides are known)
| mode      | known inputs | solves for |
|-----------|--------------|-----------|
| `legs`    | `a`, `b`     | `c = √(a² + b²)` (hypotenuse) |
| `leg_hyp` | `a`, `c`     | `b = √(c² − a²)` (the other leg) |

_In `leg_hyp` mode the hypotenuse `c` must be **strictly greater than** the known leg `a` (else no
real triangle)._

### Formula (authoritative — Pythagorean + trig, confirmed against the Source)
With both legs `a`, `b` and hypotenuse `c` known (after solving for the missing side):
```
c          = √(a² + b²)                 # legs mode
b          = √(c² − a²)                 # leg_hyp mode
area       = ½ · a · b
perimeter  = a + b + c
altitude   = (a · b) / c                # altitude to the hypotenuse
α (alpha)  = atan(a / b)  in degrees     # angle opposite leg a
β (beta)   = atan(b / a)  in degrees     # angle opposite leg b   (= 90 − α)
```

## Inputs
| name | type    | rules                                                                       |
|------|---------|-----------------------------------------------------------------------------|
| mode | string  | presence, inclusion in `legs`, `leg_hyp`                                     |
| a    | decimal | presence, numericality (greater than 0)  — leg `a`, required in both modes   |
| b    | decimal | numericality (greater than 0); required when `mode` = `legs`                 |
| c    | decimal | numericality (greater than 0); required when `mode` = `leg_hyp`; must be > a |

_Each mode requires exactly the two sides it is **given** (`a`+`b` for `legs`; `a`+`c` for
`leg_hyp`); the side it solves for is left blank._

## Outputs
| key       | meaning                                                  |
|-----------|----------------------------------------------------------|
| mode      | echo of the solve-from mode                              |
| a         | leg a (given), number string                            |
| b         | leg b (given or solved)                                  |
| c         | hypotenuse (given or solved)                            |
| alpha     | angle opposite a, in degrees                            |
| beta      | angle opposite b, in degrees                            |
| area      | ½ · a · b                                               |
| perimeter | a + b + c                                               |
| altitude  | (a · b) / c, altitude to the hypotenuse                  |

## Reference values
_PM-computed deterministically (Pythagorean + `atan`); the backend agent must reproduce them exactly.
Lengths/area/perimeter and angles are displayed to **6 decimal places** (half-up); see Notes._

| mode      | a | b | c  | (solved)        | alpha     | beta      | area      | perimeter | altitude  |
|-----------|---|---|----|-----------------|-----------|-----------|-----------|-----------|-----------|
| `legs`    | 3 | 4 | —  | c = 5.000000    | 36.869898 | 53.130102 | 6.000000  | 12.000000 | 2.400000  |
| `legs`    | 5 | 12| —  | c = 13.000000   | 22.619865 | 67.380135 | 30.000000 | 30.000000 | 4.615385  |
| `legs`    | 1 | 1 | —  | c = 1.414214    | 45.000000 | 45.000000 | 0.500000  | 3.414214  | 0.707107  |
| `leg_hyp` | 6 | — | 10 | b = 8.000000    | 36.869898 | 53.130102 | 24.000000 | 24.000000 | 4.800000  |

_Worked anchor (`legs`, a=3 b=4): c = √(9+16) = **5**; area = ½·3·4 = **6**; perimeter = 3+4+5 = **12**;
altitude = (3·4)/5 = **2.4**; α = atan(3/4) = **36.869898°**, β = atan(4/3) = **53.130102°** (α+β = 90°).
`leg_hyp` anchor (a=6, c=10): b = √(100−36) = **8**, then the 6-8-10 triangle (a 3-4-5 scaled ×2) gives
the same angles and altitude (6·8)/10 = **4.8**._

### Edge / validation cases
| inputs | expected |
|--------|----------|
| `mode=legs`, a=0 | invalid (greater than 0) |
| `mode=legs`, b blank | invalid (b required for legs mode) |
| `mode=leg_hyp`, a=5, c=5 | invalid (hypotenuse must be > leg) |
| `mode=leg_hyp`, a=8, c=6 | invalid (hypotenuse must be > leg) |
| `mode=leg_hyp`, c blank | invalid (c required for leg_hyp mode) |
| `mode=xyz` | invalid (not in inclusion list) |
| `mode=legs`, a="x" | invalid (Base numeric guard rejects non-numeric) |

## Notes
- **Mode picker (`DESIGN.md §4`):** `mode` is a single-select posted as `inputs[mode]` via a native
  radio `<fieldset>`. Two modes — "Two legs (a, b)" / "Leg & hypotenuse (a, c)" — read as **multi-word**,
  so per the §4 rule the FE renders the **`.mode-option` option list** (each option's helper names which
  side it solves for). The form shows only the two **given** side fields for the chosen mode.
- Rounding/display: trig/√ computed at `BigDecimal` precision (e.g. `BigMath.atan` / `BigDecimal#sqrt`)
  and outputs **displayed to 6 decimal places** (half-up). Angles in **degrees**. `α + β` must equal
  90° (a useful test invariant).
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
