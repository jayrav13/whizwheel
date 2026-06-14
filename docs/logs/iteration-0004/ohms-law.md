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

**Build status:** _pending regen (separate PR)._

---

## Backend regen (#54)
_— pending. Re-confirm six-mode dispatch, div-by-zero 422 vs. valid-zero success, `rp` √-domain._

## Frontend regen (#55)
_— pending. **The A/B watch:** the 6 multi-word modes reproduced as a `.mode-option` option list?_

## Delta vs. iteration-0003 version
_— pending (diff vs. PRs #60/#63 page)._
