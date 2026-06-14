## Chapter 3 — The PM agent: the first agent built (2026-06-12)

The user's first build instinct was not a calculator but an instrument to measure the experiment:

> "I think we start by building the project manager agent out and fetching all calculators … our project manager agent will generate a blog post style 'how did we do' article as the output."

Through brainstorming, the PM agent's shape was settled — a **scribe + reporter + advisor** that owns `docs/`, with these capabilities the user enumerated: an idempotent **inventory** of all calculator.net calculators; progress tracking; **iteration logs** (an iteration = rebuilding *n* calculators under a frozen, committed set of agents); **synthesis at three lengths** (exec summary / progress / blog post); and **sequencing advice** that can reorder by complexity or "pull forward a calculator that would validate a trending theory."

Key sub-decisions:
- **Write boundary:** the PM writes *only* `docs/` — never app code, never agent definitions.
- **Git as ledger.** The user asked, *"should the PM be committing in order to close the loop on docs then?"* — yes; the PM commits only `docs/` via path-scoped staging, with iteration boundaries marked by git tags `iteration-NNNN`.
- **Model:** pinned to **Opus** (the PM does the heavy reasoning).
- **Launch protocol:** every invocation begins with a deterministic, no-shortcuts ingestion of all of `docs/` + full repo/Issues state.

**The build** used subagent-driven development (a fresh subagent per task). Notably, the harness flagged each `.claude/agents/pm.md` commit as possible "self-modification" — a context-blind heuristic, since building the PM was the authorized purpose of the session. The agent was verified *behaviorally*: a fresh subagent told to *read and adopt* `pm.md` then scraped calculator.net and produced **191 calculators** (Financial 71, Fitness & Health 28, Math 38, Other 54), each with a 1–5 complexity rating and tags, committed docs-only. It also gave a sensible first-build recommendation (Percentage + BMI) and correctly **refused** to edit `app/views`, citing the agent-first discipline.

**A refinement that proved the loop:** asked whether to seed all 191 calculators as issues, the user chose incremental creation. The fix was a six-line edit to `pm.md`'s capability section, committed as `feat(pm):` — *the code never changed; the agent did.*

**Agent-driven?** ✅ The first agent, built and verified by agents, corrected by editing the agent.

---
