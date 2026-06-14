# CLAUDE.md

**whizwheel** — a reimagining of [calculator.net](https://www.calculator.net) (a broad library of calculators, polished UI, **all math server-side**), built as an **experiment in agent-driven development.**

## Every agent inherits this file

This file is the shared contract for **all** work in this repo — the main session *and* every subagent.

- **Any agent or subagent must read `CLAUDE.md` (and the docs it points to) as its first action, before doing anything else.** Treat it as inherited context.
- **Subagents do not auto-inherit this file.** When you spawn a subagent, **point it at `CLAUDE.md`** (plus the relevant `.claude/agents/*.md` definition if that agent type isn't registered yet) in its prompt.
- **Every new agent definition** (`.claude/agents/*.md`) must begin with a step instructing it to read `CLAUDE.md`, `docs/ARCHITECTURE.md`, and `docs/PRODUCT.md`. The `project-manager-agent`'s "Launch protocol" is the model to copy.

## Read these first

- **`docs/PRODUCT.md`** — what we're building, for whom (the vision).
- **`docs/ARCHITECTURE.md`** — how we build it (conventions). **Required reading before writing any app code.**
- **`docs/DESIGN.md`** — the **BLEND** design system (tokens, type, components). **Required reading before any UI work.**
- **`docs/INVENTORY.md`** — the calculator catalog (191 calculators; complexity + tags).
- **`docs/INDEX.md`** — the `docs/` layout and the iteration/log concept.

## The experiment (why this repo is unusual)

We build by iterating on **agent definitions** (`.claude/agents/`), *not* by hand-editing code. **When output disappoints, fix the agent definition — not the code.** The durable, improvable artifact is the agent. Expect heavy upfront investment in agents and docs; that is the point, not a detour.

## The agents

- **`project-manager-agent`** (Opus) — project tracking. Owns `docs/` + GitHub Issues. Never writes app code or agent definitions; stewards `PRODUCT.md`. Runs a full-context ingestion at every launch.
- **`backend`** (Opus) — everything server-side of the route. Builds/regenerates calculator math (`app/calculators/`) from each calculator's spec (its GitHub issue body), and owns routes, controllers, models, migrations/`db`, initializers, `lib`, jobs, and rake tasks; codes the JSON envelope (`ARCHITECTURE.md §4`). Creates its own worktree per task. Never writes client-side-of-the-route code (ERB, CSS, JS, view helpers).
- **`frontend`** (Opus) — the UI. Owns `app/views`, `app/helpers`, `app/assets` (Tailwind theme/tokens), and Stimulus controllers; builds to `DESIGN.md` (BLEND) and codes against the JSON envelope (`ARCHITECTURE.md §4`). Never writes calculator math, models, controller business logic, migrations, or routes.

Every build agent ingests `ARCHITECTURE.md` + `PRODUCT.md` before producing code; **UI builds also ingest `DESIGN.md`.**

## Orchestration — stay ahead of the airplane (main thread)

The main thread is an **orchestrator**: proactively **catch and kick** any *unblocked* work into the background instead of waiting idle. The moment a PR exists, dispatch its `ci-monitor`; journal at each milestone (the `historian`); run independent builds in parallel. **Only the genuine critical path should gate — everything parallelizable should already be running.** After each action, scan for newly-unblocked background tasks and fire them without being asked; if something *can't* be backgrounded yet, say why (e.g. "no PR exists yet"). (Subagents do one task; this discipline is the orchestrator's.) This proactive multi-agent orchestration is itself part of what the experiment is honing.

Concretely, this means you **default to backgrounding dispatched agents** (`run_in_background`). The main thread stays free to catch newly-unblocked work and the user can interject mid-flight — and because you act on each completion notification, backgrounding never means ignoring a result, only not blocking on it. Foreground (blocking) dispatch is the **exception** — and idling is **not** a reason to use it: prefer backgrounding even when the main thread will only sit and wait. Reserve foreground for when a backgrounded run could be **cut off before its result lands** (the canonical case is the **end-of-session historian** — a backgrounded run may be killed before it commits, so the close-out checklist waits for it).

## How work is tracked

- **Task state → GitHub Issues.** Labels: **`backend`** + **`frontend`** (the per-calculator build line — each calculator gets *both*, one issue per layer, both carrying the full `spec:v1` body), `engineering` (non-calculator infra/agent/tooling work), `agents` (deferred agentic-fix queue). PRs close issues with `Closes #N` — a calculator's backend PR closes its `backend` issue, its frontend PR closes its `frontend` issue.
- **Knowledge → `docs/`** (inventory, iteration logs, vision, conventions).
- **Iterations** are pinned to a committed agent set and tagged `iteration-NNNN`.
- **Everything lands via PR — never push directly to `main`.** This includes `docs/` and iteration bookkeeping by the PM and `JOURNEY.md` by the historian: branch → commit → PR → human merge. `main` is protected; no agent (or the main thread) pushes to it directly.

## The calculator registry

The calculator catalog lives in a **DB table — derived, never hand-maintained.** Its source of truth is **`docs/INVENTORY.md`** (the PM-maintained catalog: name, category, complexity, tags, build state); an **idempotent ingest** projects that into the `calculators` table, upserting by `slug`. Because the source is the centrally-maintained inventory and the table is *generated*, adding a calculator stays "add a file" and **no build edits the registry** — rule #3's conflict-free promise holds (it's a derived projection, not a shared edit).

- **Refresh is CLI-driven:** an idempotent ingest rake task (e.g. `bin/rails calculators:ingest`), re-runnable and convergent. Fresh DBs populate via `db/seeds.rb`; **tests use fixtures** — CI builds the DB with `db:test:prepare`, which loads `db/structure.sql` and runs **neither migrations nor seeds**, so registry data for tests comes from fixtures, and the schema-creating migration must **not** run the ingest itself.
- **Code is authoritative for what's real.** A row only links/renders if its `slug` resolves to a `Calculators::X` class (`Base.lookup`); the ingest **reconciles against the code** so the DB can never point at a calculator that isn't built (the DB can drift; the code cannot).
- **Deprecate, never delete** (rule #4): a calculator dropped from the catalog is marked, not removed.
- **Ownership:** `backend` builds the machinery (migration, model, ingest lib + rake task, fixtures — its existing `db`/migrations/models/rake turf, with ingest logic in a `lib` service so it's testable to the 100% gate); `database-agent` **operates** the refresh and reports drift (its definition is being extended from pure-inspector to run this one sanctioned ingest).

## Iteration delivery lifecycle

An **iteration** (`iteration-NNNN`) is the unit of delivery. Every iteration runs the same six phases, in order:

1. **Open** — Tag `iteration-NNNN` at the current agent SHA (pin-at-open). Define scope: the **regen set** (which already-built calculators to rebuild, and which **layer(s)** — see "Layer-scoped regen") plus the **new-build set** (new calculators — **may be empty**). The PM opens the iteration log.
2. **Build (fan out)** — In parallel, via worktree → PR → CI + visual gate → human merge: regenerate the in-scope priors from their specs with the pinned agents, and build any new calculators (a calculator's backend lands before its frontend).
3. **Evaluate** — Review what was delivered against intent: UI against `DESIGN.md`/BLEND (operator + the visual review), output correctness, and parity. This phase produces the feedback.
4. **Harvest** — Apply the agent / process / design changes the evaluation surfaced: edit `.claude/agents/*`, `DESIGN.md`, `CLAUDE.md`, and specs; file issues for the larger items. This is the experiment's core loop — **fix the agent, not the code** — and it is an explicit phase **before close**, not an afterthought. The harvest lands on `main` and becomes the agent set the next iteration pins at.
5. **Journal** — The historian journals the iteration, **including its harvest**.
6. **Close** — The PM updates `docs/INVENTORY.md` and closes the iteration log (which now records the harvest).

The **next iteration** opens pinned at the post-harvest agents; its regen sweep is what **propagates** the previous harvest across the catalog. Its new-build set is the operator's call and **may be empty — a regen-only iteration** — when the prior harvest is substantial enough to warrant a round on its own (or for any reason the operator chooses).

**Layer-scoped regen.** A regen sweep rebuilds only the **layer(s) whose agents/conventions changed** — frontend-only, backend-only, or both. A harvest that only touched the frontend agent / `DESIGN.md` needs only a frontend regen.

## Commit & git conventions (all agents)

- Branch off `main` for feature work.
- **Plain `git commit` — never add `-c commit.gpgsign=false`.** Signing is off; the override is a no-op we don't use.
- Conventional messages (`feat:`, `docs:`, `feat(project-manager-agent):` …). End every commit body with:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- **Path-scoped staging** (`git add <explicit paths>`, never `git add -A`).
- A PR that finishes a calculator/issue closes it: `Closes #N`.

## Branching & PR workflow

Feature work follows **Issue → Branch → Commit → PR → Merge → Cleanup**:

- **Branch** off `main`, named **`fix/<issue#>-<brief-description>`** (e.g. `fix/4-app-foundation`). Prefer a **worktree** for isolation (see **Worktrees** below) — required for the fan-out future, optional for a single linear effort.
- **PR** via `gh pr create`; put **`Closes #<issue>`** in the PR body; end the body with the Claude Code footer.
- **Merge with a merge commit, never squash** (`gh pr merge <pr> --merge`) — preserve the per-task commit story.
- **Never auto-merge** — merge only on explicit human instruction, after CI is green (see CI/CD monitoring).
- **After merge — use `bin/merge-cleanup <pr>`** (it pins the order below; do not hand-run the steps). **Order matters:** a branch can't be deleted while a worktree references it, so worktree removal must come *before* branch deletion — otherwise `gh pr merge --delete-branch` aborts on the local delete and **silently skips the remote delete too**, leaving a stale remote branch. The sequence the script runs: (1) `gh pr merge <pr> --merge` (**no** `--delete-branch`); (2) `git worktree remove .claude/worktrees/<slug>` if one was used; (3) `git branch -D <branch>` **and** `git push origin --delete <branch>` (local *and* remote, each its own step); (4) `git checkout main && git pull --ff-only && git worktree prune`.

## Worktrees

Worktrees give each effort an isolated checkout so concurrent sessions — and the **fan-out sweep** (one build agent per calculator, `ARCHITECTURE.md §3.1`) — never collide on a shared working tree. They live under **`.claude/worktrees/<name>/`** (gitignored), each on its own `fix/<issue#>-<desc>` branch.

There are **two lanes**, by who is doing the work:

- **Interactive / main-thread sessions** use the **`EnterWorktree`** tool (creates `.claude/worktrees/<name>/` + the branch) and **`ExitWorktree`** with `action: "remove"` at cleanup.
- **Every dispatched agent that *writes* creates its own worktree as its first action** — the build agents, the **PM**, the **historian**, and any future writing agent. **This is the standing default: you do not need to be told per-task — reading this file (your Step 0) IS the instruction.** Use the **git CLI** (`EnterWorktree`'s session-cwd semantics are unproven inside a subagent; `git worktree add` is deterministic and always works):
  ```bash
  git worktree add .claude/worktrees/<slug> -b <branch> main   # build: fix/<issue#>-<desc>;  docs: docs/<topic>
  ```
  The agent then works inside that path (absolute paths), commits, **pushes, and opens its PR from the worktree — it never merges and never pushes to `main`**. We do **not** use the `Agent` tool's dispatch-time `isolation: "worktree"`; the agent owns its own isolation lifecycle.
- **Report-only agents** (`ci-monitor`, `dependabot-agent`) never write, so they **do not** create a worktree.
- **Removal happens at the standard post-merge cleanup** (main-thread / human, after the human merges the PR) via **`bin/merge-cleanup <pr>`**, which removes the worktree **before** deleting the branch (so the delete can't fail) and deletes the local *and* remote branch. The order is load-bearing — see the "After merge" bullet above. (Manual equivalent, in order: `git worktree remove .claude/worktrees/<slug>` — or `ExitWorktree action: "remove"` — then delete local + remote branches, then `git pull --ff-only` on `main`.) An agent that only opened a PR leaves its worktree in place for that cleanup.

## Running things

- **Tests:** `bin/rails test` (Minitest). **Coverage gate: 100%** via SimpleCov — the build fails below it.
- **Every feature ships tests** — backend (unit/reference-value + integration) **and** frontend (integration render/state tests **plus** a system test + full-page screenshot **visual review**). No feature merges without them. Full taxonomy + the `NO_COVERAGE` system-pass rule: **`ARCHITECTURE.md §11`**.
- **CI:** `.github/workflows/ci.yml` — brakeman, rubocop, tests-with-coverage, system-test (screenshots). **Must be green.**
- **Start the app:** `bin/rails db:prepare && bin/dev` — details in "Starting the app" below.
- **Users/roles are CLI-managed** (no web UI), once the foundation exists: `bin/rails "users:create[name]"`, `"users:set_password[name]"`, `"admins:grant[name]"`, `"admins:revoke[name]"`.

## Starting the app

When asked to **spin up / run / start the app**:

1. **Migrate if needed:** `bin/rails db:prepare` — idempotent: creates the DB if absent, applies any pending migrations, and runs seeds (`db/seeds.rb`, e.g. the ADMIN `RoleType`). Safe to run every startup.
2. **Start the server:** `bin/dev`. JS is **importmap** (no build step), but **CSS is Tailwind** (`tailwindcss-rails`, a standalone binary — no Node), so `bin/dev` runs **foreman** from `Procfile.dev`: `web` (the Rails server) + `css` (`tailwindcss:watch`, which rebuilds `app/assets/builds/tailwind.css` on change). The built CSS is gitignored; CI builds it with `bin/rails tailwindcss:build`. Serves on http://localhost:3000.

There is no sign-up. To log in, create a user via the CLI first: `bin/rails "users:create[name,password]"` (and `bin/rails "admins:grant[name]"` for admin).

### Starting the app headlessly

`bin/dev` is for **interactive** development; it **fails in a non-interactive / backgrounded shell** (an agent or CI-like session). `bin/dev` runs foreman over `Procfile.dev`, and in a non-TTY shell `tailwindcss:watch` exits 0 right after start — foreman's "if any process exits, stop all" then SIGTERMs Puma, so the whole app comes down ~1s after boot even though Puma was healthy.

For headless standups (screenshotting, smoke-testing a page, letting a remote user view the app) use **`bin/serve-headless`** instead. It skips foreman: `db:prepare` → `tailwindcss:build` (compile CSS **once** — no watcher) → `exec bin/rails server` (just Puma, so nothing tears it down). Serves on http://localhost:3000 (override with `PORT`). Then poll `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` until `200`. Trade-off: no CSS hot-reload — re-run `bin/rails tailwindcss:build` after a style change.

## CI/CD monitoring

After **any** push or PR, the CI run must be watched to completion — never assume green. **This verification is always delegated to `ci-monitor`; the main thread does not check CI itself.** This applies to **every** PR, **including one opened by a dispatched agent** (e.g. the historian's `JOURNEY.md` PR, or a build agent's) — the agent that opens a PR does not monitor its own CI, so the **orchestrator** must dispatch `ci-monitor` the moment such a PR exists. Do not let an agent-opened PR slip past unwatched.

- **Always dispatch the `ci-monitor` subagent** to watch it — for *every* CI check, status glance included (this keeps CI mechanics and log/diagnosis tokens out of the main context). Give it a branch, a commit SHA, or `--pr <n>`. It reports pass/fail and, on failure, the root cause. **The main thread MUST NOT run `bin/ci-watch` itself** — there is no "quick single-shot glance" exception; a single dispatch is the cheaper, cleaner default, and a judgment-call carve-out just re-opens the loophole. (`ci-monitor` is a registered agent type — dispatch it by name.)
- Mechanics live in **`bin/ci-watch`** (`0`=pass, `1`=fail, `2`=pending, `3`=no run) — that script is **`ci-monitor`'s tool, not the main thread's**; the agent wraps it with diagnosis.
- **Visual gate (every PR).** `ci-monitor` reports *status* but is Bash-only — it can't *see*. After CI completes on **any** PR, the **main thread** accounts for the render via **`bin/ci-screenshots --pr <n>`** before merge. The gate is **never skipped** — but how it resolves depends on whether the PR can move a pixel:
  - **UI-surface PR** — it touches `app/views`, `app/helpers`, `app/assets`, `app/javascript`, a layout, **or the math of an existing calculator that already has a built page** (our pages render backend results, so editing a live calculator changes its page). **View** every CHANGED / NEW shot and **review it against `docs/DESIGN.md`**.
  - **Non-UI PR** — it touches none of the above (docs, infra, agent definitions, CI config, or a *new* calculator whose page does not exist yet). Run the **baseline diff** (`--baseline <dir>`) and **confirm every shot is `UNCHANGED`** (sha256-equal). This *proves* no pixel moved rather than asserting it from the file diff — seconds, no image tokens — and is **still mandatory**: a non-UI PR that unexpectedly reports a CHANGED / NEW shot is a surprise regression, so stop and view it before merge.
  - **Review every screenshot — never a sample.** The helper prints the count + a **sha256 manifest** so the set is enumerable; account for **each** shot — either viewed (UI-surface) or baseline-`UNCHANGED` (non-UI). No silent skipping or vibe-sampling.
  - (Scale-up: a vision-capable review subagent so image tokens stay out of the main context.)
- **Never auto-merge.** A green PR merges only on explicit human instruction.

## Dependency updates (Dependabot)

Dependabot opens dependency-bump PRs. Don't triage them by hand in the main thread —
**dispatch the `dependabot-agent`** (report-only; keeps the chore out of context). It
verifies each is a clean bump, checks CI, classifies the bump (patch/minor/major) + blast
radius, reads the changelog, and returns a per-PR verdict: **GREEN-LANE** (CI green +
patch/minor + low blast radius — a CI action or dev/test gem) or **NEEDS-HUMAN** (any major,
any runtime/app gem, or red CI).

- **Policy is human-gated.** The agent **recommends**; it never merges. You merge GREEN-LANE
  PRs on a glance; NEEDS-HUMAN ones get a real look. (A narrow auto-merge lane is a possible
  future opt-in, not active — the never-auto-merge rule stands.)
- **It may auto-rebase a stale PR** — its one write-action: when a Dependabot branch is behind
  `main`, it posts `@dependabot rebase` so CI re-runs against current reality. Safe because it
  only refreshes the PR *branch*, never `main` — categorically different from auto-merge.
- Until `dependabot-agent` is a registered type, dispatch a generic subagent pointed at
  `.claude/agents/dependabot-agent.md` + this file.

## JOURNEY.md — the experiment log

`JOURNEY.md` (repo root) is the detailed, running record of this experiment — answering "does this work?".

- **Main thread only.** At the start of a fresh session, read `JOURNEY.md` while responding to the first prompt, unless it is already in context. **Subagents do NOT read it** — they don't need the saga and it would waste their context.
- **You (the main thread) keep it current.** At each meaningful decision or pivot, fire the **`historian`** agent **in the background** (`run_in_background: true`) to journal it. Emit one short visible line when you do — a marker such as `📝 journaling that in the background` — then continue immediately; never block on it, and handle its completion quietly (surface only errors). The historian reads the session transcript + `JOURNEY.md`'s coverage anchor and writes the gap itself — you do **not** push it context.
- Until `historian` is a registered type, fire a generic background subagent pointed at `.claude/agents/historian.md` + this file.

## End of session

Run this checklist before a session closes. The user will try to prompt you ("end session") — do it then. This list will grow.

1. **Dispatch the historian — and let it finish.** Journal everything since its coverage anchor. Unlike mid-session journaling, **wait for it to complete** (do *not* background it): the session is closing, so a backgrounded run may be cut off before it commits. Confirm the new anchor + commit.
2. **Verify no unstaged files.** Run `git status`; ensure nothing meaningful is left uncommitted or unstaged. Surface anything that is, so leaving it is a deliberate choice.

## The rules that matter most

1. **Agent-first** — encode decisions in the agent definition, not ad-hoc code. Enforced by the **regeneration sweep**: an iteration rebuilds the in-scope prior calculators from their specs with the latest agents (a fan-out, one agent per calculator — scope and layer set by the iteration, see "Iteration delivery lifecycle"; a sweep may be layer-scoped or even regen-only), so any fix living only in calculator code is erased — which forces every durable decision up into the agent/spec/test layer. See `ARCHITECTURE.md` (the build model) and `project-manager-agent.md` (iterations).
2. **Calculators are code, append-only** — deprecate, never delete (preserves historical comparability).
3. **No hand-edited central registration** — add a calculator by adding a file; never hand-edit a shared route/table to register it (keeps parallel builds conflict-free). A *derived* registry is fine: the catalog is projected into a DB table by an idempotent ingest from `docs/INVENTORY.md` (see "The calculator registry"), so builds never touch it — the registry is generated, not a shared edit.
4. **Soft-delete, never hard-delete** user-facing data.
5. **The math layer is pure** (no DB, no request) — that's what makes 100% coverage achievable.
