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

**Build status:** ✅ built & merged — **BE [#95](https://github.com/jayrav13/whizwheel/pull/95)** (`Closes #81`) · **FE [#104](https://github.com/jayrav13/whizwheel/pull/104)** (`Closes #82`).

---

## Backend (#95) — **first date-math: PASS**
Built from spec #81 under `3f2ac29`. `:date` ActiveModel attributes; the **leap-aware borrowing**
algorithm (years/months/days) reproduced the spec exactly — including the `2020-02-29 → 2024-02-28`
guard row — plus the total-unit conversions. Date validation works as a new failure surface
(unparseable dates and `birth_date` after `end_date` are rejected), and the **default-end_date-to-today**
path is tested under a stubbed clock (no today-dependent reference row). 100% gate held.

## Frontend (#104)
Built from spec #82. Native date inputs; label-based date-validation errors render. **Control case
held: despite the `multi-mode` tag (which refers to the multiple output representations, not an input
mode), the agent did not invent an input picker** — a second confirmation alongside Tip that the
mode-picker rule is not over-applied.

## Misses → agent-change candidates
_None calculator-specific. Cross-cutting process findings (#86, #98) surfaced around this build's
merge/worktree handling — recorded at iteration level._
