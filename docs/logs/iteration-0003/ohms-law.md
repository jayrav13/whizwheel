# Ohms Law Calculator — iteration 0003 (new build)

**Kind:** new build (backend + frontend).
**Spec:** issues #54 (`backend`) / #55 (`frontend`) — identical `spec:v1` body.
**Source:** https://www.calculator.net/ohms-law-calculator.html
**Pinned agent SHA:** `0ca4a02`.
**Complexity / tags:** 2 — multi-input, multi-mode, physics.

What this calculator stresses for the experiment:
- A **six-mode "any two of four"** solver (V/I/R/P) — a broader multi-mode surface than
  Percentage's, with **conditional input presence** (only the two named by `mode` are
  required) and **all four quantities always returned**.
- **Division-by-zero guards** (e.g. `vi` with `current=0`) and one **square-root mode**
  (`rp`). Tests whether the agents handle guarded math and the 100% coverage gate across six
  branches.

**Build status:** _(pending — populate when BE/FE PRs land)_

---

## Backend (#54)

_Accrue here: what the backend agent produced, whether all six modes reproduce the
reference-value table exactly (incl. the cross-mode `12/2/6/24` consistency check via vi/ip/vp,
the `ir,R=0 → V=0,P=0` valid-zero case, and the div-by-zero invalid cases), how it handled the
multi-mode dispatch + the `rp` square root + the coverage gate, what missed, and the suggested
agent change._

## Frontend (#55)

_Accrue here: the page produced, the mode selector UI (six pairs), how it surfaces all four
V/I/R/P outputs while highlighting the two solved, the screenshot self-review against
DESIGN.md, what missed, and the suggested agent change._

## Misses → agent-change candidates

_(running list — these are what point at the next agent edit / iteration close)_
