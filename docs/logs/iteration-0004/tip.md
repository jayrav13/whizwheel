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

**Build status:** ✅ built & merged — **BE [#91](https://github.com/jayrav13/whizwheel/pull/91)** (`Closes #75`) · **FE [#106](https://github.com/jayrav13/whizwheel/pull/106)** (`Closes #76`).

---

## Backend (#91)
Built from spec #75 under `3f2ac29`. Per-person split correct (tip/total ÷ `people`, default 1);
the raw-then-round-for-display discipline (§10) handled so per-person figures need not sum exactly.
**Control case held: no mode picker invented** where there is no mode to pick.

## Frontend (#106)
Built from spec #76. Plain multi-input form, no spurious picker — confirms the agents don't
over-apply the mode-picker rule. Shipped last of the new-build FE PRs because of the serial FE merge
pipeline (shared-file central registration; see iteration README process note).

## Misses → agent-change candidates
- **#109 (`agents`) — integer coercion defeats `only_integer`.** `people` is `:integer`; ActiveModel
  casts a fractional input (e.g. `2.7`) to `2` *before* `numericality: only_integer` can reject it,
  so fractional party sizes are silently truncated rather than refused. Filed for a future agentic
  batch fix (same root cause as Amortization `years`).
