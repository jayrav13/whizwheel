# Age Calculator — iteration 0004 (new build)

**Kind:** new build (backend + frontend).
**Spec:** issues #81 (`backend`) / #82 (`frontend`) — identical `spec:v1` body.
**Source:** https://www.calculator.net/age-calculator.html
**Pinned agent SHA:** `3f2ac29`.
**Complexity / tags:** 3 — date-math, multi-mode.

What this calculator stresses for the experiment:
- The project's **first date-math** calculator — `:date` ActiveModel attributes, a **leap-aware
  borrowing** algorithm (years/months/days) reproduced exactly from the spec, plus total-unit
  conversions (months/weeks/days/hours).
- **Date validation** as a new failure surface: reject unparseable dates (`2023-02-30`), reject
  `birth_date` after `end_date`, and **default `end_date` to today** — with the reference-value
  tests passing an explicit `end_date` for determinism and the default-to-today path tested under a
  stubbed clock (no today-dependent reference row).
- Despite the `multi-mode` tag, there is **no input mode picker** (the tag is about the multiple
  output representations) — a second control case for not over-applying the picker rule.

**Build status:** _pending._

---

## Backend (#81)
_— pending build. **Watch:** leap-aware borrow of the month preceding the **end** month (the
`2020-02-29 → 2024-02-28` row is the guard); a stubbed-clock test for the today default._

## Frontend (#82)
_— pending build. **Watch:** native date inputs; label-based date-validation errors._

## Misses → agent-change candidates
_— pending._
