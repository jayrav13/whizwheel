## Chapter 54 — Worktrees standardized for every writing agent, delivered through CLAUDE.md by-reference (2026-06-14)

After the measurement landed, the user returned to a thread the assistant had started in the previous turn — making worktrees the standing default for *every* agent that writes — but reframed it as a deeper question about *how context reaches subagents at all*:

> "is it *possible* for us to deliver it standardized instructions from our CLAUDE.md? What gets passed to them from us other than the repeating agent files? Is there a centralized context that's sent? If so, if that context said 'spin up and hang out in your own worktree', I see no harm. It's forward proof and for whatever needs it, it securely has it"

Rather than guess at the harness mechanics, the assistant **fired the claude-code-guide** to get the delivery model authoritatively, and reported the finding precisely:

> "Subagents receive: their agent-definition file + the Task prompt. They get `CLAUDE.md` automatically *only if* `settingSources` is configured to load it … otherwise not. No other centralized auto-context (user memory/settings aren't passed)."

This sharpened the answer into two distinct delivery channels:

- **By-reference (what the repo already does, zero config):** every agent definition mandates a "Step 0: read `CLAUDE.md`," so a standing rule in `CLAUDE.md` already reaches every registered agent today — *"that's our centralized channel, and it works regardless of `settingSources`."*
- **Auto-injection (`settingSources`):** would push `CLAUDE.md` into subagents automatically, independent of any read-step — *"cleaner in theory, but it's an SDK-framed setting with uncertain CLI behavior — I'd want to verify before relying on it."*

The assistant's call: **put the worktree rule in `CLAUDE.md` as a standing default now** (delivered by the read-step the repo already enforces — *"bulletproof for our agents, no config risk"*), and treat `settingSources` auto-injection as an optional hardening to verify later. That gives the *"forward-proof, securely has it"* property the user wanted: the rule lives **once**, in `CLAUDE.md`, and every current and future writing agent inherits it via the read-CLAUDE.md-first step they already run — no per-agent duplication.

The change generalized the existing per-build-agent worktree convention into a **standing default for all writing agents** — explicitly naming the **build agents, the PM, and the historian** — with a deliberate carve-out: **report-only agents (`ci-monitor`, `dependabot-agent`) don't create worktrees, because they never write.** Three files were touched:

- **`CLAUDE.md`** — the **Worktrees** section now states the two-lane model with the writing-agent default front and center: *"Every dispatched agent that *writes* creates its own worktree as its first action … This is the standing default: you do not need to be told per-task — reading this file (your Step 0) IS the instruction,"* using the deterministic `git worktree add` CLI over the unproven-in-subagents `EnterWorktree`, and committing/pushing/opening its PR from the worktree — *"it never merges and never pushes to `main`."*
- **`historian.md`** — the assistant identified that this file *contradicted* the new rule (it told the historian to "commit but don't push," a relic of the pre-PR-first model flagged as friction back in Chapter 51) and **fixed it to be self-contained**: worktree → commit → push → docs PR. This resolved the awkward "main-thread-PRs-the-journal" dance for good.
- **`project-manager-agent.md`** — its worktree line was upgraded from "fine to use one" to making the worktree the **default**.

This landed as **PR #43**. The assistant summarized the resolution back to the user's question: *"yes, it's deliverable from CLAUDE.md, the rule now lives there once, and every agent inherits it via the read-step they already run — forward-proof, no per-agent duplication."*

**Agent-driven? ✅** A pure contract/agent-definition change across `CLAUDE.md` + two agent defs, no app code. Two durable data points: (1) the experiment's own *delivery mechanism* was investigated authoritatively (subagents get only their def + the Task prompt; `CLAUDE.md` reaches them by-reference via the mandated read-step, not by auto-injection unless `settingSources` is set) — which validates the repo's long-standing "point every agent at `CLAUDE.md` first" stance and explains *why* it works; and (2) the historian became fully self-sufficient under the PR-first regime, closing the small wrinkle named in Chapter 51.

---
