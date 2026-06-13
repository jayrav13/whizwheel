# CLAUDE.md

**whizwheel** — a reimagining of [calculator.net](https://www.calculator.net) (a broad library of calculators, polished UI, **all math server-side**), built as an **experiment in agent-driven development.**

## Every agent inherits this file

This file is the shared contract for **all** work in this repo — the main session *and* every subagent.

- **Any agent or subagent must read `CLAUDE.md` (and the docs it points to) as its first action, before doing anything else.** Treat it as inherited context.
- **Subagents do not auto-inherit this file.** When you spawn a subagent, **point it at `CLAUDE.md`** (plus the relevant `.claude/agents/*.md` definition if that agent type isn't registered yet) in its prompt.
- **Every new agent definition** (`.claude/agents/*.md`) must begin with a step instructing it to read `CLAUDE.md`, `docs/ARCHITECTURE.md`, and `docs/PRODUCT.md`. The `pm` agent's "Launch protocol" is the model to copy.

## Read these first

- **`docs/PRODUCT.md`** — what we're building, for whom (the vision).
- **`docs/ARCHITECTURE.md`** — how we build it (conventions). **Required reading before writing any app code.**
- **`docs/DESIGN.md`** — the **BLEND** design system (tokens, type, components). **Required reading before any UI work.**
- **`docs/inventory.md`** — the calculator catalog (191 calculators; complexity + tags).
- **`docs/INDEX.md`** — the `docs/` layout and the iteration/log concept.

## The experiment (why this repo is unusual)

We build by iterating on **agent definitions** (`.claude/agents/`), *not* by hand-editing code. **When output disappoints, fix the agent definition — not the code.** The durable, improvable artifact is the agent. Expect heavy upfront investment in agents and docs; that is the point, not a detour.

## The agents

- **`pm`** (Opus) — project tracking. Owns `docs/` + GitHub Issues. Never writes app code or agent definitions; stewards `PRODUCT.md`. Runs a full-context ingestion at every launch.
- **backend** *(not built yet)* — calculator math in `app/calculators/`, per `ARCHITECTURE.md`.
- **`frontend`** (Opus) — the UI. Owns `app/views`, `app/helpers`, `app/assets` (Tailwind theme/tokens), and Stimulus controllers; builds to `DESIGN.md` (BLEND) and codes against the JSON envelope (`ARCHITECTURE.md §4`). Never writes calculator math, models, controller business logic, migrations, or routes.

Every build agent ingests `ARCHITECTURE.md` + `PRODUCT.md` before producing code; **UI builds also ingest `DESIGN.md`.**

## How work is tracked

- **Task state → GitHub Issues.** Labels: `engineering` (the build line), `agents` (deferred agentic-fix queue). PRs close issues with `Closes #N`.
- **Knowledge → `docs/`** (inventory, iteration logs, vision, conventions).
- **Iterations** are pinned to a committed agent set and tagged `iteration-NNNN`.

## Commit & git conventions (all agents)

- Branch off `main` for feature work.
- **Plain `git commit` — never add `-c commit.gpgsign=false`.** Signing is off; the override is a no-op we don't use.
- Conventional messages (`feat:`, `docs:`, `feat(pm):` …). End every commit body with:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- **Path-scoped staging** (`git add <explicit paths>`, never `git add -A`).
- A PR that finishes a calculator/issue closes it: `Closes #N`.

## Branching & PR workflow

Feature work follows **Issue → Branch → Commit → PR → Merge → Cleanup**:

- **Branch** off `main`, named **`fix/<issue#>-<brief-description>`** (e.g. `fix/4-app-foundation`). Prefer a **git worktree** (EnterWorktree) for isolation / concurrent sessions and the fan-out future; a plain branch is fine for a single linear effort.
- **PR** via `gh pr create`; put **`Closes #<issue>`** in the PR body; end the body with the Claude Code footer.
- **Merge with a merge commit, never squash** (`gh pr merge <pr> --merge`) — preserve the per-task commit story.
- **Never auto-merge** — merge only on explicit human instruction, after CI is green (see CI/CD monitoring).
- **After merge:** delete the remote branch, remove the worktree if one was used, and `git pull` on `main`.

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

## CI/CD monitoring

After **any** push or PR, the CI run must be watched to completion — never assume green.

- **Dispatch the `ci-monitor` subagent** to watch it (keeps the main session clean). Give it a branch, a commit SHA, or `--pr <n>`. It reports pass/fail and, on failure, the root cause. (Until `ci-monitor` is registered as a type, spawn a generic subagent and point it at `.claude/agents/ci-monitor.md` + this file — see "Every agent inherits this file".)
- Mechanics live in **`bin/ci-watch`** (`0`=pass, `1`=fail, `2`=pending, `3`=no run); the agent wraps it with diagnosis.
- **Visual gate (every PR).** `ci-monitor` reports *status* but is Bash-only — it can't *see*. After CI completes on **any** PR, the **main thread** pulls the screenshots with **`bin/ci-screenshots --pr <n>`** and **reviews them against `docs/DESIGN.md`** before merge — regardless of whether the diff looks UI-related (the CI/Linux render is a cheap cross-platform check that catches incidental regressions a code diff hides).
  - **Review every screenshot — never a sample.** The helper prints the count + a **sha256 manifest** so the set is enumerable; account for **each** shot. Either **view** it, or — against a baseline (`--baseline <dir>`) — let the byte-identical (sha256-equal) shots pass *deterministically* and **view only the CHANGED/NEW**. No silent skipping or vibe-sampling. On a docs-only PR this means a full baseline diff showing every shot `UNCHANGED` (CI renders are byte-stable run-to-run), not eyeballing a subset.
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

1. **Agent-first** — encode decisions in the agent definition, not ad-hoc code. Enforced by the **regeneration sweep**: every iteration rebuilds *all* prior calculators from their specs with the latest agents (a fan-out, one agent per calculator), so any fix living only in calculator code is erased — which forces every durable decision up into the agent/spec/test layer. See `ARCHITECTURE.md` (the build model) and `pm.md` (iterations).
2. **Calculators are code, append-only** — deprecate, never delete (preserves historical comparability).
3. **No central registration** — add a calculator by adding a file; never edit a shared registry/route/table (keeps parallel builds conflict-free).
4. **Soft-delete, never hard-delete** user-facing data.
5. **The math layer is pure** (no DB, no request) — that's what makes 100% coverage achievable.
