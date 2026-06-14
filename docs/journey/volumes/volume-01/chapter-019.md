## Chapter 19 — The PM was the first agent built and the least used: a pending design question, not a verdict (2026-06-13)

This chapter is a short but substantive coda to the closed session — a reflection prompted by the user, mid-wrap-up, that surfaced the first genuinely uncomfortable data point about one of the agents and named a *deliberate design decision still pending* rather than reaching a verdict.

With the end-of-session checklist already run once (historian to completion through Chapter 18, working tree clean, `main` in sync), the user paused the close to ask a pointed question about the agent that started it all:

> "Can you comment on PM usage? I guess it was low, but that's because we haven't worked on calculators, right?"

The assistant agreed that the user's own explanation was the **main** reason — but was careful to name it as not the whole story:

> "You're right that it was low, and your explanation is the main one — but it's not the *whole* story, and the rest is the more interesting part."

**The primary reason: the PM is calculator-shaped, and we haven't built a calculator.** The assistant laid out why the PM's designed job genuinely hasn't begun: *"The PM's core machinery is calculator-shaped: *iterations* ("rebuild n calculators"), *sequencing* ("which calculator next"), *synthesis* ("how's convergence going"), *iteration logs + tags*. None of that applies to building a foundation. So its designed job genuinely hasn't started — it's an instrument waiting for its workload."* This confirms the user's hypothesis directly: low usage is mostly because the work to date (foundation, instrumentation) is not the work the PM was built for.

**But two honest secondary reasons.** The assistant named them explicitly rather than letting the calculator explanation absorb everything:

1. **The orchestrator bypassed the PM for the routine tracking that *did* happen.** In the assistant's words: *"I created issues #4, #6, #7 with `gh issue create` directly, and I wrote `PRODUCT.md` myself — both things the PM nominally owns. I did that because the PM's **mandatory full-context launch ingestion** (read *all* of `docs/`, now including a huge `JOURNEY.md`, plus all git/issues/PRs) makes it *heavyweight to invoke for one `gh issue create`*."* It named the resulting tension precisely: *"the PM is built for deep, deliberate moments, not frequent lightweight tracking — and when I needed lightweight tracking, I routed around it."* This is the load-bearing finding of the chapter: the PM's own heavyweight launch protocol (designed in Chapters 3–4 as a *feature* — deterministic, no-shortcuts ingestion of the full knowledge layer) is disproportionate for one-off tracking, so the orchestrator handled that tracking itself.

2. **The PM isn't a registered subagent type yet.** *"It's not a registered subagent type yet (needs a session reload), so every invocation was the awkward read-and-adopt fallback — extra friction that further discouraged casual use."*

**What it did do, it did well.** The assistant was careful not to let low usage read as a failure: *"the 191-calculator inventory was a real, substantial, verified output, and it correctly refused out-of-boundary work. Low usage ≠ unproven — just unexercised in production."*

**The pending design question — named, not resolved.** The assistant framed the *next* session as the PM's real test, and articulated the decision that will need to be made deliberately:

> "If, even *with* calculators, I keep bypassing it because its launch protocol is too heavy for routine use, that's a result — it would mean either the PM needs a lighter "quick mode," or the honest division is **orchestrator handles routine tracking; PM reserved for synthesis/sequencing/iteration-boundaries.** Worth deciding deliberately rather than by drift."

And it closed on the data point itself, stated plainly:

> "the PM was the *first* agent built and the *least* used so far — which is a slightly uncomfortable but useful data point. Its verdict is pending the calculators, and `JOURNEY.md` will catch whether it earns its keep or gets designed-around."

The user accepted the reflection and called for the final wrap — *"One more quick end of session runs and we're good"* — and the assistant began the closing checklist again, foreground historian on `main`, expressly *"to capture the PM-usage reflection."* That foreground run is the one writing this chapter.

**Agent-driven?** N/A — no artifact changed here; this was reflection, not a build. The chapter records an *observation about how the agents are actually being used*, and a design question (route all tracking through the PM, at cost, vs. let the orchestrator handle routine tracking with the PM reserved for synthesis/sequencing/iteration-boundaries) that remains **open** — to be decided when calculators exercise the PM for real.

---
