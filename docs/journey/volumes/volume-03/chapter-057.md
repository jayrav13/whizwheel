## Chapter 57 — The `database-agent` gets built: subagent-driven execution, and a course-correction on when subagents earn their cost (2026-06-14)

Chapter 56 closed at the writing-plans step — a brainstormed, committed spec on a branch, no plan and no agent definition yet. This chapter is the build: the spec became an implementation plan, the plan became the actual `.claude/agents/database-agent.md`, a fresh-eyes review approved it, a live smoke test exercised it, and PR #47 (`Closes #36`) merged. Along the way the *execution method itself* was put under examination twice — first about whether to fan out, then about whether subagents were worth their ceremony at all — and the assistant adjusted the prescribed workflow rather than running it on rails.

### From spec to plan to an execution-method choice

The assistant wrote the implementation plan with the superpowers writing-plans skill, first studying *"the house style of the richer agent defs so the plan's def content matches conventions (launch protocol, boundary phrasing)."* Because the whole effort builds a single artifact, the plan chunked that file's authoring into sequential tasks with concrete validation baked in (re-running the census, a live read-only smoke test). The assistant then self-reviewed the plan against the spec and caught one parity gap — *"the def never states it creates no worktree"* — and added it before committing the plan to `docs/superpowers/plans/2026-06-14-database-agent.md` (commit `5b1409b`).

With spec + plan in hand, the assistant offered the user two execution modes — **subagent-driven** (a fresh subagent per task, recommended) or **inline** (executed in-session with checkpoints) — and the user chose subagent-driven (*"1"*). That choice loaded the superpowers **subagent-driven-development** skill, whose prescribed shape is: *fresh subagent per task + two-stage review (spec compliance, then code quality) after each.*

### First adjustment — granularity, and the worktree call

The assistant did not run the skill literally. It made an up-front granularity judgment: plan Tasks 1–4 all build *the same single file by sequential append* — tightly coupled, not independent — so it dispatched them as **one implementer** authoring the complete def plus the embedded census validation (Task 5), with the live smoke test (Task 6) as its own subagent and the PR (Task 7) handled by the orchestrator. It also made a whizwheel-specific worktree call that *departs from the standing per-agent worktree default* and explained why:

> "the implementer will work **on the existing `docs/36-database-agent-design` branch in the main tree, not a fresh worktree** — that branch already holds the prerequisite spec+plan commits, and this is a single linear effort, so a new worktree would fragment it."

This is a deliberate, reasoned exception to the Chapter-54 "every writing agent makes its own worktree" default — taken because the prerequisite commits already lived on the branch and a new worktree would split one linear effort across two trees.

### The fan-out question — "should we be spawning them all?"

The assistant backgrounded the single implementer, and the user asked: *"I backgrounded - should we be spawaning them all?"* The answer drew the distinction the experiment leans on between a dependency chain and independent work:

> "no, not for this plan. These tasks form a dependency chain, not independent work: implementer (writes def) → spec review → quality review → smoke test → PR. Each stage consumes the previous one's output … Spawning them all at once would have them reviewing a file that doesn't exist yet."

And it named *when* the repo does fan out — *"independent work with no shared state — exactly the repo's **regeneration sweep** (one `backend` agent per calculator) … this side quest isn't it."* It also noticed, mid-answer, that the harness had **registered `database-agent` as a live Agent type** — meaning the implementer had already written the file — which would let the Task-6 smoke test dispatch the *real registered agent* rather than a generic subagent pointed at the def.

### The course-correction — "wouldn't inline be better for every step after this one then?"

The user pressed the deeper question: *"Oh I'm surprised subagent was recommended then, wouldn't inline be better for every step after this one then?"* The assistant conceded the point partway and refined it — a genuinely substantive reflection on *when subagents earn their cost*:

> "This task is authoring one ~150-line markdown file whose content I already wrote *verbatim* in the plan — so the 'implementer' is mostly mechanical, and the per-task two-stage review ceremony is heavier than the work warrants. Inline would've been a defensible pick."

But it argued *"inline for everything after"* wasn't right either, isolating the two remaining steps that earn a separate agent for reasons other than fresh implementation context:

> "**The smoke test (Task 6) should stay a subagent** — and it's the highest-value one. It's the actual *behavioral* test of the def: a fresh agent reads the def cold and acts on it. If I run it 'inline,' I'd be role-playing the agent while knowing exactly what I intended it to do — a contaminated test."

> "**One review pass is worth keeping as a subagent** — not for fresh *context*, but for fresh *eyes*. I wrote both the spec and the plan's exact content, so reviewing it inline is marking my own homework."

The resolution split the difference and **collapsed the skill's prescribed two-stage review (spec, then quality) into a single fresh-eyes review subagent**, kept the smoke test as the *real* `database-agent`, and did the PR inline as pure mechanics — *"That drops the ceremony you're reacting to while keeping the two subagent uses that actually earn their cost."* The user agreed: *"Yep that makes sense and works."*

The data point: the assistant ran a prescribed third-party skill but **adapted it to the situation** — recognizing the implementation was mechanical (the plan held the def's content verbatim), and that the durable reasons to spend a subagent here were *contamination avoidance* (the behavioral smoke test) and *confirmation-bias avoidance* (don't grade your own homework), not the skill's default rationale of fresh implementation context. This is the same adapt-don't-copy instinct the journey showed when it adapted tenor's branching flow (Chapter 17) rather than importing it whole.

### Implementer DONE, fresh-eyes review APPROVED, three honesty-sharpening polish notes

The implementer reported **DONE** — *"no deviations, census validated (5 tables + 1 view, 4 FKs, reconciliation 'none')"* — with all four blocks written byte-for-byte from the plan's fenced content (commits `5eba85e` → `3c76bbe`). The single fresh-eyes reviewer returned **APPROVED** with three *cosmetic* findings, which the assistant applied inline (trivial markdown, no need to re-spin a subagent) because all three *"actually sharpen the census's honesty — which is this agent's whole point"*:

1. note that the FK census assumes single-column FKs;
2. state *why* `schema_migrations`/`ar_internal_metadata` are excluded (so the table count doesn't confuse against `\dt`);
3. add `created_at`/`updated_at` to the `calculations` overlay entry so the "created-at time range" capability is self-grounding.

Committed as `e11e24f`. The notes are all about making the census *honest about its own coverage* — the same negative-context principle the operator supplied back in Chapter 56.

### The smoke test — the real registered agent, run cold, zero writes

Task 6 dispatched the **real registered `database-agent` type** against the literal motivating question — "what is the state of my local test run?" — the honest behavioral check the assistant had argued for keeping as a subagent. The assistant recorded the baseline row count first, so a read-only violation would be detectable. The result:

> "The smoke test passed beautifully — the agent followed its launch protocol, ran both census steps with reconciliation ('none' undocumented), counted by calculator/attribution/kept-vs-discarded, **discovered the 5 Percentage modes from the data** rather than assuming them, and reported RBAC."

And the read-only posture was *verified*, not assumed — *"Read-only confirmed (13 → 13, zero writes)."* The row count was unchanged after the agent ran, proving it mutated nothing. The mode-discovery behavior — the agent learning the five Percentage modes *from the data* rather than from a baked-in taxonomy — is the exact payoff of the read-only, census-first design the operator shaped in Chapter 56, now demonstrated in practice.

PR #47 was opened (`Closes #36`), `ci-monitor` dispatched to watch it, and the side quest's seven plan tasks were complete — a brainstormed spec, a self-reviewed plan, a from-plan agent def, a fresh-eyes approval, a live read-only smoke test, and a PR in review.

**Agent-driven? ✅** A new agent definition built from its own spec/plan, validated by an independent fresh-eyes reviewer and a live behavioral test before merge. Two process notes worth keeping: (1) the smoke test ran the *real* registered agent against the real DB and proved both correctness (mode-discovery, reconciliation, RBAC) and the read-only invariant (13 → 13 rows); and (2) the execution method was itself adjusted under questioning — the prescribed two-stage review collapsed to one fresh-eyes pass — on the principled grounds that the implementation was mechanical and only contamination/bias avoidance justified a subagent here.

---
