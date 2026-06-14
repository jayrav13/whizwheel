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

**Build status:** _pending._

---

## Backend (#83)
_— pending build. **Watch:** displayed-payment-driven schedule with the final-row reconciliation;
the `r = 0` zero-rate edge (`12000 @ 0%/1y`); exact reproduction of the month-1 + totals anchors._

## Frontend (#84)
_— pending build. **Watch:** a `tabular-nums` schedule table (DESIGN §4 "Data table" — thin rules,
right-aligned, total row), a CSS `conic-gradient` donut + balance curve from the `chart` key, and a
long-table responsive treatment (scroll/reflow, not overflow). No math in the view._

## Misses → agent-change candidates
_— pending._
