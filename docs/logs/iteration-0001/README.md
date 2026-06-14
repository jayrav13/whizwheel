# Iteration 0001

**Status:** closed
**Opened:** 2026-06-13
**Closed:** 2026-06-13
**Pinned agent SHA:** `c7796eb` (`main` HEAD at open)
**Tag:** `iteration-0001`
**Calculators:** Percentage (#30 backend / #31 frontend)

**Headline outcome:** Percentage shipped end-to-end (backend #32, page-serving #34,
frontend #35) — the first full `spec → build → measure` loop. Backend nailed the math +
validation contract (the `send`-dispatch multi-mode pattern dodging the unreachable-branch
100% gate); the FE page came out on-system but with **cramped mode pills** that its own
screenshot self-review **declared "roomy"** — a miscalibrated spacing bar. → iteration 0002
invests in a real DESIGN.md spacing system (and, following it, teeth for the FE self-review).

---

## Why this SHA

The iteration is pinned to **`c7796eb`** — the `main` HEAD at open, which captures the
current frozen agent set. The last *agent-definition*-touching commit was `4919ecb`
(spec:v1 formalization); `c7796eb` is a docs-only commit on top of it (Percentage bumped to
complexity 3), so the agent definitions at the tag are byte-identical to `4919ecb`'s. We pin
the boundary at HEAD because that is the fully-ingested, clean state the iteration opens
against.

## Baseline agent set (this is iteration 1 — no "since previous")

This is the first iteration of the experiment, so there is no prior agent set to diff
against. The agents in play at `c7796eb` are:

| Agent | Role |
|---|---|
| `project-manager-agent` (Opus) | Project tracking — owns `docs/` + GitHub Issues; never writes app code or agent definitions. |
| `backend` (Opus) | Server-side of the route — calculator math (`app/calculators/`), routes, controllers, models, migrations, the JSON envelope. Builds from each calculator's spec (its issue body). |
| `frontend` (Opus) | The UI — `app/views`, `app/helpers`, `app/assets` (Tailwind/BLEND), Stimulus controllers; codes against the JSON envelope. |
| `ci-monitor` | Bash-only CI watcher — reports pass/fail + root cause. |
| `dependabot-agent` | Report-only dependency-PR triage (GREEN-LANE / NEEDS-HUMAN). |
| `historian` | Keeps `JOURNEY.md` current. |

**spec:v1 is now in force** (`ARCHITECTURE.md §3.2`, formalized in `4919ecb` / PR #29): the
calculator spec **is** the `engineering` issue body, and the backend agent regenerates code
*from* that spec. Percentage (#30) carries the first `spec:v1` body.

## What this iteration builds

- **Percentage (#30)** — multi-mode, complexity 3. The first calculator built by the
  agent-driven loop. **n=1, no regeneration sweep** (no prior calculators exist).

The new build is the iteration's only evidence this turn (no prior-calculator deltas yet).
Per-calculator notes accrue in `docs/logs/iteration-0001/percentage.md` as the build lands.

## Per-calculator notes

| Calculator | Issues | File | Kind |
|---|---|---|---|
| Percentage | #30 (BE) / #31 (FE) | `percentage.md` | new build |
