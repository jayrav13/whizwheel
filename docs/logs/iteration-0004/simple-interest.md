# Simple Interest Calculator — iteration 0004 (new build)

**Kind:** new build (backend + frontend).
**Spec:** issues #77 (`backend`) / #78 (`frontend`) — identical `spec:v1` body.
**Source:** https://www.calculator.net/simple-interest-calculator.html
**Pinned agent SHA:** `3f2ac29`.
**Complexity / tags:** 2 — multi-input.

What this calculator stresses for the experiment:
- The **financial primitive** `I = P · r · t` — the simplest financial formula, a clean base for
  the compound/amortizing calculators above it.
- The **picker rule's cleanest fresh test.** The `years`/`months` **unit selector** (N=2, short
  labels) is a brand-new picker on a never-seen calculator; per `DESIGN.md §4` it should come out a
  **segmented control** on the first build with **no human prompt** — the strongest evidence the
  mode-picker rule generalizes beyond the three calculators it was retrofitted onto in 0003.
- A months → years conversion that must happen **before** the formula.

**Build status:** _pending._

---

## Backend (#77)
_— pending build._

## Frontend (#78)
_— pending build. **Watch:** does the unit selector render as a segmented control unprompted?_

## Misses → agent-change candidates
_— pending._
