# Ohms Law — iteration 0004 (regeneration sweep — separate PR)

**Kind:** regeneration (regenerate-from-spec, **not** refactor prior code). Ships in its **own PR**,
distinct from the new-build PRs (human directive).
**Spec:** issues #54 (`backend`) / #55 (`frontend`) — unchanged `spec:v1` body (regen reuses the
existing spec; no new issue).
**Source:** https://www.calculator.net/ohms-law-calculator.html
**Pinned agent SHA:** `3f2ac29`.
**Complexity / tags:** 2 — multi-input, multi-mode, physics.

**Why this regen matters (the A/B):** Ohms was the **prototype** that proved the `.mode-option`
option list in iteration 0003 (PR #63), before the rule was codified (PR #64). With the rule now
pinned, the question: regenerating from spec #55 alone, does the FE agent land the **6-mode
option list** unprompted — reproducing the prototype that is now the rule? Plus re-confirmation that
the six-mode guarded solver (div-by-zero → 422, valid-zero success, `rp` square-root domain, all
four quantities returned) survives the BE regen at the 100% gate.

**Build status:** ✅ regenerated & merged — **BE [#96](https://github.com/jayrav13/whizwheel/pull/96)** (no `Closes`) · **FE [#100](https://github.com/jayrav13/whizwheel/pull/100)** (no `Closes`).

---

## Backend regen (#96)
Regenerated from spec #54 under `3f2ac29`. The six-mode guarded solver survived the rebuild:
div-by-zero → 422 vs. valid-zero success distinction held, the `rp` square-root domain guard held,
and all four quantities are returned. 100% gate held.

## Frontend regen (#100) — **A/B verdict: PASS**
From spec #55 alone, the FE agent reproduced the **6 multi-word modes as a `.mode-option` option
list** unprompted — i.e. it independently arrived at the very prototype (PR #63) that *became* the
rule (PR #64). The N≥4/multi-word → option-list branch self-applies.

## Delta vs. iteration-0003 version
**Rendered-equivalent** to the PR #60/#63 page — correct option-list picker, guarded solver intact.
