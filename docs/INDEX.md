# whizwheel — docs/

This directory is the **knowledge layer** for whizwheel, owned by the **PM agent**
(`.claude/agents/pm.md`), the only writer here. It holds the durable record of *how the
project went* — distinct from app code (`app/`, `lib/`, …) and agent definitions
(`.claude/agents/`).

Task state (the kanban) is **not** here — it lives in **GitHub Issues**. The line:
the kanban may live off-git (it's a board); the knowledge stays in the repo. Iteration
logs reference issue numbers, so the repo tells the whole story on its own.

## Layout

| Path | What it holds |
|---|---|
| `inventory.md` | The full catalog of calculators on calculator.net, with complexity (1–5) and tags. Refreshed idempotently from the site. |
| `logs/` | One folder per iteration plus `logs/INDEX.md`. |
| `superpowers/specs/` | Design specs. |
| `superpowers/plans/` | Implementation plans. |

## The Issues layer

- **One `engineering` issue per calculator** to build, seeded from the inventory.
- **`agents` issues** are deferred work queued for a future agentic batch fix.
- PRs close issues with `Closes #N`. The PM creates and labels issues but never closes them.

## The iteration concept

An **iteration** is the rebuild of some `n` sequentially-next calculators (a set of
selected `engineering` issues) using a **frozen, committed set of agent definitions**
(pinned to a git commit/SHA).

- **Opens** when the agent set is locked and `n` + the calculators are chosen (PM
  recommends, user confirms). The PM tags the boundary `iteration-NNNN` and records the
  agent SHA.
- **Lives** as `logs/iteration-NNNN/`, accruing per-calculator build outputs and feedback.
- **Closes** when we decide we have learned enough to change the agents. That decision
  triggers the agent edit + commit, which opens the next iteration.

`logs/INDEX.md` registers all iterations. Per-calculator notes live in disjoint files
(`logs/iteration-NNNN/<calculator>.md`) so fan-out never collides; `logs/INDEX.md` is the
one serial aggregate.
