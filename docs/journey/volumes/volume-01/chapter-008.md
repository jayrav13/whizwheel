## Chapter 8 — CLAUDE.md and inheritance (2026-06-13)

The user: *"we don't have a CLAUDE.md file. Can you consider any other documentation we might want."* Created `CLAUDE.md` as a lean **router + rulebook** (read-these-first pointers, the experiment's discipline, the agent roster, commit conventions, the five rules that matter most) and rewrote the boilerplate `README.md`. Then a precise extension:

> "can we just make it more explicit to all agents that they should inherit from CLAUDE.md … it'll work now when you spawn a generic subagent … and it'll codify this in both directions for the future."

So `CLAUDE.md` now declares it is inherited by *all* agents/subagents, instructs that spawned subagents be pointed at it (they don't auto-inherit it), and requires every new agent definition to read it first. The PM's launch protocol was updated to read `CLAUDE.md` too. This is also where the project-wide commit conventions live — including a real lesson learned: **plain `git commit`, never the `-c commit.gpgsign=false` override** (signing was off; the override was a no-op the user asked us to drop).

**Agent-driven?** ✅ Conventions codified in the file all agents inherit.

---
