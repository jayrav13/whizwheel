# Percentage — iteration 0004 (regeneration sweep — separate PR)

**Kind:** regeneration (regenerate-from-spec, **not** refactor prior code). Ships in its **own PR**,
distinct from the new-build PRs (human directive).
**Spec:** issues #30 (`backend`) / #31 (`frontend`) — unchanged `spec:v1` body (regen reuses the
existing spec; no new issue).
**Source:** https://www.calculator.net/percent-calculator.html
**Pinned agent SHA:** `3f2ac29`.
**Complexity / tags:** 3 — multi-mode, multi-input.

**Why this regen matters (the A/B):** In iteration 0003 Percentage's pickers were converted by an
explicit post-hoc sweep (PR #66: main mode → option list, Increase|Decrease → segmented). The
mode-picker rule is now in the **pinned** agent set. The question: regenerating from spec #31 alone
under `3f2ac29`, does the FE agent **independently** land the **option list** for the 5-multi-word
main mode and the **segmented control** for the 2-short Increase|Decrease toggle — with no human
prompt? That is the clean A/B the 0003 logs deferred.

**Build status:** _pending regen (separate PR)._

---

## Backend regen (#30)
_— pending. Math unchanged at this SHA; expected near-no-op (multi-mode dispatch + §10 precision)._

## Frontend regen (#31)
_— pending. **The A/B watch:** correct pickers reproduced unprompted (option list + segmented)?_

## Delta vs. iteration-0003 version
_— pending (diff vs. PR #66 page)._
