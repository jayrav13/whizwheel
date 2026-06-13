# Design: Project Tracking & the PM Agent

**Date:** 2026-06-12
**Status:** Approved (design) — pending implementation plan
**Scope of this spec:** the experiment's framing + the **Project Manager (PM) agent**. The frontend and backend agents, the calculator conventions, and the fan-out harness are explicitly out of scope here and get their own specs later.

---

## 1. The experiment

whizwheel recreates [calculator.net](https://www.calculator.net) — its full breadth of calculators, reimagined our own way. A beautiful client UI for *using* calculators; **all math computed on the backend**.

The point of the project is not the calculators. It is a methodology test:

> Build the entire app **exclusively by iterating on agent definitions** — a frontend agent and a backend agent that encode the user's engineering style — and have Claude orchestrate those agents to produce the code. Does iterating on *agents* (rather than code) converge on output that matches expectations, and does that approach scale to larger apps?

The durable, improvable artifact is the **agent definition**, not any individual calculator. Code from a session is disposable; an agent file compounds across every future build.

### Core discipline

**When output disappoints, fix the agent definition — not the code.** Patching code teaches nothing; patching the agent is the iteration. This is the rule the whole experiment rests on.

### Why calculator.net suits this

It is a corpus of ~200 structurally similar problems (inputs → computation → results display) on a smooth difficulty gradient. Each new calculator is a measurable test of the agents against a harder instance of the same shape. Backend correctness is objectively verifiable against reference values; frontend quality is where the user's taste gets exercised.

### Operating principles

- **Agent-first, deliberately the hard path.** We codify decisions into the agent, not the code. This forces the user to describe intent precisely and forces Claude to interpret intent faithfully (and flag when it is guessing).
- **Start slow, one calculator at a time** on the main thread. Fan-out is a *future capability* we stay compatible with (see §4), not how we begin.
- **Git history is the ledger.** Breaking changes are expected. When a new convention would break older calculators, we document it, optionally back-apply, and move the strategy forward — all visible in history.

### The three agents

| Agent | Owns | Status |
|---|---|---|
| Frontend (FE) | Views, Stimulus, CSS, UI | Future spec |
| Backend (BE) | Models, calculation objects, controllers, math | Future spec |
| **Project Manager (PM)** | `docs/` — tracking, reporting, sequencing advice | **This spec** |

---

## 2. The PM agent

### Role boundary: scribe + reporter + advisor

The PM **records** what happens, **reports** it at multiple lengths, and **advises** on sequencing. It does **not** decide what gets built — it recommends; the user pulls the trigger.

### Write boundary (hard rule)

The PM writes **only under `docs/`**. It never writes app code and never edits agent definitions. It *reads* agent definitions (to describe them) and reads app/git state, but mutation is confined to `docs/`.

### Capabilities

**C1 — Inventory** (`docs/inventory.md`)
- Idempotently scrape calculator.net to produce the full catalog of calculators.
- Each entry: name, category, source URL, a **quantitative complexity rating (1–5)**, and **tags** (e.g. `charts`, `multi-input`, `date-math`, `iterative-solve`, `currency`).
- The tag vocabulary is **created and extended as calculators are ingested**, and complexity + tags can be **idempotently updated on re-fetch**. These values are allowed to change over time — including when model interpretation shifts.
- Pre-build complexity/tags are **hypotheses**; they get **corrected empirically** as calculators are actually built and the logs reveal the truth.
- A re-fetch detects additions / removals / changes and updates in place.

**C2 — Progress** (`docs/PROGRESS.md`)
- Tracks the current state of each calculator's rewrite into the app.
- State vocabulary (PM defines, we refine): `backlog → selected → built → shipped → needs-rework`.
- Each calculator links to the iteration that built it and the agent version (SHA) used.

**C3 — Iteration logs** (`docs/logs/`)
- An **iteration** = the rebuild of some `n` sequentially-next calculators using a **frozen, committed set of agents** (pinned to a git commit/SHA).
- Each iteration's log captures: **what changed in the agents since the last iteration**, the build outputs, and **all feedback and discussion** on the output before the next iteration begins.
- **Lifecycle:**
  - **Opens** — we lock the agent set, choose `n` and the specific calculators (PM recommends, user confirms); PM tags `iteration-NNNN` and records the agent SHA in the log header.
  - **Lives** — the log accrues build outputs and our feedback/discussion as we go.
  - **Closes** — the decision that we've learned enough and want to change the agents *is* the trigger to edit agent definitions, commit, and open iteration `N+1`.
- `docs/logs/INDEX.md` tracks every iteration: status (open/closed), date, agent SHA, calculators, headline outcome.
- `docs/INDEX.md` documents the `docs/` structure and the concept of iterations/logs.
- **Fan-out-ready layout:** per-calculator log files live under `docs/logs/iteration-NNNN/<calculator>.md` (disjoint, conflict-free); shared aggregates (PROGRESS.md, INDEX.md) are reconciled by a single serial pass (see §4).

**C4 — Synthesis (three lengths)**
- **Exec summary** — ~5 sentences.
- **Progress update** — ~2–3 paragraphs.
- **Blog post** — the "how did we do" article.
- Voice: first-person ("we"), technical reader. Whole-project by default; scopeable to an iteration or date range on request. Drawn from the logs + progress. The blog post is the accumulated log, synthesized — not written from scratch.

**C5 — Sequencing advisory**
- Reads progress + logs to recommend which calculators come next.
- Can **reorder** to increase/decrease complexity, or **pull forward** a calculator that would validate or refute a trending theory.
- **Theory ownership is shared:** the PM both *surfaces* candidate theories it spots in the logs ("the FE agent keeps missing on multi-tab layouts — want to stress-test that?") and *accepts* a theory the user asserts, then finds calculators to test it.
- Runs at the start of every iteration or on request. **Advisory only** — the user confirms.

### Git strategy

- PM commits **only `docs/`**, via **path-scoped staging** (`git add docs/...`, never `git add -A`). It must never sweep up app code or agent-definition changes from the working tree.
- Conventional, filterable messages: `docs(pm): refresh inventory (+3 / −1)`, `docs(pm): open iteration 0003 [agents @ a1b2c3d]`, `docs(pm): log feedback — percentage calculator`. So `git log -- docs/` reads as the project-management history.
- **Iteration boundaries = git tags** `iteration-NNNN` (zero-padded, sortable), pointing at the agent-definition commit the iteration is pinned to.
- **Ordering protocol:** (1) *we* edit + commit the agent definitions; (2) *PM* records that SHA, updates INDEX, creates the tag, and commits its doc updates.
- Linear on `main`. Branch-per-iteration is available later but not used now.
- The PM never commits agent definitions or app code.

### Tools the PM needs

WebFetch (scrape calculator.net), Read/Write/Edit (docs), Bash (scoped git operations).

---

## 3. `docs/` layout (target)

```
docs/
  INDEX.md                     # what docs/ is; the iteration/log concept
  inventory.md                 # full calculator catalog + complexity + tags
  PROGRESS.md                  # current state of each calculator's rewrite
  logs/
    INDEX.md                   # iteration registry (status, date, SHA, outcome)
    iteration-0001/
      <calculator>.md          # per-calculator build + feedback (disjoint files)
      ...
  superpowers/specs/           # design specs (this document)
```

---

## 4. Forward-looking: fan-out compatibility (banked, not built now)

We begin one calculator at a time, sequentially. We preserve the ability to fan out later. Two concurrency models are supported; both rest on the same invariant — **no two agents dangerously write the same file at once.**

- **Worktree-per-calculator** — isolation for free; each calculator → its own worktree → branch → PR.
- **Same-branch concurrent** — all agents on one branch, relying on **file-level locking** so an in-flight edit can't be clobbered; agents retry or block. Valid *only if that file-level safety exists* (worktrees provide isolation natively; same-branch is a discipline we must guarantee).

Two design principles follow and constrain the (future) FE/BE agents:

1. **Disjoint files + serial reconcile.** Parallel work writes only to per-calculator files; shared aggregates (PROGRESS.md, INDEX.md, and any shared app file) are written by a single serial step. The per-calculator log layout in C3 already reflects this.
2. **Auto-discovered, self-contained calculators.** The calculator pattern must avoid central registration (no shared `routes.rb`/registry edit per calculator), so parallel additions never touch a shared file. This is a constraint on the conventions the agents encode.

Pacing note: **fan-out width grows with agent maturity.** Early iterations stay narrow (n=1–2, sequential, tight feedback) because immature agents produce correlated failures; widen as variance drops.

Prerequisites for real PRs (not blockers now): a GitHub remote (the repo has none yet), and practical concurrency tops out ~10–14 agents before queueing.

---

## 5. Success criteria

The PM's own output *is* the measurement of the experiment:

- Over iterations, the gap between agent output and expectations **shrinks**.
- Corrections increasingly become **agent-definition edits**, not code patches.
- Eventually the agents produce **complex** calculators to taste with **minimal correction**.

The logs are the evidence; the blog post is the synthesis.

---

## 6. Out of scope / deferred

- The **frontend** and **backend** agent definitions (future specs).
- The **calculator conventions** themselves (emerge as we build; encoded into the agents).
- The **fan-out / workflow harness** (future).
- The **UI direction** (deliberately still open; will be codified into the FE agent later).
