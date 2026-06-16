## Chapter 123 — "Should we entirely deprecate ci-monitor?": a pre-launch decision to keep the insurance policy through the stress test (2026-06-16)

A new session opened pointed straight at iteration-0007. The operator's first prompt was a readiness check —

> **"Ok, now do we have the next 10 calculators we want to work on queued up?"**

— and the orchestrator confirmed the locked 10 (Auto Loan, Sales Tax, Pythagorean Theorem, Discount, VAT, Personal Loan, Average Return, ROI, House Affordability, Income Tax), restated the round's framing as a **process stress test, not a results round** (2× fan-out at ~20 build PRs, holding results as the controlled variable after iteration-0006's clean 6/6), and listed what still stood between here and Open. But before any of that fired, the operator paused to settle a piece of agent-roster hygiene:

> **"Before doing that, should we entirely deprecate the ci-monitor in favor of the quality-assurance-agent?"**

This chapter records the decision that came out of that question — a deliberate **defer**, not a deprecation — and the reasoning behind it, because the reasoning is the experiment thinking about its own machinery.

### Grounding the question in the live agent defs, not memory

The orchestrator's instinct was correct: don't answer from recollection. It said as much —

> **"Good question to settle before opening the round. Let me ground it in the current agent defs and the open tracking issue rather than answer from memory."**

— and went and read the actual state. The findings sharpened the question into something more precise than "deprecate or not."

**The adoption decision was already made and closed.** Issue **#169** — the "revisit before adoption" tracker for swapping the QA agent in for `ci-monitor` — is **CLOSED**. The QA agent is the live gate for *every* PR, CLAUDE.md already routes all CI + visual + DB checks through it, and the QA definition explicitly says its CI facet **"absorbs what ci-monitor did."** So in the *active path*, `ci-monitor` is already not dispatched.

**What remains of ci-monitor is purely a dormant fallback, not in the live path.** The orchestrator enumerated its only two surviving roles:

1. **The named fallback** — CLAUDE.md's adoption note: *"if the QA agent proves unfit, reverting this section to dispatch ci-monitor + the main-thread visual gate is the fallback."*
2. **A comparative reference** in `backend.md`, `github-agent.md`, `database-agent.md`, and `dependabot-agent.md` — the "report-only, no worktree, like ci-monitor" shape used to *describe* those agents, not to dispatch ci-monitor.

So "entirely deprecate" did not mean removing a live component — it meant **removing the insurance policy**: scrubbing the fallback language, marking `ci-monitor.md` deprecated, and rewording the four descriptive references.

### The recommendation: don't pull the fallback during the trial

Having reframed the question that way, the orchestrator made an unhedged recommendation against deprecating now — and the argument is the load-bearing part of this chapter, because it is the experiment reasoning about *when* to change its own tooling:

> **"Iteration-0007 is a deliberate process stress test at 2× fan-out (~20 PRs) — and that fan-out *is* QA's first real trial at scale (its prior live runs are a handful of PRs). Pulling the documented fallback right before the biggest stress test the harness has faced is the one moment you'd most want it kept."**

And the principle it distilled:

> **"don't remove the fallback during the trial — remove it after the trial passes."**

The cost calculus made the call easy: keeping `ci-monitor` costs essentially nothing (a dormant definition plus four descriptive mentions), while deprecating it now buys only "conceptual tidiness" and **forecloses a cheap recovery path exactly when recovery is most likely to be needed**. The orchestrator also noted that pulling the fallback would *inject a new variable* into a round whose entire purpose is holding the machinery controlled — deprecating mid-stress-test would muddy the very signal 0007 exists to read.

The proposed sequencing folded the deprecation into the round's own lifecycle rather than treating it as a pre-launch chore: run 0007 with QA gating all ~20 PRs, **track its first-pass gate rate and any deaths/misses** (already a planned 0007 metric), and if QA proves out across that volume, **fold the full ci-monitor deprecation into the 0007 harvest** — "where agent-roster changes belong." That places the deprecation in the Harvest phase, gated on evidence the round itself produces.

### The decision: defer to the 0007 harvest

The operator chose the recommended path. The orchestrator confirmed it twice — once to state the direction, once to record it:

> **"Settled: keep ci-monitor as is for now — no changes before 0007. I'll fold its full deprecation into the 0007 harvest, gated on QA proving out across the round's ~20-PR fan-out."**

And after recording it to the iteration-0007 plan memory (no agent-def edits, as the operator chose):

> **"Decision locked: ci-monitor stays as the dormant fallback through iteration-0007. Its full deprecation becomes a 0007 harvest task, gated on QA proving out across the round's ~20-PR fan-out — measured by the first-pass gate rate + any QA deaths/misses already on the 0007 metrics list. If QA holds at scale, the harvest marks `ci-monitor.md` deprecated, scrubs the fallback language in CLAUDE.md, and rewords the four comparative refs."**

### Agent/doc-driven? — deliberately neither, yet

No agent definition or doc was edited in this chapter — and that absence is the point. The decision was to **not** change the roster yet, and to make the change a falsifiable, evidence-gated task scheduled for the round's Harvest phase. The only artifact touched was the operator's iteration-0007 plan memory, where the deferred-deprecation task was recorded so it isn't lost between Open and Harvest. This is the experiment's discipline applied to its own scaffolding: a tooling change that *could* have been done by reflex ("the new gate is live, retire the old one") was instead held until the round produces the evidence to justify it — keeping the fallback as cheap insurance precisely across the largest fan-out the harness has yet faced. The "does this work?" signal here is meta and procedural: the harness reasoned about the risk of changing the harness mid-experiment, and chose to gate the change on the experiment's own metrics rather than on tidiness.

---
