## Chapter 61 — "Did we kick off CI for 50?": the orchestrator's own blind spot, and a contract tightened for agent-opened PRs (2026-06-14)

Chapter 60 closed the session. Chapters 57–60 were committed by a foreground historian run, which opened journey PR **#50**; the assistant printed its end-of-session summary table — #46–#49 merged, **#50 open + green** awaiting merge — and declared the session complete. But the table's *"⏳ open, awaiting your merge"* on #50 hid an assumption the assistant had never actually verified. The user pulled on exactly that thread:

> "did we kick off CI for 50? If so, result?"

The assistant did not bluff. It owned the miss plainly:

> "Honestly — no, I didn't. I opened #50 via the historian and went straight to close-out without dispatching `ci-monitor` for it. That's a miss against the discipline we just firmed up (every PR gets a monitor). CI itself auto-triggers on PR open, so a run exists; I just never watched it."

It corrected the omission the *right* way — **via `ci-monitor`, not inline** (per the very rule firmed in Chapter 59) — dispatching the monitor for #50. But the more valuable move was naming the **pattern behind the miss**, not just patching the instance:

> "the historian opens its own PR autonomously at session close, and the orchestrator's 'dispatch a monitor the moment a PR exists' reflex didn't fire because I didn't open it — same blind spot could hit any agent-opened PR. If it recurs, that's a candidate for a one-line `CLAUDE.md` tweak ('including PRs opened by dispatched agents')."

This is a precise diagnosis: the Chapter-59 rule had closed the "main thread checks CI inline" loophole, but a *different* hole remained — the orchestrator's catch-and-kick reflex is keyed on *the main thread opening a PR*, and a **dispatched agent** (the historian here; a build agent in general) opens its PR autonomously, so the reflex simply never triggers. The assistant explicitly held back from acting on the pattern unprompted — *"Not acting on it now — just noting it for your call"* — leaving the contract change to the user. `ci-monitor` then reported **#50 green** across all five jobs (`run 27491882355`).

### The user folds the lesson into the same PR

The user's response made the fix concrete and bundled it with the merge:

> "Include a tightened CLAUDE.md per your observation in this PR as well. On push, re-listen for CI. Then, on green, merge"

The assistant edited `CLAUDE.md`'s CI/CD-monitoring section **in the journey worktree, on the #50 branch** (so the rule and the chapters that motivate it ride in together), adding the agent-opened-PR clause to the existing firmed sentence:

> "This applies to **every** PR, **including one opened by a dispatched agent** (e.g. the historian's `JOURNEY.md` PR, or a build agent's) — the agent that opens a PR does not monitor its own CI, so the **orchestrator** must dispatch `ci-monitor` the moment such a PR exists. Do not let an agent-opened PR slip past unwatched."

Committed as `de3456c` (the commit body records the precipitating event verbatim: *"the historian's own JOURNEY.md PR (#50) slipped past unmonitored"*). On push the assistant **re-dispatched `ci-monitor`** for the updated #50 — dogfooding the rule it had just written, with a wry aside about who exactly opened *this* PR: *"per the very rule I just wrote — agent... well, orchestrator-opened, but monitored all the same."* The monitor reported #50 green a second time; the assistant merged it (`gh pr merge --merge`), landing `main` at **`8412cca`**, then ran the post-merge cleanup it had earlier flagged as the one open thread — removed the `.claude/worktrees/journey` worktree, deleted the branch, confirmed the tree clean — and dispatched this final foreground historian run to journal the tweak and close out.

**Agent-driven? ✅ (contract/`CLAUDE.md`).** This is the experiment's core loop turned on the **orchestration layer itself**: a process gap surfaced *in live practice* (the historian's own PR slipping past unwatched), was diagnosed down to *why the reflex didn't fire* (a dispatched agent, not the main thread, opened it), and was closed by **tightening the durable contract** — not by the assistant resolving to remember next time. Two things are worth marking: (1) the assistant answered the user's "did we?" with an unhedged *"Honestly — no, I didn't"* rather than glossing the gap, the same candor seen when it admitted the inline-`ci-watch` slip in Chapters 58–59; and (2) the fix extends the *same* sentence Chapter 59 firmed, in the *same* layer (`CLAUDE.md`, which governs the orchestrator) rather than `ci-monitor.md` (which only governs the agent once dispatched) — the loophole-closing pattern of Chapters 27/59 applied one level up, to the orchestrator's own dispatch reflex.

---
