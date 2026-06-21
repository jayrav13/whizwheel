## Chapter 131 — The concurrency cap tightens to a hard 2 — proved necessary, mid-session, by a PM death (2026-06-19)

This is the session's central harvest, and it is almost entirely about **orchestration discipline** rather than calculator results — the experiment honing its own multi-agent process. The trigger was an agent death; the irony is that the death proved the very cap the operator was about to direct.

### The dead agent that made the case

While the two fix gates (#292, #293) ran, the operator asked the orchestrator to consult the PM on the next calculators:

> **"I think the next step is to pick 5 calculators to work on, can you ask what the PM thinks we should pick"**

The orchestrator dispatched the `project-manager-agent` (full-context ingestion → ranked pick list). But by then three heavy agents were already in flight — QA on #292, QA on #293, and now the PM — and the orchestrator had even noted it at the time: "That's 3 heavy agents in flight — at the concurrency cap, so I'm holding here rather than firing more." The (then-current) documented cap was the iteration-0007 harvest's **"~3–4 heavy agents."** Three was supposedly safe.

It wasn't. Some twenty-five minutes later the operator noticed the absence:

> **"I don't see a PM agent running, cap hit?"**

The orchestrator checked — refusing to assume — and confirmed the death by output-file metadata alone (not reading the transcript, which would overflow context):

> **"it's dead, not running. The PM's output file hasn't been written to in ~27 minutes … with 335 KB of transcript but no completion notification. That's the silent-death signature — almost certainly the iteration-0007 rate-limit death: when I dispatched it, QA-#292 + frontend-#215 were already running and QA-#293 piled on right after, so the PM was caught in a window of 3+ concurrent heavy agents and got cut off mid-run without ever returning its verdict."**

This is the **#140 silent-subagent-death** signature again — but the diagnostic detail is what makes it a harvest: it died at **3 concurrent heavy agents**, *below* the documented "~3–4" ceiling. The very guidance written one iteration earlier to prevent this had been honored, and the death happened anyway. The orchestrator re-dispatched the PM **solo** ("no cap pressure this time"), and it returned cleanly — the recovery confirming the cause was concurrency, not the task.

### The operator's directive: a hard cap of 2, with a standing queue

The PM's pick list landed (recorded in the next chapter), and the operator chose its pick as-is — but first issued the process change that this session is most about. Verbatim:

> **"Let's document a cap of 2 subagents running at a time, document in CLAUDE.md. Goal for Claude would be to queue up tasks it knows it needs to run based on discussion but only ever send 2 agents at a time. Always proactivelly in that when one ends, know what the next one is to run. If the workflow of an agent involves enqueueing another agent, prioritize the follow-on enqueue over popping something from the ongoing list of agents to deploy**
>
> **Fair? Would be documented in CLAUDE.md"**

Three distinct ideas live in that paragraph, and all three landed in the contract:

1. **A hard ceiling of 2 in flight** — not "~3–4," not "wave it," but *only ever 2 at once*, with never a third.
2. **A standing queue, not a wait** — the orchestrator is to *enqueue every task it knows it'll need* in dependency order, proactively, so the moment a slot frees it already knows what to pop. The slot is never idle; the cap never becomes a stall.
3. **Follow-on priority** — when a finishing agent *spawns* its own next agent (a build PR that now needs its QA gate, a QA FAIL that needs re-dispatch, a stale-SHA that needs a re-gate), that follow-on jumps **ahead of** anything in the standing backlog. Draining an in-flight chain beats starting new work.

The orchestrator agreed, and — notably — pointed at this session as the evidence for the operator's own proposal:

> **"Your proposal is not just fair — this session is the evidence for it. The PM died at only 3 concurrent heavy agents, below the documented ~3–4. So tightening to a hard 2 with an explicit queue is a real harvest."**

### How it landed in the contract

Because there is no agent formally chartered to own `CLAUDE.md` (that gap is issue #72), and because the PM authored the original concurrency-cap text in the iteration-0007 harvest (#287), the orchestrator treated process/contract edits as the PM's de-facto steward turf — but the actual edit here was made by the orchestrator on a branch (since it was the in-flight reframe of an existing section). The change landed as **PR #294**, branched off `main` and gated like everything else (PASS, docs-only — CI green, baseline-diff all #87 noise; "A one-line `CLAUDE.md` prose edit structurally cannot move a rendered pixel").

The "Concurrency cap" section under Orchestration was rewritten from **"wave the fan-out (~3–4 heavy agents at a time)"** to **"at most 2 subagents at a time, with a standing queue"** — encoding the three ideas above as explicit bullets, and recording *why* 2 rather than 3–4: the iteration-0007 ~7-agent rate-limit kill *and* this session's PM death at only 3, both the same silent mid-run death, the second below the old guidance.

### Practicing the rule it just wrote

The most legible evidence that the change "took" is that the orchestrator immediately ran its own dispatching by it — narrating the queue out loud:

> **"Now I'll put the new discipline into practice immediately. Here's my explicit queue:"**

It declared an in-flight pair (QA on #294 taking the priority follow-on slot; `backend` on #286 from the top of the standing queue), an explicitly *held* backlog (#286's own QA gate as a follow-on, the 5-calculator round blocked on #286 merging, the three human-merge-pending PRs), and the pop rule: "When either in-flight agent comes to rest, I'll pop the next — prioritizing any follow-on it spawns … over the standing backlog, per the rule I just documented." From that point through the rest of the session, every dispatch was annotated with which of the 2 slots it occupied and what was queued behind it. The cap stopped being prose and became the visible operating mode.

The meta-point of this chapter: the experiment's core loop ("fix the agent/contract, not the code") ran on the *orchestrator itself*. The failure was a coordination death; the fix was a contract edit (`CLAUDE.md`), not a one-off "I'll be more careful"; and the very session that wrote the rule is the data point the rule cites. The cap was proved necessary by the thing it was written to prevent.
