## Chapter 16 — Adopting tenor's branching strategy (2026-06-13)

Before pushing, the assistant **held the push** to honor a prior request — *"you asked me to check tenor's branching strategy first."* It reviewed the sibling project `../tenor` and summarized its full **`Issue → Branch → Commit → PR → Merge → Deploy → Cleanup`** workflow: GitHub issue with a Success-Criteria checklist; *always* a git worktree (`.claude/worktrees/<name>/`) for concurrent-session safety; branch named **`fix/<issue#>-<brief-description>`**; **`Closes #<issue>`** in commit bodies; `gh pr create` with **merge commits, never squash**; `bin/ci-watch`, never auto-merge; merge only on explicit say-so; deploy-watch; then cleanup.

It laid the comparison against the just-built `foundation` branch in a table — the deltas being branch naming (`foundation` vs `fix/N-desc`), no worktree, and `Closes #N` planned for the PR body rather than the commits — and kept the project's *intentional* differences (the `engineering`/`agents` label taxonomy; the `Co-Authored-By: Claude Fable 5` trailer, *"per our env's instruction"*). Its recommendation: **adopt tenor's flow, keep the intentional differences** — concretely: rename `foundation` → `fix/4-app-foundation`; close #4 via the PR body (adding `Closes #4` retroactively *"means rewriting 8 commits; the PR-body close is equivalent and clean"*); merge-commit-not-squash to *"preserve the per-task commit story (which this experiment values)"*; adopt worktrees *going forward* but not retrofit; and **codify a "Branching" section in CLAUDE.md.**

The user approved all of it, and stacked on two more requests:

> "1, 2, 3, 4, and 5 yes
>
> Also, add a section in CLAUDE.md that whenever I ask you to spin up the app, fire up whatever the appropriate server startup command is - maybe here it's foreman run start? Let's review
>
> We may want to verify that migrations happen if needed on startup too
>
> So let's rename / push / open PR with Closes #4 and monitor CI. Then, add all of the listed items. Then, add a section in CLAUDE.md on what it means to start up the app. Then, successfully start it up so we can see the results and test"

**Agent-driven?** ✅ A cross-project convention was reviewed, adapted (not copied wholesale), and slated for the inherited contract.

---
