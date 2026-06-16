## Chapter 124 — Iteration-0007 opens: a process stress test at 2× fan-out, with predictions written in up front (2026-06-16)

With the ci-monitor question settled (Chapter 123), the operator gave the launch order:

> **"Rad, let's launch iteration-0007 and get started with the work needed for all 10 calculators. Final state - all PR's merged and web app running ready for me to review the 10 new calculators"**

This is the formal **Open** of iteration-0007, and it is worth recording in detail because the round is deliberately designed to be *legible* — its whole purpose is to test whether the iteration-0006 harvest "took" at twice the fan-out, and that test is only meaningful if the predictions and metrics are stamped *before* the work runs. This chapter captures the Open; the builds, gates, and merges are later chapters' material.

### The round's stated shape

The orchestrator restated the staged plan it would drive, naming the operator's pre-authorization explicitly:

> **"This is a ~20-PR fan-out, so I'll orchestrate it in stages: Open → fan out builds (backend-before-frontend per calc) → QA-gate every PR → merge on green → stand up the app for your review. You've authorized the merges ('all PRs merged') — I'll merge each PR only once its `quality-assurance-agent` gate returns PASS, and surface anything that fails rather than force it."**

Two things are load-bearing in that sentence. First, the **merge authorization is blanket but conditional**: the operator's "all PRs merged" pre-authorizes the merges, but each merge is still gated on a QA PASS — the human-gated-merge rule is preserved by making the gate, not a per-PR ask, the thing standing between a green PR and `main`. Second, the **failure posture is explicit**: anything that fails its gate is surfaced, not forced. That is the discipline the stress test is meant to exercise at volume.

### Recon before the handoff

Before dispatching Open, the orchestrator ran a quick recon to make sure the handoff mirrored the established pattern and didn't duplicate anything:

> **"First, quick recon so the Open + issue-filing handoff mirrors the established pattern and doesn't duplicate anything the PM may have already filed."**

The recon returned the facts that anchored the rest of the launch:

> **"None of the 10 are filed yet; `main` is at `e85c47c`. Reusable primitives all present (`loan`, `mortgage`, `ohms_law`, `right_triangle`, `percentage`, `standard_deviation`)."**

That two of the nine pure-recombination calculators (Personal Loan, House Affordability) lean on an already-present `loan`/`mortgage` core, and that the math primitives the rest recombine all exist, is exactly the precondition the round needs: the 9 recombinations should be genuinely *recombinations*, leaving Income Tax as the one new primitive. The orchestrator then calibrated against the real spec:v1 format and the 0006 log shape before dispatching — *"This is the spec:v1 bar (rich: PM-computed reference values, formulas confirmed against calculator.net, edge cases) and the log structure to mirror."*

### Pin-at-open: the tag goes on post-harvest main

Per the established convention (the 0006 log), the **main thread applies the pin tag** while the PM owns the log and specs:

> **"Per the established convention (0006 log), the main thread applies the pin tag at post-harvest `main`, and the PM opens the log + authors specs. Let me pin the tag and set up progress tracking."**

> **"Tag `iteration-0007` pinned at `e85c47c`."**

The SHA `e85c47c` is the post-harvest `main` — the agent set that absorbed the iteration-0006 harvest *and* the admin-stats side-quest harvest (the TradingView-Histogram + monospace-`<code>` conventions). Pinning there is what makes 0007 a clean regression test: the 10 new builds run on exactly the conventions the prior harvests encoded, so whether those conventions reproduce correctly across 10 unseen calculators is the measurement.

### Dispatching the PM to Open — predictions and metrics up front

The orchestrator then fired the PM in the background to do the Open proper, emphasizing the legibility design:

> **"Now dispatching the PM to Open the iteration — it'll write the log (with predictions/metrics up front, per the stress-test design), backfill the INVENTORY rows, and author all 10 spec:v1 bodies. Backgrounding it; nothing else is unblocked until specs exist."**

The predictions stamped in at Open — the falsifiable claims the round is testing — are the harvested conventions from iteration-0006: **no registry collision** across the fan-out, **INVENTORY backfilled at Open** (not per-build), the **derived calculator count holds**, **no fixture↔page surprise**, and **no per-build count bumps**. Writing them in before the work runs is what turns any recurrence into a clean falsification rather than a post-hoc rationalization — the round's legibility is its point. The PM also carries the extra rigor on **Income Tax's bracket/piecewise math**, the one deliberate new primitive and the round's single conscious capability nudge.

The orchestrator noted the worktree-isolation reasoning that lets the PM and historian run concurrently without conflict:

> **"I said I'd journal — firing the historian in the background now (it writes only under `docs/journey/`, so no conflict with the PM's `docs/logs/` + specs)."**

### The regen set is empty — and why

The locked 10 are all **new builds**; the **regen set is empty**. This is a deliberate consequence of the round's design: the 10 new builds, branched off post-harvest `main`, inherit the iteration-0006 and admin-stats harvest conventions *natively* — there is no need to regenerate priors to propagate those conventions, because every new calculator reads them at build time. (The orchestrator had flagged at the prior session that *if* a small regen set were included it would fold in a check that the admin-stats harvest propagated — the TradingView-`Histogram` and monospace-`<code>` conventions — but the operator's locked scope carried no regen, making 0007 a new-build-only stress test.)

### State at journal time

The orchestrator's status read-out captured the round's machinery in flight:

> **"Iteration-0007 is open and running."** — pin tag applied at `e85c47c`, 12-task progress tracking set up with the dependency graph (Open → file 20 build issues → 10 builds → stand up app), the PM in the background writing the log with **"falsifiable predictions + consistency metrics up front (the legibility that makes this stress test worth running)"**, backfilling the 10 INVENTORY rows, and authoring all 10 spec:v1 bodies; the historian journaling alongside.

The downstream sequencing was named and gated on the PM: once specs exist, `github-agent` files the 20 build issues (backend + frontend per calculator), then the builds fan out — **Auto Loan first** (re-establishes the loan core), then Personal Loan + House Affordability inherit it, Sales Tax ↔ VAT built in parallel as a twin convergence-probe, and Pythagorean / Discount / ROI / Average Return as independent parallel builds. QA gates every PR; green PRs merge under the operator's blanket authorization; the app is stood up headless with all 10 live for review.

### Agent/doc-driven? — pure machinery, run at scale

No agent definition or doc convention changed in this chapter — the Open is the iteration *lifecycle* engaging, not a harvest. The artifacts in motion are the iteration log, the INVENTORY backfill, and 10 spec:v1 bodies (all PM-owned), plus the `iteration-0007` tag pinned by the main thread. The "does this work?" signal here is entirely about the **process at 2× scale**: the experiment is consciously running the same six-phase lifecycle it ran for 0006, but doubled, with the success criteria written down in advance so the round can be read as a falsifiable test of whether the harvested conventions reproduce across ten unseen calculators. The deliberate move — holding results constant and treating *coordination at fan-out* as the variable under test — is itself the chapter's evidence: the harness is now mature enough to instrument and stress-test its own machinery on purpose.

---
