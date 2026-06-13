# Design: Project Tracking & the PM Agent

**Date:** 2026-06-12
**Status:** Approved (design, rev. 2) — pending implementation plan
**Scope of this spec:** the experiment's framing + the **Project Manager (PM) agent**. The frontend and backend agents, the calculator conventions, and the fan-out harness are explicitly out of scope here and get their own specs later.

**Rev. 2 changes:** task/kanban tracking moves to **GitHub Issues**; `PROGRESS.md` is retired; the PM gains a mandatory full-context **launch protocol** and a pinned **Opus** model.

---

## 1. The experiment

whizwheel recreates [calculator.net](https://www.calculator.net) — its full breadth of calculators, reimagined our own way. A beautiful client UI for *using* calculators; **all math computed on the backend**.

The point of the project is not the calculators. It is a methodology test:

> Build the entire app **exclusively by iterating on agent definitions** — a frontend agent and a backend agent that encode the user's engineering style — and have Claude orchestrate those agents to produce the code. Does iterating on *agents* (rather than code) converge on output that matches expectations, and does that approach scale to larger apps?

The durable, improvable artifact is the **agent definition**, not any individual calculator. Code from a session is disposable; an agent file compounds across every future build.

### Core discipline

**When output disappoints, fix the agent definition — not the code.** Patching code teaches nothing; patching the agent is the iteration. This is the rule the whole experiment rests on.

### Two-layer record

| Layer | Lives in | Holds |
|---|---|---|
| **Kanban (task state)** | **GitHub Issues** | Discrete units of work — what to build, what's in flight, what's deferred. Concurrency-safe, PR-linked (`Closes #N`). |
| **Knowledge (the lessons)** | **`docs/` (in repo)** | Inventory, iteration logs, synthesis. The learning record and the experiment's evidence. |

The principle that draws the line: **the kanban may live off-git (it's a board), but the knowledge stays in the repo.** Iteration logs reference issue numbers, so even if GitHub vanished, the repo still tells the whole story — you'd lose the board, not the lessons. This preserves "git history is the ledger" for the part that matters.

### Why calculator.net suits this

It is a corpus of ~200 structurally similar problems (inputs → computation → results display) on a smooth difficulty gradient. Each new calculator is a measurable test of the agents against a harder instance of the same shape. Backend correctness is objectively verifiable against reference values; frontend quality is where the user's taste gets exercised.

### Operating principles

- **Agent-first, deliberately the hard path.** We codify decisions into the agent, not the code. This forces the user to describe intent precisely and forces Claude to interpret intent faithfully (and flag when it is guessing).
- **Start slow, one calculator at a time** on the main thread. Fan-out is a *future capability* we stay compatible with (see §4), not how we begin.
- **Git history is the ledger** for knowledge. Breaking changes are expected. When a new convention would break older calculators, we document it, optionally back-apply, and move the strategy forward — all visible in history.

### The three agents

| Agent | Owns | Model | Status |
|---|---|---|---|
| Frontend (FE) | Views, Stimulus, CSS, UI | likely Sonnet (TBD) | Future spec |
| Backend (BE) | Models, calculation objects, controllers, math | likely Sonnet (TBD) | Future spec |
| **Project Manager (PM)** | `docs/` + GitHub Issues — tracking, reporting, sequencing advice | **Opus** | **This spec** |

---

## 2. The PM agent

### Model

Pinned to **Opus** in the definition (not inherited from the session). The PM does the project's heaviest reasoning — full-history ingestion, synthesis, theory-spotting — and pinning makes the agent reproducible regardless of session settings.

### Launch protocol (Step 0 — every invocation, no exceptions)

Before doing **any** task, the PM ingests full context **deterministically — no sampling, no shortcuts.** This is expensive by design; the PM must never operate on partial history.

1. Read **every** file under `docs/` in full.
2. Capture **complete** repository + project state:
   - `git log` (full) and `git tag --list 'iteration-*'`.
   - All GitHub Issues, **every state**, with labels and bodies (`gh issue list --state all`).
   - All PRs, every state, with their closing-issue references.
3. Only after full ingestion does the PM begin the requested task.

### Role boundary: scribe + reporter + advisor

The PM **records** what happens, **reports** it at multiple lengths, and **advises** on sequencing. It does **not** decide what gets built — it recommends; the user confirms and pulls the trigger. Sequencing is advisory.

### Write boundary (hard rule)

- The PM writes **only** under `docs/`, and **manages GitHub Issues** (create/label/read).
- It **never** edits app code (`app/`, `lib/`, `config/`, `db/`, `test/`, `bin/`, …).
- It **never** edits agent definitions (`.claude/agents/`), including its own.
- It **never closes** issues — PR merges close them via `Closes #N`.
- It **may read anything** — agent definitions, app code, git history, issues, PRs — to describe it accurately.
- If a task would require writing app code or an agent definition, **stop and say so**; offer the content for the user or another agent to place.

### What it owns (in docs/)

| File | Purpose |
|---|---|
| `docs/inventory.md` | Full calculator catalog + complexity + tags. |
| `docs/logs/INDEX.md` | Registry of iterations. |
| `docs/logs/iteration-NNNN/<calculator>.md` | Per-calculator build + feedback. |
| `docs/INDEX.md` | Explains the structure (rarely changes). |

### Capabilities

**C1 — Inventory** (`docs/inventory.md`)
- Idempotently scrape calculator.net (all category pages, not just the homepage subset) to produce the full catalog.
- Each entry: name, category, source URL, a **quantitative complexity rating (1–5)**, and **tags** (created/extended as calculators are ingested).
- **Idempotent merge:** re-fetches **preserve** empirically-corrected complexity/tags (do not clobber with fresh hypotheses), **add** new calculators, **mark** removed ones. Pre-build values are hypotheses; they get corrected as calculators are actually built.

**C2 — Task tracking (GitHub Issues)**
- The PM **creates and labels** issues; it reads their state for reporting. It does not close them.
- **One `engineering` issue per calculator** to build (title = calculator name; body links the inventory row + source URL + complexity/tags). Issues are seeded from the inventory.
- **`agents` issues** capture deferred work — bugs/cleanups queued for a future agentic batch fix (the `agents` queue).
- An iteration's calculators are its set of selected `engineering` issues, built under a pinned agent SHA; their PRs close them with `Closes #N`.

**C3 — Iteration logs** (`docs/logs/`)
- An **iteration** = the rebuild of some `n` sequentially-next calculators (= selected `engineering` issues) using a **frozen, committed set of agents** (pinned to a git commit/SHA).
- Each iteration's log captures: **what changed in the agents since the last iteration**, the build outputs, and **all feedback and discussion** before the next iteration begins.
- **Lifecycle:** **opens** (lock agents, choose `n` + calculators, PM tags `iteration-NNNN` + records SHA) → **lives** (per-calculator notes + feedback accrue) → **closes** (decision to change the agents; that decision triggers the agent edit + the next iteration).
- `docs/logs/INDEX.md` registers every iteration: status, date, agent SHA, calculators (with issue numbers), headline outcome.
- Per-calculator files (`logs/iteration-NNNN/<calculator>.md`) are **disjoint** (fan-out-safe); `logs/INDEX.md` is a serial aggregate.

**C4 — Synthesis (three lengths)**
- **Exec summary** (~5 sentences), **progress update** (~2–3 paragraphs), **blog post** (the "how did we do" article).
- Voice: first-person ("we"), technical reader. Whole-project by default; scopeable on request. Drawn from the logs + inventory + issue state — the blog post is the accumulated log, synthesized.

**C5 — Sequencing advisory**
- Reads the inventory, issue state, and logs to recommend which calculators come next.
- Can **reorder** to raise/lower complexity, or **pull forward** a calculator whose tags/complexity would validate/refute a trending theory.
- **Theory ownership is shared:** the PM both *surfaces* candidate theories it spots in the logs and *accepts* a theory the user asserts, then finds calculators to test it.
- Runs at the start of every iteration or on request. **Advisory only** — the user confirms.

### Git & Issues discipline

- PM commits **only `docs/`**, via **path-scoped staging** (`git add docs/...`, never `git add -A`). Never sweeps up app code or agent-definition changes.
- Conventional messages: `docs(pm): ...`. End every message body with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- **Iteration boundaries = git tags** `iteration-NNNN` (zero-padded), pointing at the agent-definition commit the iteration is pinned to.
- **Ordering protocol:** (1) the user edits + commits the agent definitions; (2) the PM records that SHA, updates the log + `INDEX.md`, creates the tag, and commits its doc updates.
- **Issues:** the PM creates/labels issues with `gh`; it never closes them (PRs do). Linear history on `main`.

### Tools

`WebFetch` (scrape), `Read`/`Write`/`Edit` (docs), `Bash` (scoped `git` + `gh`).

---

## 3. `docs/` layout (target)

```
docs/
  INDEX.md                     # what docs/ is; the iteration/log concept; the Issues layer
  inventory.md                 # full calculator catalog + complexity + tags
  logs/
    INDEX.md                   # iteration registry (status, date, SHA, issues, outcome)
    iteration-0001/
      <calculator>.md          # per-calculator build + feedback (disjoint files)
  superpowers/specs/           # design specs (this document)
  superpowers/plans/           # implementation plans
```

(Task state is **not** in `docs/` — it lives in GitHub Issues.)

---

## 4. Forward-looking: fan-out compatibility (banked, not built now)

We begin one calculator at a time, sequentially. We preserve the ability to fan out later. **GitHub Issues already dissolve the hardest fan-out problem** from rev. 1 — there is no shared `PROGRESS.md` for parallel builds to conflict on; per-calculator state lives in independent issues, and each PR closes its own issue.

Two concurrency models remain available, both resting on the same invariant — **no two agents dangerously write the same file at once:**
- **Worktree-per-calculator** — isolation for free; each calculator → worktree → branch → PR → `Closes #N`.
- **Same-branch concurrent** — relies on **file-level locking** so an in-flight edit can't be clobbered; valid only if that safety exists.

Two design principles still constrain the (future) FE/BE agents:
1. **Disjoint files + serial reconcile.** Parallel work writes only to per-calculator files; the only serial aggregate left in `docs/` is `logs/INDEX.md`.
2. **Auto-discovered, self-contained calculators.** No central registration (no shared `routes.rb`/registry edit per calculator), so parallel additions never touch a shared file.

Pacing note: **fan-out width grows with agent maturity.** Early iterations stay narrow (n=1–2, sequential, tight feedback); widen as variance drops.

The `agents` issue queue is the natural input to a future autonomous fix-workflow (loop/cron over `agents`-labeled issues).

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

## 7. Prerequisites (completed during planning)

- GitHub remote `git@github.com:jayrav13/whizwheel.git` (private) wired as `origin`.
- Labels `engineering` (build line) and `agents` (deferred agentic-fix queue) created.
