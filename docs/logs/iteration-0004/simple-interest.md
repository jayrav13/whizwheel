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

**Build status:** ✅ built & merged — **BE [#89](https://github.com/jayrav13/whizwheel/pull/89)** (`Closes #77`) · **FE [#103](https://github.com/jayrav13/whizwheel/pull/103)** (`Closes #78`).

---

## Backend (#89)
Built from spec #77 under `3f2ac29`. `I = P · r · t` with the months → years conversion applied
**before** the formula. Reference-value table and 100% gate held.

## Frontend (#103) — **picker-rule generalization: PASS**
The `years`/`months` **unit selector (N=2, short)** came out a **segmented control on the first
build, with no human prompt.** This is the cleanest evidence in the iteration that the mode-picker
rule **generalizes to an unseen calculator** — not just the three it was retrofitted onto in 0003.
Together with the three regen PASSes, it makes the rule **3/3 correct on regen + correct on a fresh
build, with discrimination** (segmented for N≤3/short vs. option-list for N≥4/multi-word).

## Misses → agent-change candidates
- Shares the cross-cutting **#110** non-numeric-coercion issue (numericality not actually enforced;
  `:decimal` casts a non-number to `0` before validation runs) filed at iteration level.
