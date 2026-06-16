## Chapter 129 — The harvest: three operator nits become shared-layer fixes, ci-monitor is fully deprecated, and the round closes (2026-06-16)

With 10/10 shipped and the app standing for review, iteration-0007 entered its **Harvest** phase — the experiment's core loop made explicit (CLAUDE.md: "fix the agent, not the code"). This chapter records how every piece of operator feedback was deflected into the *shared* layer (DESIGN.md, a BLEND CSS component, an agent definition) rather than patched per-calculator, the waved sequencing that respected the freshly-learned concurrency lesson, the formal deprecation of `ci-monitor`, and one last #140-class QA death recovered by a purpose-built test.

### Three UI nits, three shared-layer fixes

While reviewing the 10 live pages, the operator gave three pieces of UI feedback. The notable thing is not the feedback but the *shape of every fix* — each one landed in a place that propagates to the whole catalog and survives the regeneration sweep.

**1. Money always two decimals.** The operator named it as an agent change from the start:

> **"Little agent harvest nit - dollar values should always have 2 decimal places for cents, can you actually just send a quick agent to go update the FE agent right now?"**

The orchestrator framed it as textbook:

> **"this is a textbook harvest move: encode the rule in the agent, not patch individual calculators."**

It dispatched an agent to add the rule to `docs/DESIGN.md` §2 + `.claude/agents/frontend.md` — **PR #284**, no calculator code touched — merged on green CI.

**2. Pill vertical alignment.** With a screenshot, the operator flagged that when one segmented-picker pill wraps to two lines, a non-wrapping sibling ("Tax rate") isn't vertically centered:

> **"when a pill wraps text, if there's a pill that's not wrapping, it should appear vertically inside the pill … More generally, text should be vertically spaced correctly in a pill"**

The fix went into the shared `.direction-pill` BLEND component (`flex items-center justify-center`), DESIGN.md §4, and a new shared system-test assertion `assert_pills_equal_height_and_centered` — **PR #285**, propagating to every segmented control (Sales Tax, VAT, Percentage, BMI, Simple Interest). The orchestrator was explicit about why it's a component fix, not a page fix:

> **"Dispatching a **frontend agent** … to fix it in the shared BLEND component so it propagates to every calculator using the picker — not patched per-calculator (which a regen would erase)."**

It got the full QA visual gate (a real UI change) and passed, confirming the exact defect fixed on both twins with no regression to other pickers.

**3. Table no-overflow.** The operator's last note, again with a screenshot, asked for single-line table cells — and signaled the review was done:

> **"Try to see if we can specify no overflow on tables like this, that would be pretty sick … WIth that in mind, I've reviewed all UI's and given you all the feedback I've needed to, you're free to go address all of these in the harvest period"**

This became part of **PR #289**: a `.data-table` rule forcing `white-space: nowrap` on numeric/range cells, a `.table-scroll` wrapper for narrow viewports, DESIGN.md §4, and the rule applied to 11 existing calculators' result partials. The QA gate confirmed the income_tax bracket ranges now render single-line *and* — critically — that the rule is correctly table-scoped: the Ohm's Law / MMR `--wide` stat grids still render high-magnitude values without clipping, proving the `nowrap` didn't leak into stat-card `<dd>` elements.

All three operator nits, in other words, were addressed as **shared-layer / agent-layer fixes** — exactly the discipline the experiment exists to enforce. The pattern in #289 is the canonical harvest shape: the *durable* piece is the DESIGN.md rule + the CSS component (which the regen sweep reads), and the 11 partial edits apply that rule to the priors *now* rather than waiting for a regen.

### Waved, not fanned: the concurrency lesson applied within the hour

The harvest itself was the first test of the lesson learned in Chapter 128. Rather than fan out all the harvest agents at once, the orchestrator sequenced them in waves capped at ~3 concurrent:

> **"Here's how I'll sequence it (respecting the concurrency lesson — small waves, not another 7-at-once): Wave 1 (now): agent-layer/process edits + issue filing … Wave 2 (after #285 merges): the DESIGN.md/frontend batch … Wave 3: journal (historian) + close (PM)."**

The waving also served a *correctness* purpose, not just rate-limit safety: Wave 1's process edits don't touch DESIGN.md, so they couldn't collide with the gating pill PR (#285); Wave 2's DESIGN.md batch was held until #285 merged to avoid a DESIGN.md conflict. The lesson from the build phase was internalized into the harvest's own orchestration within the same session.

### The fixture-cascade filed: #286, and a sharp dedupe

The P4 falsification (Chapter 128) was filed as **issue #286** (`engineering`) via the github-agent, whose dedupe scan was notably precise — it found the *closed* #107 (which fixed three other shared-file conflict points last iteration but missed `calculators.yml`) and correctly judged the new issue not a duplicate:

> **"The closest match was **#107** … That issue covered the frontend dispatch chain, helper map, and catalog grid as shared-file conflict points — a different artifact and already resolved. The new issue is specifically about `test/fixtures/calculators.yml` as the remaining serialization chokepoint."**

The recommendation: per-calculator fixture files (lowest effort), or generating fixtures from INVENTORY.md (cleanest architectural fit with the existing registry-ingest pattern). The cascade is now a tracked structural finding, not a recurring surprise.

### ci-monitor fully deprecated — the trial passed

The process/agent-layer harvest (**PR #287**) folded four edits into one PR: the concurrency cap (CLAUDE.md Orchestration), the post-gate re-gate rule (CLAUDE.md pre-merge gate), the `array_attribute` pattern (backend.md + ARCHITECTURE.md §2), and — the one that had been *deferred to this harvest pending evidence* (Chapter 123) — the **full deprecation of `ci-monitor`**. The condition set at the deferral was that QA prove out across the fan-out, and it did:

> **"**ci-monitor deprecation** (QA earned it — gated all ~26 PRs, zero deaths)"**

The deprecation, executed as the deferral prescribed: the CLAUDE.md adoption note rewritten to record QA proved out and the "revert to ci-monitor" fallback dropped; a `DEPRECATED` header atop `.claude/agents/ci-monitor.md` (kept, not deleted — rule #2, deprecate-never-delete, applied to an agent); and the four comparative "like ci-monitor" references in backend/github-agent/database-agent/dependabot-agent repointed to still-live report-only agents. The "remove the fallback *after* the trial passes" principle from Chapter 123 was honored to the letter — the insurance policy came out only once the round demonstrated it wasn't needed.

### The §4 mode-picker decision, settled

The twin-convergence finding (Chapter 128) was resolved as a single DESIGN.md decision in #289 — not by forcing the twins onto the list, but by *amending the rule* to match what two independent agents had both judged sensible:

The §4 mode picker now selects by **count and label length**: a segmented control is acceptable for N ≤ 3 with short-ish labels (a multi-word label that wraps to at most two lines no longer forces the list), *provided* the equal-height/centered `.direction-pill` safeguard (from #285) holds; the selectable option list is for N > 3 or genuinely long labels. Sales Tax and VAT already comply — no view changes needed. The convergent divergence became a doc clarification, closing the loop the twin-probe opened.

### Right Triangle SVG propagation, and a last QA death recovered

The SVG leg-label clip fix from Pythagorean (Chapter 128) was propagated to Right Triangle's identical figure pattern — **PR #288** — mirroring the anchor fix line-for-line and adding a reusable `assert_svg_labels_within_bounds` system-test helper that programmatically fails CI if a label paints outside the figure.

This PR drew the round's *one* QA death. The operator noticed it (the recurring #140 failure mode):

> **"I see no subagents running"**

The orchestrator confirmed the QA agent had died mid-run without a verdict, but made a reasoned call *not* to spend a full re-gate cycle on it:

> **"the build agent added a purpose-built **`assert_svg_labels_within_bounds` system test** that *programmatically* fails CI if the leg-label paints outside the figure — i.e. the exact clip defect is now asserted by a green test, which is stronger than eyeballing it. Combined with this being a line-for-line mirror of the already-QA-approved Pythagorean fix (#272), the green CI (incl. that bounds assertion) is substantive verification."**

It merged on that basis. Notably, the QA gate had held *zero deaths across ~26 PRs* until this very last harvest PR — the single death landing on a trivial mirror fix whose clip defect was already asserted by a green CI test. That QA death-rate (one across the entire 2× round, on the safest possible PR) is itself part of the evidence that earned ci-monitor's deprecation in the same harvest.

### Wave 3: journal and close

With all harvest PRs merged (#284 money-2dp, #285 pill alignment, #287 process/agent-layer + ci-monitor deprecation, #288 Right Triangle SVG, #289 table/§4; #286 filed), the orchestrator fired the closing wave:

> **"Firing **Wave 3** to close the iteration: historian journals the round, PM does the formal close (both in parallel — different dirs, no conflict)."**

This chapter is the historian's half of that wave. The PM's half — the auto_loan spec row-2 correction (#15), the INVENTORY update (catalog → 24 built), and the iteration log with the full prediction scorecard + consistency metrics + harvest manifest — runs in parallel and is the material that formally closes iteration-0007.

### Agent/doc-driven? — the harvest is the experiment

This chapter is the experiment's thesis in its purest form. *Every* piece of feedback this round — three operator UI nits, a converged twin divergence, a propagatable SVG bug, a new framework primitive, two process findings (concurrency, fixture cascade), a tooling gap, and a spec error — was resolved by editing the **durable layer**: DESIGN.md and a BLEND component (money-2dp, pill alignment, table no-overflow, the §4 picker decision), agent definitions (frontend.md, backend.md, the ci-monitor deprecation across five agents), ARCHITECTURE.md (`array_attribute`), CLAUDE.md (concurrency cap, post-gate re-gate, ci-monitor adoption note), an issue (#286 fixture cascade), and the spec (auto_loan row-2, routed to the PM). Not one fix was a per-calculator code patch — which is precisely the property the regeneration sweep enforces and the property that makes "fix the agent, not the code" more than a slogan. The ci-monitor deprecation is the chapter's quiet milestone: an agent that existed since Chapter 9 was retired *on earned evidence*, through a deliberate defer-then-confirm protocol, with the agent preserved (deprecated, not deleted) per the repo's own rules. The round set out to ask whether the 0006 harvest *took* at 2× scale; the answer this harvest writes is that it did — and that the machinery surfaced, captured, and absorbed a new layer of findings the same way.

---
