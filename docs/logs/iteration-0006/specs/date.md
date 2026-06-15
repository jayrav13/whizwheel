<!-- spec:v1 -->
**Category:** Other
**Source:** https://www.calculator.net/date-calculator.html
**Complexity:** 3
**Tags:** date-math, multi-mode
**Card description:** Days between two dates, or add/subtract years, months, weeks and days from a date.

## Intent
A two-mode date calculator (confirmed against the Source's two tabs):
1. **`difference`** — the number of days between two dates, with a calendar-aware
   **years / months / days** breakdown and a weeks-and-days view.
2. **`add_subtract`** — a start date with a signed offset of years / months / weeks / days **added or
   subtracted**, yielding the resulting date.

### `difference` mode (authoritative)
Given `start_date` and `end_date` (order-independent — the calculator reports the magnitude):
```
total_days   = |end_date − start_date|          # exact day count
total_weeks  = total_days // 7  (remainder days = total_days % 7)
```
The **Y/M/D breakdown** uses calendar-aware borrowing (the Age-calculator algorithm), computed from
the earlier date to the later date:
```
years  = Δ years
months = Δ months   (borrow 12 months from years if negative)
days   = Δ days     (borrow the days-in-the-preceding-month if negative, then borrow a month)
```

### `add_subtract` mode (authoritative)
Given `start_date`, an operation `operation ∈ {add, subtract}`, and integer offsets `years`,
`months`, `weeks`, `days` (any may be 0):
```
sign = (operation == add) ? +1 : −1
# apply years then months (calendar-aware: clamp an overflowed day to the month's last day,
#   e.g. Jan 31 + 1 month → Feb 28/29), then apply weeks (×7) and days as plain day arithmetic.
result_date = start_date  shifted by  sign × (years, months)  then  sign × (weeks·7 + days) days
```
Month/year arithmetic is calendar-aware with **end-of-month clamping**; week/day arithmetic is exact
day counting (leap days included).

## Inputs
| name       | type    | rules                                                                                  |
|------------|---------|----------------------------------------------------------------------------------------|
| mode       | string  | presence, inclusion in `difference`, `add_subtract`                                     |
| start_date | date    | presence (the base date in both modes)                                                  |
| end_date   | date    | required when `mode` = `difference`                                                     |
| operation  | string  | inclusion in `add`, `subtract`; required when `mode` = `add_subtract`                   |
| years      | integer | numericality (greater than or equal to 0); used in `add_subtract` (default 0)           |
| months     | integer | numericality (greater than or equal to 0); used in `add_subtract` (default 0)           |
| weeks      | integer | numericality (greater than or equal to 0); used in `add_subtract` (default 0)           |
| days       | integer | numericality (greater than or equal to 0); used in `add_subtract` (default 0)           |

_The offset fields are unsigned magnitudes; `operation` supplies the sign. `:date` inputs are parsed
as real calendar dates (an invalid date like `2023-02-30` is a validation error)._

## Outputs
### `difference` mode
| key          | meaning                                                       |
|--------------|---------------------------------------------------------------|
| mode         | `difference`                                                  |
| total_days   | exact day count between the two dates (integer, non-negative) |
| years        | calendar-aware Y component of the breakdown                   |
| months       | calendar-aware M component                                    |
| days         | calendar-aware D component                                    |
| total_weeks  | total_days // 7                                              |
| remainder_days | total_days % 7                                             |

### `add_subtract` mode
| key         | meaning                                              |
|-------------|------------------------------------------------------|
| mode        | `add_subtract`                                       |
| result_date | the resulting date (ISO `YYYY-MM-DD` string)         |
| start_date  | echo of the base date                                |
| operation   | echo of `add` / `subtract`                           |

## Reference values
_PM-computed deterministically (calendar-aware borrowing + day arithmetic, leap years included); the
backend agent must reproduce them exactly._

### `difference` mode
| start_date | end_date   | total_days | years | months | days | total_weeks | remainder_days |
|------------|------------|------------|-------|--------|------|-------------|----------------|
| 2023-01-15 | 2025-03-20 | 795        | 2     | 2      | 5    | 113         | 4              |
| 2024-01-01 | 2024-12-31 | 365        | 0     | 11     | 30   | 52          | 1              |
| 2020-02-28 | 2020-03-01 | 2          | 0     | 0      | 2    | 0           | 2              |

_Worked anchor (`2023-01-15 → 2025-03-20`): total_days = **795**; Y/M/D = 2 years, 2 months, 5 days
(from 2023-01-15: +2y → 2025-01-15, +2m → 2025-03-15, +5d → 2025-03-20); 795 // 7 = **113** weeks,
795 % 7 = **4** days. The leap-spanning `2020-02-28 → 2020-03-01` is **2** days (Feb 29 exists in 2020)._

### `add_subtract` mode
| start_date | operation  | years | months | weeks | days | result_date |
|------------|------------|-------|--------|-------|------|-------------|
| 2024-01-01 | `add`      | 0     | 0      | 0     | 30   | 2024-01-31  |
| 2024-02-28 | `add`      | 0     | 0      | 0     | 1    | 2024-02-29  |
| 2024-01-01 | `subtract` | 0     | 0      | 0     | 1    | 2023-12-31  |
| 2023-01-31 | `add`      | 0     | 1      | 0     | 0    | 2023-02-28  |
| 2020-02-29 | `add`      | 1     | 0      | 0     | 0    | 2021-02-28  |

_Worked anchors: `2024-01-01 + 30 days` = **2024-01-31**; `2024-02-28 + 1 day` = **2024-02-29** (2024 is
a leap year); `2024-01-01 − 1 day` = **2023-12-31**. End-of-month clamping: `2023-01-31 + 1 month` =
**2023-02-28** (Feb has no 31st); `2020-02-29 + 1 year` = **2021-02-28** (2021 has no Feb 29)._

### Edge / validation cases
| inputs | expected |
|--------|----------|
| `mode=difference`, end_date blank | invalid (end_date required for difference) |
| `mode=difference`, start after end | valid — magnitude reported (total_days non-negative, Y/M/D from earlier→later) |
| `mode=add_subtract`, operation blank | invalid (operation required) |
| `mode=add_subtract`, all offsets 0 | valid — result_date == start_date |
| start_date = 2023-02-30 | invalid (not a real date) |
| `mode=add_subtract`, months = 1.5 | invalid (fractional integer — Base numeric guard rejects) |
| `mode=zzz` | invalid (not in inclusion list) |

## Notes
- **Mode picker (`DESIGN.md §4`):** `mode` is a single-select posted as `inputs[mode]` via a native
  radio `<fieldset>`. Two modes — "Difference between dates" / "Add or subtract" — read as **multi-word**,
  so per the §4 rule the FE renders the **`.mode-option` option list**; each option's helper names what
  it does. The form shows only the fields relevant to the chosen mode (two dates for `difference`;
  start date + operation + the four offset fields for `add_subtract`). Within `add_subtract`, the
  `operation` (Add / Subtract, N=2 short) is itself a sub-picker → **segmented control** per the rule.
- **No "Today" quick-fill default by silent prefill** — if any date field is offered a Today
  convenience it must be the explicit `DESIGN.md §4` Today button (never auto-prefill); `start_date`
  and `end_date` are primary inputs and may simply be required, with no silent default.
- Rounding/display: dates are exact (no rounding); integer day/week/month/year counts. `result_date`
  is an ISO `YYYY-MM-DD` string. Calendar arithmetic is leap-aware with end-of-month clamping for
  month/year shifts.
- `:integer` offset fields — the `Calculators::Base` numeric guard rejects non-numeric / fractional
  input at the cast seam, so **no `only_integer` workaround is needed**.
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
