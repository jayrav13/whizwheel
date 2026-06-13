# CLAUDE.md

**whizwheel** — a reimagining of [calculator.net](https://www.calculator.net) (a broad library of calculators, polished UI, **all math server-side**), built as an **experiment in agent-driven development.**

## Read these first

- **`docs/PRODUCT.md`** — what we're building, for whom (the vision).
- **`docs/ARCHITECTURE.md`** — how we build it (conventions). **Required reading before writing any app code.**
- **`docs/inventory.md`** — the calculator catalog (191 calculators; complexity + tags).
- **`docs/INDEX.md`** — the `docs/` layout and the iteration/log concept.

## The experiment (why this repo is unusual)

We build by iterating on **agent definitions** (`.claude/agents/`), *not* by hand-editing code. **When output disappoints, fix the agent definition — not the code.** The durable, improvable artifact is the agent. Expect heavy upfront investment in agents and docs; that is the point, not a detour.

## The agents

- **`pm`** (Opus) — project tracking. Owns `docs/` + GitHub Issues. Never writes app code or agent definitions; stewards `PRODUCT.md`. Runs a full-context ingestion at every launch.
- **backend** *(not built yet)* — calculator math in `app/calculators/`, per `ARCHITECTURE.md`.
- **frontend** *(not built yet)* — the UI.

Every build agent ingests `ARCHITECTURE.md` + `PRODUCT.md` before producing code.

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

## Running things

- **Tests:** `bin/rails test` (Minitest). **Coverage gate: 100%** via SimpleCov — the build fails below it.
- **CI:** `.github/workflows/ci.yml` — brakeman, rubocop, tests-with-coverage. **Must be green.**
- **Server:** `bin/rails server`.
- **Users/roles are CLI-managed** (no web UI), once the foundation exists: `bin/rails "users:create[name]"`, `"users:set_password[name]"`, `"admins:grant[name]"`, `"admins:revoke[name]"`.

## The rules that matter most

1. **Agent-first** — encode decisions in the agent definition, not ad-hoc code.
2. **Calculators are code, append-only** — deprecate, never delete (preserves historical comparability).
3. **No central registration** — add a calculator by adding a file; never edit a shared registry/route/table (keeps parallel builds conflict-free).
4. **Soft-delete, never hard-delete** user-facing data.
5. **The math layer is pure** (no DB, no request) — that's what makes 100% coverage achievable.
