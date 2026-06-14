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

**Build status:** ✅ regenerated & merged — **BE [#94](https://github.com/jayrav13/whizwheel/pull/94)** (no `Closes`) · **FE [#99](https://github.com/jayrav13/whizwheel/pull/99)** (no `Closes`).

---

## Backend regen (#94)
Regenerated from spec #30 under `3f2ac29`. Math unchanged at this SHA — a near-no-op as expected
(multi-mode dispatch + §10 precision preserved). Reference-value table and the 100% gate held.

## Frontend regen (#99) — **A/B verdict: PASS**
From spec #31 alone, the FE agent **independently reached for the correct pickers, unprompted:**
the **5-multi-word main mode → `.mode-option` option list**, and the **2-short Increase|Decrease
toggle → segmented control**. This reproduces exactly what the iteration-0003 *post-hoc* sweep
(PR #66) had to be hand-driven to produce. The mode-picker rule, now pinned in the agent set,
is **self-applying** — no human flagged a scrunched control this time.

## Delta vs. iteration-0003 version
**Rendered-equivalent.** The page came out matching the PR #66 result (correct picker elements,
DESIGN §4 spacing) with no hand-tweak — the diff is the clean A/B evidence that the rule survives
regeneration from spec alone.
