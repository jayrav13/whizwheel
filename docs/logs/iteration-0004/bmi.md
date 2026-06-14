# BMI — iteration 0004 (regeneration sweep — separate PR)

**Kind:** regeneration (regenerate-from-spec, **not** refactor prior code). Ships in its **own PR**,
distinct from the new-build PRs (human directive).
**Spec:** issues #52 (`backend`) / #53 (`frontend`) — unchanged `spec:v1` body (regen reuses the
existing spec; no new issue).
**Source:** https://www.calculator.net/bmi-calculator.html
**Pinned agent SHA:** `3f2ac29`.
**Complexity / tags:** 2 — multi-input, health, unit-conversion.

**Why this regen matters (the A/B):** In iteration 0003 BMI's US/Metric selector was the calculator
that *surfaced* the missing element-choice axis (scrunched pills), then was converted to a
**segmented control** by PR #65. With the rule now pinned, the question: regenerating from spec #53
alone, does the FE agent land the **segmented control** for US|Metric (N=2, short) **on the first
try, unprompted** — i.e. never re-introduce the scrunched pill row? Plus a re-confirmation that the
derived-text `category` (WHO band) + the raw-vs-display band discipline (§10) survive the rebuild.

**Build status:** _pending regen (separate PR)._

---

## Backend regen (#52)
_— pending. Re-confirm raw-vs-display band seam (24.95 → "25.0" display but stays Normal)._

## Frontend regen (#53)
_— pending. **The A/B watch:** US|Metric reproduced as a segmented control unprompted (no scrunch)?_

## Delta vs. iteration-0003 version
_— pending (diff vs. PRs #62/#65 page)._
