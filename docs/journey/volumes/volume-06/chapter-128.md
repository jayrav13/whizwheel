## Chapter 128 — The frontend wave, a rate-limit that killed seven agents, a clean zero-rebuild recovery, and the prediction scorecard at 10/10 (2026-06-16)

This is the chapter the round was *designed to produce*: the 2× fan-out hitting a real ceiling. With all 10 backends merged, the orchestrator fanned out the frontend builds, dispatching seven heavy Opus agents at once — and tripped a transient server-side rate-limit that killed every one of them mid-run. The recovery that followed is the strongest single piece of "does this work?" evidence in iteration-0007: **every dead agent's work was salvaged, zero calculators were rebuilt.** This chapter also records the P4 falsification (the fixture-conflict cascade), the twin-convergence finding, and the prediction scorecard at 10/10.

### Seven frontends, then silence

The first three frontends (Discount #271, Pythagorean #272, Average Return #273) had already built, gated, and merged earlier — the per-calculator pipeline working exactly as designed, including a clean post-gate-push catch (see below). With the backends all merged, the orchestrator fanned out the remaining seven frontends in two dispatches: Auto Loan, Sales Tax, VAT, then ROI, Income Tax, Personal Loan, House Affordability.

Then the notifications came back not as PRs but as errors:

> **`API Error: Server is temporarily limiting requests (not your usage limit) · Rate limited`**

The orchestrator diagnosed it immediately and named its own mistake:

> **"All the frontend agents died together on the **same transient server-side rate-limit** ('not your usage limit' — a load throttle), and the safety classifier briefly went down too (blocking my Bash calls). This is a clear sign I **over-fanned the concurrency** — 7 heavy Opus frontend agents at once tripped the limit."**

Critically, it knew nothing on the merged line was at risk: all 10 backends + bookkeeping were safely on `main`. And it reasoned about *when* the agents died — ~12 minutes in, at 55–68 tool-uses each — concluding they likely died during their *final return*, after doing most of the work. Rather than hammer the throttled server, it deliberately paused to let the limit drain before resuming.

### The recovery: zero rebuilds

When recovery resumed (the operator nudged it forward with an explicit plan), the orchestrator found the precise truth of what survived. No PRs had opened, but **all seven worktrees existed with work in them** — the agents had built but died before pushing. It triaged each worktree by how far it got:

> **"roi-fe + house-affordability-fe: work **committed** (1 commit each, clean tree) — died during push/PR. I can push + open those PRs myself. … auto-loan, sales-tax, vat, income-tax, personal-loan: 7–8 **uncommitted** files each — nearly complete but died before committing."**

The recovery then unfolded as a sequence of escalating-cheapness salvage moves, *none* requiring a fresh build agent:

1. **Personal Loan** had actually *survived* and opened PR #277 — the earlier worktree check had caught it mid-run.
2. **ROI (#278)** and **House Affordability (#279)** — committed work, pushed and PR'd directly by the orchestrator.
3. **Auto Loan (#280), Sales Tax (#281), VAT (#282), Income Tax (#283)** — uncommitted but complete file sets; the orchestrator committed + pushed them and let **CI's 100%-coverage gate be the validator**:

> **"All four dead worktrees have the **complete frontend file set** … the agents died right after writing everything, just before committing/verifying. I'll commit + push + open PRs for all four (Bash only — zero agents, zero rate-limit risk) and let **CI's 100%-coverage gate + full suite be the validator**. Any that come back red, I rebuild just that one."**

The result, in the orchestrator's own words:

> **"**Recovery complete — all 7 frontend PRs now exist, and I rebuilt nothing from scratch.** Every dead agent's work was salvaged."**

And the validation held: all four recovered PRs (#280–283) passed `test` + the 100% coverage gate, confirming the salvaged-but-unverified work was genuinely complete. The recovery was *deliberately throttled* — gating in pairs, never exceeding ~3 concurrent agents again. (The `SendMessage`-to-resume-a-dead-agent approach was considered and abandoned — the tool wasn't available — and the commit-and-let-CI-validate trick proved both simpler and rate-limit-safe.)

This is the round's marquee finding, and the harvest lesson is concrete: **cap concurrent heavy build agents at ~3–4, not 7.** But the equally important signal is that the *recovery* worked — the worktree-isolation model (each agent's work lives in its own checkout) meant a mass death left every agent's output recoverable on disk, and CI was a sufficient validator for the work the dead agents couldn't verify themselves.

### P4 falsified: the fixture-conflict cascade

The round's fourth prediction — *no fixture↔page coupling surprise* — was falsified, cleanly. Every frontend PR appends a row to the shared `test/fixtures/calculators.yml` (the registry fixture), so at merge time each frontend collided with the previous one on that file:

> **"#277 hit a merge conflict — almost certainly `test/fixtures/calculators.yml`, the shared registry fixture each frontend appends a row to. This is the **fixture↔page coupling (P4) surfacing as a merge-time conflict in the fan-out** — a real iteration-0007 finding."**

The conflict was always a clean *additive union* — two calculators appending their own row at the same spot — so the resolution was mechanical (keep both). The orchestrator resolved #277 by hand to confirm the pattern (briefly chasing a false alarm — Ruby 3.4's safe YAML loader rejecting a `Time` value, which Rails loads fine), then **automated** it for the rest: auto-detect → union-resolve → push → merge. The cascade was tamed, but it is a genuine structural finding the 0006 harvest didn't anticipate, and it was filed as issue #286 (see Chapter 129). The takeaway: the fan-out *built* conflict-free (rule #3 held — no shared *source* file was hand-edited per calculator), but it *serialized at merge* on a shared *test fixture* — a coupling the registry-derivation pattern was supposed to have eliminated everywhere but the fixtures.

### The twin-convergence finding

Sales Tax and VAT — the deliberate twin convergence-probe — were built blind from parallel specs without peeking at each other, at both layers. The payoff came at the frontend QA gate, when the Sales Tax verdict flagged a §4 design divergence and noted the twin made the *identical* choice:

> **"the mode picker uses a **segmented control**, but DESIGN.md §4 mandates the `.mode-option` list when 'any label is multi-word' … Critically, **VAT (#282), the structural twin, uses the identical segmented treatment** — so this is a *convergent* divergence best resolved as one harvest decision … rather than a per-PR fix."**

The orchestrator read this as the headline finding the probe was built to detect:

> **"both Sales Tax *and* VAT independently chose a **segmented mode-picker** for multi-word labels, diverging from DESIGN.md §4's `.mode-option` list rule **identically**. That's exactly the convergence-consistency the twin-probe was designed to detect — one clean harvest decision … not a per-PR defect."**

Two independent agents, given near-identical specs and the same DESIGN.md, *diverged from the doc in the same way* — which means the divergence is a property of the documented rule (its wording was ambiguous for short 3-mode pickers), not agent noise. That is the experiment's "the agent layer is generative" claim shown in the negative: a doc ambiguity reproduces consistently, so fixing the doc fixes it everywhere.

### A process wrinkle: post-gate push leaves the gate stale

Pythagorean's frontend (#272) surfaced a smaller but real process finding. After its QA gate passed, the build agent pushed a *cosmetic SVG-clip fix* — so the gate had run on the prior SHA. The orchestrator caught it before merging:

> **"the QA PASS was for the *prior* SHA and the cosmetic fix isn't gated yet. **I'll hold the #272 merge until its CI lands green on the current head** rather than merge on the stale gate."**

It held until CI re-ran green on the fix head, then merged. The build agent had *also* flagged that Right Triangle (#215) carries the identical clip pattern and correctly declined to reach across seams to fix it — a propagation harvest item. Both became harvest entries: a "post-gate push requires re-gate" rule, and the Right Triangle SVG propagation.

### 10/10 — and the scorecard

The last frontends merged one by one, each with the automated fixture-conflict resolution, until VAT (#282) closed the set:

> **"🎉 **#282 VAT merged — all 10 calculators complete (10/10)!** Main at `be5659d`."**

The orchestrator ran the registry ingest to project the 10 new INVENTORY rows into the catalog table — and the result confirmed prediction P3 *exactly*:

> **"Ingest clean: **`upserted=24, deprecated=0, drift=0`** — … That confirms **prediction P3 exactly: the derived count held 14 → 24 with zero drift and no per-build bumps.**"**

Then it stood the app up headless (HTTP 200) with all 24 calculators live, handed the operator a review list of the 10 new pages, and posted the **stress-test scorecard** the round had been written to produce:

> **"- **P1 no registry collision** — ✅ held<br>- **P2 INVENTORY backfilled at Open** — ✅ held<br>- **P3 derived count holds 14→24, no per-build bumps** — ✅ held *exactly* (ingest: `upserted=24, drift=0`)<br>- **P4 no fixture↔page coupling surprise** — ❌ **falsified** (cleanly) … the shared `calculators.yml` fixture caused a **merge-conflict cascade** … a real finding the 0006 harvest didn't anticipate.<br>- **P5 no cross-seam edits** — ✅ held (the new `array_attribute` Base primitive was backend-turf, not cross-seam)"**

Four of five predictions held; the one that fell, fell *cleanly* — a written-down expectation falsified by a specific, reproducible mechanism, which is exactly the legibility the round was designed for (Chapter 117). The orchestrator's summary framed the meta-result precisely: **results held as the controlled variable** (including the Income Tax capability probe passing first-pass at both layers), and **the process is what got stressed** — the rate-limit ceiling and the fixture cascade being the two real findings the 2× scale surfaced.

### Agent/doc-driven? — the recovery is the evidence

No agent definition or doc changed in this chapter either; this is the build phase running to completion, and its harvest lands in Chapter 129. The "does this work?" signal here is unusually strong on two axes. First, **resilience**: a mass agent death from over-concurrency lost *zero* work, because worktree isolation kept every agent's output on disk and CI's 100%-coverage gate was a sufficient validator for the unverified salvage — the system degraded into a recoverable state rather than a lossy one. Second, **legibility**: the round was conceived as a process stress test with falsifiable predictions stamped at Open, and it delivered exactly that — P4 falsified by a named mechanism, the twin-probe detecting a convergent doc-ambiguity, the capability probe passing, and the derived registry count holding to the prediction *to the unit*. The findings (concurrency cap, fixture cascade, the array_attribute primitive, the twin picker decision, the SVG-clip propagation, the post-gate re-gate rule, the Auto Loan spec fix) are all *captured for the harvest* — which is the next chapter, and the point of the whole loop.

---
