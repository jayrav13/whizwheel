# Percentage — iteration 0002 (regeneration sweep, frontend)

**Kind:** regeneration (frontend only). The first regenerate-from-spec production of an
existing calculator — and the iteration's sole evidence.
**Spec:** issue #31 (`frontend`), the `spec:v1` body.
**Source:** https://www.calculator.net/percent-calculator.html
**Pinned agent SHA:** `1e18ce2` (carries the new DESIGN.md §3 spacing scale).
**PR:** #41 (`feat(ui): regenerate Percentage page (iteration 0002 — spacing scale)`) —
merged to `main` (commit `489bc99`). Does **not** re-close #31 (already closed by PR #35).

This iteration is `n = 0` new builds: it exists only to regenerate the Percentage page with
the improved agent set and measure what the agent change produced. The delta against the
iteration-0001 page (PR #35) is the experiment's first controlled measurement of an
agent-definition change.

---

## The measurement — the regeneration

**What we did.** The FE agent regenerated the Percentage page **from spec #31 + the new
DESIGN.md alone**. Per PR #41, the prior `percentage.*` / `_result.*` / `results/*` / Stimulus
controller / helper were **not read or copied** — they were rebuilt fresh from the spec and
BLEND. This is the regenerate-from-spec discipline working as designed: an independent
production, not a patch of the 0001 page. The human put **zero pixels in the markup** — no
in-flight hand-tweak like the iteration-0001 `gap-2.5` bump (`2ef2315`→`346eda9`). Whatever
spacing the page came out with is purely what the improved DESIGN.md guidance produced.

**The result — visibly roomier mode pills.** The regenerated pills came out on the
**Grouped-wrapping** tier (`gap-x-3 gap-y-4`) with larger chip padding (`px-5 py-2.5`),
clearly breathing across the wrapped rows — distinct, separately-hittable chips rather than
the cramped, bunched cluster of the 0001 baseline. The larger row-gap (`gap-y-4` >
`gap-x-3`) makes the wrapped rows read as a grid, not a clump — exactly the relationship-based
rhythm the new scale prescribes. This is a clear, visible improvement over the 0001 page,
produced from the guidance alone.

**Preserved through the fresh rebuild (the durable fixes held).** Both iteration-0001
remedies that we had pushed *up into DESIGN.md / the controller contract* survived the
independent regeneration:
- **Label-based validation errors** — messages phrased against each field's visible label
  ("Value (V1) can't be blank"), never raw attribute keys. This lives in DESIGN.md §4 +
  `CalculatorsHelper`, so the fresh build reproduced it.
- **The hero-result rendering** — the BLEND hero card (coral left-rule, tabular-nums RESULT)
  came back correctly, with the `_result` partial still dispatching Percentage → its hero and
  any other calculator → a generic key/value hero.

That these survived a from-scratch rebuild is itself confirmation that encoding a fix in the
agent layer (not the page) makes it durable across the sweep — the agent-first rule, working.

---

## The bisect conclusion

Iteration 0001 surfaced **two** candidate levers for the cramped-pills failure:
**(a)** DESIGN.md had no real spacing scale, and **(b)** the FE screenshot self-review had
"no teeth" — it declared the cramped pills "roomy." Iteration 0002 changed **only (a)** (the
spacing scale; `08b83ef` / PR #38) and deliberately held the self-review bar **constant**, to
isolate which lever was binding.

**The result bisects cleanly to DESIGN.md.** With a concrete spacing standard to measure
against, the unchanged self-review correctly judged the roomier pills as good (PR #41's
self-review verdict: the pills "breathe… read as separate targets rather than a tight
cluster") — and the output *was* good. So:

- **Improving DESIGN.md (the spacing scale) was the lever.** Better guidance alone moved the
  output.
- **The FE self-review bar proved adequate once it had a concrete standard to measure
  against.** The "self-review has no teeth" hypothesis (0001 miss (b)) was **NOT** the binding
  constraint this round. The review didn't need more teeth — it needed a ruler. (Giving the
  review explicit spacing teeth remains a *possible* future refinement, but it is no longer
  on the critical path; this result demotes its urgency.)

**Caveat — single stochastic sample.** This is **one** regeneration of **one** page. FE
generation is stochastic; a single roomy result is a **strong signal, not proof**. The honest
read is "the scale moved this regeneration in the right direction," not "the scale
deterministically guarantees good spacing." Repeating the sweep (here and on future
multi-mode pages) would harden the conclusion.

---

## First confirmation of the agent-improvement loop

This is the headline. A change to an **agent reference doc** (DESIGN.md's spacing scale),
**alone** — with no code hand-edited, the prior page not even read — produced **measurably
better output** via the regeneration sweep. That is the experiment's core thesis
(*improve the agent, not the code; the sweep proves it*) **demonstrated end-to-end for the
first time**. Iteration 0001 proved the build loop could *produce* a calculator; iteration
0002 proves the *improvement* loop closes: edit a doc → regenerate from spec → see the
output get better, attributable to the doc change because nothing else moved.

---

## Regeneration variances worth noting (fresh production differs)

A from-scratch regeneration is an independent production, so non-load-bearing details that
aren't pinned by the spec or DESIGN.md drift between versions. Two worth recording:

- **Intro / result copy was rewritten.** The page's prose (intro + result-area copy) came out
  differently worded than the 0001 page. Benign — neither version is "wrong" — but a reminder
  that copy not fixed in the spec is regenerated each sweep.
- **Input placeholders downgraded: helpful hints → "0".** The 0001 page used hint-style
  placeholders ("e.g. 50"); the regen produced bare "0" placeholders. This is a **minor UX
  downgrade** and a **candidate future refinement**: the "e.g." hint pattern isn't captured
  anywhere in DESIGN.md, so the regeneration had nothing telling it to keep it and dropped it.
  The fix, if we want the hint pattern durable, belongs **in DESIGN.md** (a placeholder/hint
  convention) — not in the page, or the next sweep erases it again. Same lesson as the
  spacing scale, in miniature.

These variances are exactly what the sweep is supposed to expose: anything not encoded in the
agent layer is non-durable, and we learn what to encode next by watching what drifts.

---

## Iteration takeaway

Iteration 0002 is the experiment's first **clean win for the agent-improvement loop**: a
DESIGN.md-only change (the spacing scale) regenerated the Percentage page — fresh from spec,
human pixels at zero — into one with **visibly roomier, breathing mode pills**, while the
durable 0001 fixes (label errors, hero result) held through the rebuild. The bisect points at
**DESIGN.md, not the FE self-review**, as the binding lever; the review was adequate once it
had a standard to grade against. The result is a strong single-sample signal, not proof. The
next refinements it surfaces — a placeholder/hint convention in DESIGN.md, and (lower
urgency) optional spacing teeth in the FE self-review — are themselves agent-layer changes,
which is the loop continuing to work.
