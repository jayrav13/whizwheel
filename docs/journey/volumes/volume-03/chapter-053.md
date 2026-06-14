## Chapter 53 — "Stay ahead of the airplane" moves from personal memory into the shared contract (2026-06-14)

In Chapter 51 the user had banked an operating principle — *"always stay ahead of the airplane"* (proactively background any unblocked work) — and the assistant had saved it to **personal memory**. This session the user asked the right follow-up about *where* such a rule should live:

> "Can the note about kicking things off when able actually be moved to something in the repo instead of memory? Will it maintain its efficacy?"

The assistant's answer was yes, and that the repo is the *better* home:

> "This is **main-thread orchestration** guidance (subagents do one task; only the orchestrator 'stays ahead'). CLAUDE.md is *the* main-thread contract — 'read as its first action, every session.' So it lands with at least the same reliability as a memory entry … and it gains two things memory can't: it's **version-controlled with the project** and **shared**."

It named the one tradeoff honestly — in `CLAUDE.md` the rule is **whizwheel-scoped** (it won't follow the user to other repos the way personal memory does) — and judged that the right call here precisely because the user *wanted* it in the repo. It also tied the move to the experiment's thesis: *"the experiment is partly about honing agentic orchestration, so 'stay ahead' is a genuine project convention, not just a personal quirk."*

The principle landed in `CLAUDE.md` as a new **"Orchestration — stay ahead of the airplane (main thread)"** section: the main thread is an *orchestrator* that proactively *catches and kicks* any unblocked work into the background instead of waiting idle; only the genuine critical path should gate; after each action it scans for newly-unblocked tasks and fires them; if something *can't* be backgrounded, it says why — **PR #40**. The section ends by naming this discipline as *itself part of what the experiment is honing*. To avoid the rule living in two places (drift), the assistant committed to **deleting the memory copy once #40 merged** — *"so it never lives in neither place."* After #40 merged, it did exactly that (and caught + fixed a stray typo it had introduced into `MEMORY.md` in the same edit).

The move was also *practiced while being made*: the assistant fired #40's `ci-monitor` *"in the same breath"* as opening the PR, and ran #40's visual gate the moment its CI went green — the very catch-and-kick discipline the PR was codifying.

**Agent-driven? ✅** A doc/contract edit (`CLAUDE.md`), via PR per the project's own rule. A small but pointed data point: the experiment is now reaching the stage where *the operator's own working habits* — not just product or build conventions — are being promoted into the version-controlled, shared contract so future sessions inherit them.

---
