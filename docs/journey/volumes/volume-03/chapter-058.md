## Chapter 58 — Two journey PRs merged, and a self-caught discipline slip: running `bin/ci-watch` inline instead of dispatching `ci-monitor` (2026-06-14)

With #47 in review, the user gave a compound instruction: *"Merge on CI success and then summarize all of the agents we now have that are specific to this repo and custom created for this project."* The assistant accepted merge-on-green (after the mandatory visual gate, expected byte-identical on a docs/agent-def-only change), and queued the agent-roster summary. The user then added that the held-back journey PR could merge too: *"Oh, the journaling/brainstorm can be merged"* — the historian's Chapter-56 PR **#46**, deliberately held in Chapter 56 to avoid two concurrent journey branches colliding.

### The slip, and the user catching it

Reaching to merge #46, the assistant started to check its CI by running `bin/ci-watch` directly. The user interrupted (*"[Request interrupted by user]"*) and asked the pointed question:

> "In that case, why not just send a ci-monitor to verify"

The assistant owned the slip without hedging:

> "Fair point — I broke my own discipline by running `bin/ci-watch` inline; the convention is to dispatch `ci-monitor` so CI mechanics stay out of the main thread. Doing it properly for #46:"

It then dispatched two `ci-monitor`s — one for #46 (the journey chapter) and one for #47 (the database-agent) — both reporting green across all five jobs. Both PRs were docs/`.md`-only with zero render surface, so the visual gate was treated as **N/A by file-scope** (recorded as reasoning, not skipped silently): *"#46 touches **only `JOURNEY.md`** — zero render surface … there's nothing for screenshots to regress."* Both merged with merge commits; `main` fast-forwarded; **issue #36 closed by #47**; the journey worktree and local branches cleaned up.

### The agent roster — the experiment's custom-agent inventory, recorded

The user's other request produced a full rundown of the seven repo-bespoke agents, organized by *who writes*: the **build line** (`backend` orange, `frontend` cyan — opus, own worktree, write app code), the **tracking & record** line (`project-manager-agent` blue, `historian` purple — write docs only), and the **report-only watchers** (`ci-monitor` green, `dependabot-agent` yellow, and the new `database-agent` pink — never write, no worktree). The assistant noted the patterns the roster reveals: opus for judgment-heavy roles, sonnet for the mechanical watchers; every *writer* gets an isolated worktree and every *report-only* agent is deliberately worktree-less; colors unique per agent (*"pink was the last free one — hence the new agent took it"*).

**Agent-driven? n/a (merges + a summary).** No artifact changed in this chapter beyond the two merges. The data point is a *discipline* one: a codified convention (dispatch `ci-monitor`, don't watch CI inline) was *violated by the main thread itself*, the human caught it, and the assistant owned it plainly — which set up the next chapter's fix at the right layer.

---
