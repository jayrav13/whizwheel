# Amortization Calculator — iteration 0004 (new build, the stretch)

**Kind:** new build (backend + frontend).
**Spec:** issues #83 (`backend`) / #84 (`frontend`) — identical `spec:v1` body.
**Source:** https://www.calculator.net/amortization-calculator.html
**Pinned agent SHA:** `3f2ac29`.
**Complexity / tags:** 4 — multi-input, tabular-output, charts.

What this calculator stresses for the experiment (the iteration's stretch):
- The project's **first `tabular-output`** — a full month-by-month `schedule` array (payment /
  interest / principal / balance per month) emitted as structured rows over the §4 envelope, with
  the **final payment absorbing rounding** so the last balance lands exactly on `0.00`.
- The project's **first `charts`** — a `chart` envelope key carrying the donut series (principal vs.
  total interest) + a balance-over-time curve, rendered **CSS-only** to DESIGN §4 ("Charts"). Tests
  the BE/FE seam under a rich result: the **backend owns all numbers**, the FE only renders.
- Schedule reconciliation: `schedule.length == number_of_payments`, `Σ interest == total_interest`,
  `Σ payment == total_paid`, final-row balance `0.00` — the schedule-shape assertions in the spec.

**Build status:** ✅ built & merged — **BE [#97](https://github.com/jayrav13/whizwheel/pull/97)** (`Closes #83`) · **FE [#105](https://github.com/jayrav13/whizwheel/pull/105)** (`Closes #84`).

---

## Backend (#97) — **first tabular-output: PASS**
Built from spec #83 under `3f2ac29`. Emitted a full month-by-month `schedule` array
(payment/interest/principal/balance per month) with the **final payment absorbing rounding** so the
last balance lands exactly on `0.00`. The reconciliations held: `schedule.length ==
number_of_payments`, `Σ interest == total_interest`, `Σ payment == total_paid`, plus the `r = 0`
zero-rate edge (`12000 @ 0%/1y`). The month-1 row + totals anchors reproduced exactly. **All numbers
owned by the backend** — the BE/FE seam did not leak math into the view. 100% gate held.

## Frontend (#105) — **first charts: PASS**
Built from spec #84. First `tabular-output` + `charts` page: a `tabular-nums` schedule **data table**
(DESIGN §4 — thin rules, right-aligned, total row) plus a **CSS `conic-gradient` donut** (principal
vs. total interest) and an **SVG balance-over-time curve**, rendered from the `chart` envelope key
with no math in the view. The stretch landed in one build.

## Misses → agent-change candidates
- **#109 (`agents`)** — `years` is `:integer` and shares Tip's `only_integer`-defeated-by-coercion
  bug (fractional term silently truncated).
- **#112 (`engineering`)** — the donut/table surfaced an undecided **financial semantic-color**
  question (interest green-in-donut vs. coral-in-table) + the card eyebrow color (faint vs. §2
  green); filed to settle in DESIGN.md.
- This page is the concrete driver behind **#107** (FE de-facto central registration → serial merge
  pipeline) — its rich shared-file touch made the new-build FE merge ordering matter.
