# Tip Calculator — iteration 0004 (new build)

**Kind:** new build (backend + frontend).
**Spec:** issues #75 (`backend`) / #76 (`frontend`) — identical `spec:v1` body.
**Source:** https://www.calculator.net/tip-calculator.html
**Pinned agent SHA:** `3f2ac29`.
**Complexity / tags:** 2 — multi-input.

What this calculator stresses for the experiment:
- The **first per-person split** — secondary figures (`tip_per_person`, `total_per_person`)
  derived from the primary tip/total by dividing by `people` (default 1).
- A **plain multi-input form with no mode picker** — a control case: confirms the agents don't
  over-apply the new mode-picker rule where there is no mode to pick.
- A subtle rounding note: per-person figures derive from the **raw** tip/total then round for
  display, so they need not sum exactly to the whole-party figures.

**Build status:** _pending._

---

## Backend (#75)
_— pending build._

## Frontend (#76)
_— pending build._

## Misses → agent-change candidates
_— pending._
