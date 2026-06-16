## Chapter 122 — "Any low hanging fruit?": a backlog scan, three quick wins, and a fan-out to three agents (2026-06-15)

A new session opened on a deliberately small, open-ended prompt — and it is a useful chapter precisely because it shows the orchestration machinery applied not to an iteration or a marquee feature, but to ordinary **backlog grooming**: surface the cheap-but-valuable open issues, let the operator pick, fan them out to the right specialist agents. No new conventions were minted here; this is the experiment running in its steady state.

### The prompt: "any low hanging fruit?"

The operator opened with a single line:

> **"any low hanging fruit?"**

The orchestrator's instinct was correct and on-protocol: it did **not** start eyeballing issues itself, but reached for the backlog specialist —

> **"I'll pull the current backlog through the `github-agent` to spot the genuine quick wins."**

This is the CLAUDE.md routing rule honored by reflex: backlog summaries (Now/Later + effort) route through `github-agent`, the caller supplies intent, the agent handles the GitHub conventions. The orchestrator dispatched it in the background and reported it would relay the candidates when they returned.

### The github-agent's first attempt failed — claiming no Bash

The first dispatch came to rest without doing the job. Its returned result was a request for a capability it believed it lacked:

> **"I need Bash access to run the `gh` CLI commands required for this task. … the `gh` CLI is the **only** path to live GitHub data. There is no other tool here that can substitute for it. … Could you grant Bash access so I can run the two required `gh` commands?"**

This is worth recording as a recurring *agent-capability mis-read*: the `github-agent` is a report/action-only agent whose entire job is running `gh`, yet the dispatched instance came to rest convinced it had no Bash. The orchestrator's first reaction was to route around it — *"The agent hit a permissions wall. Let me just pull the data directly."* — but the operator **interrupted that** and steered it back to the proper channel:

> **"Try gh agent again"**

A small but pointed correction: rather than let the orchestrator do the backlog scan inline (which would pull GitHub mechanics into the main thread, exactly what the agent boundary exists to prevent), the operator insisted the second attempt go back through the specialist. The orchestrator re-dispatched **with an explicit nudge that Bash/`gh` is available**, and the second attempt succeeded. (The contrast with Chapter 121's #140 silent-death pattern is instructive: there the agent vanished without a verdict; here the agent *returned* but with a false self-assessment of its tools — a different failure mode, fixed the same way, by re-dispatch.)

### The scan: a tiered quick-win list, no PRs in flight

The successful run opened with the load-bearing fact that nothing was blocked —

> **"No open PRs exist, so none of these issues are blocked."**

— and returned a clean, **tiered** quick-win list, easiest-and-most-valuable first, explicitly omitting the strategic/architectural items. The orchestrator relayed it in two tiers:

**Knock-out-now tier (low effort, high value):**
- **#231 — `bin/merge-cleanup` cd footgun** (engineering): branch-delete + main-checkout fail when the shell's cwd is *inside* the worktree being removed — **the exact friction Chapter 121 had hit and finished by hand.** The issue ships its own fix (a `cd "$(git rev-parse --show-toplevel)"` before `git worktree remove`, plus making a failed delete a real error instead of a silent "already gone"). ~10–20 lines of shell; fires on basically every interactive merge.
- **#229 — flaky admin-stats system test** (engineering): the post-login `assert_link "Admin"` race under parallel `test:system` — **the pre-existing flake Chapter 121 had flagged for filing.** Fix is a shared `sign_in_as` helper that blocks on the post-login redirect. Test-layer only, exact file already identified.
- **#213 — blank string defeats `default:0`, crashes compute** (engineering): a `before_validation` coercion in `Calculators::Base` so a blank raw value for a defaulted numeric attribute becomes its default (or a 422 instead of a 500). One place in `Base` covers every calculator present and future; pairs with the already-shipped #109/#110.

**Clear-scope tier (low–med):** #214 (registry-active calc with no FE page 500s → rescue `MissingTemplate`), #224 (the `ci-watch`/`ci-screenshots` false NO-RUN SHA-lookup bug — the QA-reliability friction filed in Chapter 120), and #112 (the DESIGN.md financial-color decision, PM-owned, where *the edit is trivial; the decision is the work*).

The orchestrator's own recommendation, offered unprompted:

> **"#231 and #229 are the cleanest pure wins — both self-diagnosing, both tooling/test-layer (no calculator code, no regen implications), high friction-reduction. #213 is the best product win (systemic 500 fix)."**

Two of the three top picks are friction the *previous* chapter generated and flagged in passing — the footgun the orchestrator hit during the #227 cleanup, and the system-test race the frontend agent noticed during the #228 regen. The backlog had captured them; the scan surfaced them; the loop closed.

### The decision: "send all 3"

The operator picked the entire knock-out-now tier:

> **"send all 3: 231, 229, 213, separate relevant subagents"**

The instruction *"separate relevant subagents"* is the crux — three issues, three **independent** dispatches, each to the agent that owns that layer, in parallel. This is the "stay ahead of the airplane" orchestration discipline applied to grooming: three unblocked, non-conflicting tasks, so all three fire at once rather than serially.

### The fan-out: backend ×2, frontend ×1

The orchestrator routed each issue to its correct owner by CLAUDE.md's turf lines:

| Agent | Issue | Owns |
|---|---|---|
| `backend` | **#231** | `bin/merge-cleanup` cd-into-worktree fix (shell tooling / `bin`) |
| `backend` | **#213** | `Calculators::Base` blank-string coercion (the math/validation base class) |
| `frontend` | **#229** | shared `sign_in_as` system-test helper (frontend's system-test turf) |

The routing is precise: #231 is shell tooling under `bin/` and #213 is server-side-of-the-route validation in the calculator base class, both squarely `backend`; #229 is a **system-test** helper, and system tests + the visual gate are the `frontend` agent's territory. Each agent was dispatched to branch in its own worktree, ship tests, and open a PR with `Closes #N` — the standard Issue → Branch → Commit → PR machinery, fanned three wide. The orchestrator emitted the journaling marker — *"📝 journaling that in the background"* — and fired the historian alongside the three builds.

Critically, the orchestrator pre-committed to the gate before any PR existed:

> **"The moment a PR lands I'll dispatch the `quality-assurance-agent` to gate it — and report back PR URLs and verdicts as they come in."**

So the QA gate is queued by intent for all three the instant their PRs appear — no agent-opened PR slips past ungated (the CLAUDE.md rule), and nothing merges without explicit human instruction.

### Agent/doc-driven? — N/A; this is the machinery, not a harvest

This chapter mints no convention and edits no agent definition — it is the experiment in **steady-state operation**, which is itself evidence worth recording. The "does this work?" signal here is procedural: a one-line open-ended prompt was resolved entirely through the agent boundaries (backlog scan → `github-agent`; fixes → the layer-owning build agents), the orchestrator routed three independent tasks to three correct specialists in parallel without doing any of the work itself, and two of the three picks were friction the *previous* session had generated and the backlog had faithfully captured. The one wrinkle — the `github-agent`'s false "I have no Bash" self-report — was caught by the operator (*"Try gh agent again"*) and fixed by re-dispatch rather than by the orchestrator absorbing the task inline, preserving the boundary the failure tempted it to cross. At journal time all three builds plus this historian run were in flight; the QA gate and merges are the next chapter's material.

---
