# BMI Calculator — iteration 0003 (new build)

**Kind:** new build (backend + frontend).
**Spec:** issues #52 (`backend`) / #53 (`frontend`) — identical `spec:v1` body.
**Source:** https://www.calculator.net/bmi-calculator.html
**Pinned agent SHA:** `0ca4a02`.
**Complexity / tags:** 2 — multi-input, health, unit-conversion.

What this calculator stresses for the experiment:
- A **unit-system mode** (`us` vs `metric`) where the mode changes the *meaning* of the
  `weight`/`height` inputs (and the `703 ×` factor), not just which formula branch runs.
- A **derived text output** (`category`, the WHO band) returned alongside the numeric `bmi` —
  the first calculator with a non-numeric result key.

**Build status:** _(pending — populate when BE/FE PRs land)_

---

## Backend (#52)

_Accrue here: what the backend agent produced, whether the reference-value table reproduced
exactly (incl. the cross-mode 23.0 consistency check and the band boundaries), validation
handling, what missed, and what agent-definition change any miss suggests._

## Frontend (#53)

_Accrue here: the page produced, the unit-system mode UI, how the `category` text output is
surfaced next to the numeric BMI, the screenshot self-review against DESIGN.md, what missed,
and the suggested agent change._

## Misses → agent-change candidates

_(running list — these are what point at the next agent edit / iteration close)_
