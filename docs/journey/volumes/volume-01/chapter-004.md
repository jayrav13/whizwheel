## Chapter 4 — The GitHub Issues pivot (2026-06-12)

Mid-stream, the user caught something:

> "should we not loop in GitHub Issues into this flow? … 2 key tags maybe could be 'engineering' and 'agents'."

This produced a clean **two-layer split**: **task state (the kanban) → GitHub Issues**; **knowledge (the lessons) → `docs/` in the repo**. The principle: the kanban may live off-git (it's a board); the *knowledge* stays in the repo so "git history is the ledger" still holds for what matters. `PROGRESS.md` was retired (issues replaced the board). Crucially, Issues also **dissolved the hardest fan-out problem** identified earlier — the user had asked:

> "would we be able to use agent fan-out or dynamic workflow to kick off all of the work and result in 10 or more PR's …" (and later) "we'll want to do a worktree approach."

With one issue per calculator and one PR closing it (`Closes #N`), parallel builds never contend on a shared progress file. Two forward-looking constraints were banked: **disjoint files + serial reconcile**, and **auto-discovered, self-contained calculators** (no central registration), so parallel builds stay conflict-free.

This pivot also added the PM's mandatory **full-context launch ingestion** and an explicit **Opus** pin — both recorded in the spec (rev. 2) and the agent.

**Agent-driven?** ✅ All changes landed in the spec + the PM agent.

---
