## Chapter 56 — A side-quest design: the `database-agent`, where a boundary tension and a live-census idea reshaped the spec (2026-06-14)

A fresh session opened on a deliberate detour. The user: *"Let's knock out a side quest, let's think about a potential database agent per the issue"* — the `database-agent` filed *prospectively* back in Chapter 49 (issue #36, deferred, *"while the schema is still simple"*). No code, no build: this chapter is a **design brainstorm**, run end-to-end through the superpowers **brainstorming skill** before any implementation, and it ends — by design — at the user-review gate, not at a merged agent. It is a clean small instance of the repo's stance that *the agent definition is the durable artifact* and is worth designing before it is written.

The assistant announced the method up front: *"I'll start by invoking the brainstorming skill since we're designing a new agent (creative/design work), and pull up the relevant issue in parallel."* It grounded itself in the existing agent definitions and the live schema, then — before asking any clarifying questions — surfaced something that *the issue's own framing got subtly wrong*.

### The boundary tension — what the agent's value actually is

The #36 issue motivates the agent as a way to stop hand-writing throwaway database scripts. The assistant caught that this collides with the repo's lane boundaries:

> "The issue motivates this agent by 'we don't want to hand-write a one-off `bin/rails runner` script every time.' But under CLAUDE.md's boundaries, the `backend` agent owns `lib`, rake tasks, and scripts — and this agent is strictly read-only and never writes app code. So the database-agent *can't* ship a reusable `bin/db-report` script or rake task to eliminate ad-hoc queries; that would cross into backend's lane."

The reframe followed directly — and it is a pure restatement of the experiment's central principle (the durable artifact is the *agent*, not the code it might emit):

> "Which means its durable value isn't 'no more ad-hoc scripts' — it's **'ad-hoc queries written by something that already knows the schema cold and never has to rediscover it.'** The reusable artifact is the *agent definition's schema fluency*, not a committed script."

This is a small but telling moment: the agent's *purpose statement in its own founding issue* was found to imply a boundary violation, and the fix was to relocate the value from a committed output (a script — backend's lane) up into the agent definition itself (schema fluency — the agent layer). Agent-first, applied to the agent's *own charter*. The user confirmed the cleaner model and the brainstorm proceeded.

### The first design — config, boundaries, posture

After grounding in the actual schema (the assistant enumerated it: tables `calculations` / `users` / `sessions` / `roles` / `role_types`, the `calculation_logs` view that LEFT JOINs `username`, which tables are soft-deletable via `Discardable` and which are not, and the attribution chain `calculations.user_id → users → roles → role_types`), the assistant laid out a full first-pass design:

- **Config:** `model: opus`, `tools: Bash, Read`, `color: pink`. The color choice carried an explicit rationale — pink because *"`red` reads as 'danger,' wrong signal for a read-only inspector"* — a deliberate semantic mapping consistent with the per-agent color convention from Chapter 33.
- **Report-only → no worktree**, mirroring `ci-monitor` / `dependabot-agent` (the agents that never write, carved out of the worktree default in Chapter 54).
- **A Step-0 launch protocol** mirroring the PM's: read `CLAUDE.md`, `ARCHITECTURE.md` (the relevant sections), the schema source of truth, and the models.
- **A read-only hard boundary, stated absolutely:** only `SELECT` / ActiveRecord reads / `dbconsole` / `psql`; never a write, never a `discard`, never a migration (that is backend's lane), never app code or agent defs.
- **Operating posture (the user's earlier call): ad-hoc + schema-fluent** — composes throwaway `bin/rails runner` one-liners, *commits nothing*; default target `RAILS_ENV=development` (the local `bin/dev` click-through DB — the literal "local test run"), always stating which env it queried.
- **Scope: whole schema, equal depth** — accepting the heavier definition and more regeneration churn in exchange for uniform coverage.

The assistant explicitly flagged the three spots *most worth a second look*: the pink color, the mode-discovery-from-data caveat, and the whole-schema maintenance cost. The user did not bite on those — instead, the user reached past the design and reshaped its centerpiece.

### The user's creative steer — a live census instead of static docs

The proposed "baked-in schema knowledge" was static, hand-written documentation. The user rejected that frame in favor of something self-correcting:

> "For baked in schema knowledge - can we get creative here? Write a query that the agent is required to run on startup that builds a report of the entire schema in Postgres itself via a query. It can, by definition, never get stale
>
> Then, the deeper documentation you write is based on the schema you know about now. As schema evolves, we will evolve the details in the agent. But even if our details aren't there, having a canned query to start with will expose the entire schema, including the negative context of not having a lot of details about the schema elements for which we haven't added to the agent"

The assistant recognized this as a strict improvement — *"a genuinely better idea than static-only documentation — it makes the agent honest about its own coverage"* — and, true to the repo's "validate before you spec" instinct, **ran the census queries against the live dev DB before baking them in**: *"I don't want to spec a query I haven't seen run."* Both queries — a **columns census** (one row per table/view with type and nullability) and an **FK census** (the relationship graph) — reproduced the ground truth exactly: every table, the `calculation_logs` view, all columns and nullability, and all four foreign keys.

The revised design replaced static documentation with **two layers plus a reconciliation step**:

- **Layer 1 — the live `information_schema` census**, run as the launch protocol's final step, authoritative and *never stale by construction*.
- **Layer 2 — a hand-written enrichment overlay** (jsonb shapes, `Discardable` semantics, the attribution chain, mode discovery), stamped with a currency date, evolved via agent-def PRs as the schema grows.
- **Reconciliation on launch** — the agent diffs the live census against its own overlay and reports the gap explicitly, so an undocumented table surfaces as *"present in DB, NOT yet documented in this agent"* rather than as a silent blind spot. As the assistant put it, the agent is *"never silently blind."* This is precisely the *"negative context"* the user asked for: a new table added next iteration appears immediately as "exists, undocumented" instead of being invisible until someone remembers to update the def. The assistant also noted the design hardens the read-only posture as a side effect — catalog introspection is the canonical safe first move.

The user approved tersely: *"good"*.

### Written, self-reviewed, and parked at the gate

The assistant set up a branch (per the never-push-to-`main` rule) and, during the brainstorming skill's spec self-review step, caught and fixed one imprecision of its own — the overlay's currency stamp. Because iteration 0002 had just closed and 0003 was not yet open, asserting an iteration number would have been wrong, so it anchored the currency to the date instead, deferring the iteration label to the def's build time. The spec was committed to `docs/superpowers/specs/2026-06-14-database-agent-design.md` on branch `docs/36-database-agent-design` (commit `270e9c2`), and the assistant stopped at the brainstorming flow's user-review gate, recapping the three headline decisions (the boundary reframe, the pink/no-worktree/dev-DB/opus config, and the two-layer census-plus-overlay knowledge model). The user approved (*"approved"*), and the assistant moved on to invoke the **writing-plans** skill to turn the spec into an implementation plan for the actual `.claude/agents/database-agent.md`.

The window closes here — the writing-plans skill is loaded but the plan itself, and the agent definition it will produce, are not yet written. **The `database-agent` does not yet exist; only its design spec does, and that spec is committed on a branch awaiting the next step, not merged.**

**Agent-driven? ✅ (design only)** No app code, no agent definition yet — a brainstormed spec committed on a branch, the artifact that precedes the agent. Two things worth noting as evidence: (1) the brainstorming-skill discipline caught a *boundary contradiction in the agent's own founding issue* before a line was written, and resolved it by relocating value from a committed script into the agent definition — the agent-first principle applied reflexively to a new agent; and (2) the design's load-bearing improvement came from the **operator**, not the assistant — the live-census idea that makes the agent's documentation un-stale-able and self-honest about its coverage gaps — continuing the journey's most consistent pattern: the operator pushing intent into a more durable shape than the assistant's first draft reached for, and the assistant validating it (here, literally running both census queries against the real DB) before committing it.

---
