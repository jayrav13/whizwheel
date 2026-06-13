# Calculator Inventory

The full catalog of calculators on [calculator.net](https://www.calculator.net),
maintained idempotently by the PM agent. Re-running a refresh updates this table in
place: new calculators are added, removed ones are marked, and **manually/empirically
corrected complexity and tags are preserved** (not clobbered by fresh hypotheses).

## Complexity scale (1–5)

| Rating | Meaning |
|---|---|
| 1 | Trivial — one input to one output, no real formula. |
| 2 | Basic single formula (e.g. BMI, percentage). |
| 3 | Multiple inputs or selectable modes (e.g. loan payment, body-fat methods). |
| 4 | Iterative or tabular output (e.g. amortization schedule, retirement projection). |
| 5 | Multi-mode + charts + numerical solving (e.g. mortgage with extra payments, scientific). |

Pre-build ratings are **hypotheses**; they get corrected as calculators are actually
built and the logs reveal the truth.

## Tag vocabulary (seed — extensible)

`charts`, `multi-input`, `multi-mode`, `date-math`, `time-math`, `iterative-solve`,
`tabular-output`, `currency`, `unit-conversion`, `statistical`, `randomness`,
`text-output`. Add new tags as calculators warrant; record additions here.

## Catalog

| Calculator | Category | Complexity | Tags | Source |
|---|---|---|---|---|
<!-- Populated by the PM agent via the Inventory capability. -->
