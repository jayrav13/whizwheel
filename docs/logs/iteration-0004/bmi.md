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

**Build status:** ✅ regenerated & merged — **BE [#92](https://github.com/jayrav13/whizwheel/pull/92)** (no `Closes`) · **FE [#101](https://github.com/jayrav13/whizwheel/pull/101)** (no `Closes`).

---

## Backend regen (#92)
Regenerated from spec #52 under `3f2ac29`. The raw-vs-display band seam survived the rebuild
(compute at full precision; round only for display per §10) and the derived-text WHO `category`
band reproduced from spec. 100% gate held.

## Frontend regen (#101) — **A/B verdict: PASS**
From spec #53 alone, the FE agent landed the **US|Metric selector as a segmented control (N=2,
short)** **on the first try, unprompted** — it never re-introduced the scrunched pill row that, in
iteration 0003, was the very thing a human had to flag (and that PR #65 then converted). This is the
strongest single data point that the rule is durable: the calculator that *surfaced* the missing
element-choice axis now self-corrects from spec.

## Delta vs. iteration-0003 version
**Rendered-equivalent** to the PR #62/#65 page — correct segmented control, no scrunch, derived
category band intact. The miss that opened the mode-picker investigation does not recur.
