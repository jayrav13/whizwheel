## Chapter 136 — Six weeks dormant: a cross-repo survey walks back into whizwheel, and "can we let loose?" gets an evidence-based half-no (2026-08-07)

This chapter opens the first whizwheel work in six weeks, and it is worth stating plainly what the gap was: `main`'s last substantive commit was **2026-06-20** (PR #298, the orchestration-harvest journal). The 2026-06-25/26 session that produced the iteration-0007-r2 harvest (Chapters 134–135) ended with everything **staged and unmerged** — PRs #305, #311, #314 open, seven issues filed, iteration-0008 not opened. Then nothing. Dependabot kept opening PRs into an empty room. The journey log's coverage anchor stayed frozen at `2026-06-26T12:52:28.649Z`.

Two structural notes belong at the top of this chapter, because they shape everything in it and the two that follow.

**First: this session was launched from the wrong directory.** It ran from `/Users/jravaliya/Code` — the *parent* of the repo — not from the repo root. That single fact is the reason this chapter is being written weeks late and by explicit pointer rather than by the historian's normal discovery path; the full diagnosis is Chapter 138's subject.

**Second: whizwheel was not the session's starting topic.** The operator opened on a cross-repo question:

> **"List out all of my repos from remote GitHub that use Claude and have been committed to in the last 12 months"**

The answer was a 20-row table, and the framing observation was that the question had no negative cases:

> **"All 20 of your repos with commits in the last 12 months use Claude in some form — every one has either a `CLAUDE.md`, a `.claude/` directory, or both."**

A side quest followed and closed cleanly in another repo: `skywatch` had a `.claude/projects/…/memory/` directory committed to a **public** repo. The operator said **"Yeah investigate and clean up skywatch's memory files committed to public please"**, and the finding was reported without inflation — *"No secrets in there — no keys, no credentials, no email. It's project notes plus a light user profile. The one real leak is your local username in the path"* — plus the fact that made deletion (not merely untracking) safe: the in-repo copy was *"stale and orphaned,"* a 4-file snapshot frozen at the initial commit, while the live memory lived under `~/.claude/projects/`. The operator said **"Great, merge"** and it merged. (That this cleanup is itself an instance of *the `~/.claude/projects/` directory being misunderstood* is an irony the session did not remark on, and which Chapter 138 will make load-bearing.)

Two more table refinements later — the operator asking to swap the commit column for **"a short descrition of what the project is"** — whizwheel appeared in the survey with a one-line self-description drawn from its own `CLAUDE.md`:

> **"calculator.net reimagined — broad calculator library, all math server-side. Built as an experiment in agent-driven development"**

And that is what prompted the question this chapter is actually about.

### "To what extent can we let loose on whizwheel?"

The operator's question, verbatim:

> **"To what extent can we let loose on whizwheel? I feel like that's such a well established project that we can make incremental but reliable progress. Is this accurate?"**

The response opened by refusing to answer from memory — *"Good question to check rather than assume. Let me look."* — and then actually ran the gates on the current checkout rather than quoting the journal's claims about them. This is the same verification reflex the log has recorded since Chapter 12 (*evidence, not reassurance*), applied here to a six-week-old repo whose state nobody had confirmed.

The verdict was split rather than given:

> **"Half right — and the half that's right is stronger than you're giving it credit for. I ran everything on the current checkout."**

**The measured substrate**, all freshly run:

| Gate | Result |
|---|---|
| Test suite | 1573 tests, 20296 assertions, **0 failures**, 5.0s |
| Coverage | **100.00% line** (2005/2005), enforced as a hard gate |
| RuboCop | 239 files, **0 offenses** |
| Brakeman | **0 security warnings** |

The read on *why* that substrate exists tied the numbers back to two of the repo's five rules:

> **"A 5-second suite at 100% enforced coverage is about the best feedback loop an agent can be handed. And two architectural rules were deliberately designed for fan-out: rule #3 (*no hand-edited central registration* — you add a calculator by adding a file, the registry is projected from `INVENTORY.md`) means parallel agents don't collide on shared files, and rule #5 (*the math layer is pure*) is what makes 100% coverage reachable at all. 298 PRs merged in nine days is not a fluke; it's that design working."**

This is an outside-in confirmation of the journal's own running thesis, produced by an assistant that had *not* read the journey log to reach it — it ran the gates and read `CLAUDE.md`. The correctness-compounds-upward claim (Chapter 116) and the conflict-free-fan-out claim (rule #3, exercised at 7× and 10× in iteration-0007) both survived a cold audit.

### Three arguments against "let loose"

The counterweight was specific, and two of the three cut at the *experiment's own design*:

**1. The regeneration sweep is hostile to incremental patching.** The response quoted rule #1 back — *"so any fix living only in calculator code is erased"* — and drew the consequence:

> **"That's intentional — it forces decisions up into the agent/spec/test layer. But it means the unit of durable work here is a spec or agent-definition change, not a patch. An agent turned loose to "fix things" would produce work that the next sweep deletes."**

This is the sharpest external statement of rule #1's *cost* the log has recorded. The regen sweep is the mechanism that makes the experiment honest; it is also the mechanism that makes unsupervised "just go fix things" autonomy structurally wasteful here.

**2. Long dispatched agents die, and it is documented.** Issue **#140** is still open (*"Recurring agent death: API Error: socket connection closed unexpectedly"*), and the response cited this log's own accumulated death catalogue back at itself — the two silent deaths of the 2026-06-19 session and iteration-0007's mid-run rate-limit kill *"which lost uncommitted work"* — along with the harvested lesson from Chapter 133: *"completion notifications alone aren't reliable; verifying the side-effect is the real signal."* The conclusion: **"Unattended fan-out is exactly the regime where this bites."**

**3. The contract forbids it.** *"Never auto-merge. A green gate merges only on explicit human instruction."*

### The dormancy, named from the commit graph

Then the observation that gives this chapter its title, derived not from the journal but from `git log`:

> **"And the momentum isn't there. Every commit in the repo's life — all 511 — lands between June 12 and June 20. Everything since is dependabot. Three of your PRs are still open and staged for an iteration-0008 that never started: #305, #311, #314, all journey/harvest docs."**

(The date range is the assistant's read of the bulk; the three June-26 harvest commits sat on unmerged branches, not on `main`, which is exactly why the graph looked like it stopped on the 20th.)

The reframe that closed the question:

> **"So the accurate framing: it's not "let loose" — it's *the highest-throughput supervised fan-out lane you own.* Where you can genuinely open the throttle is the calculator backlog, because the registry pattern makes parallel builds conflict-free and the coverage gate makes correctness self-enforcing. Where you can't is anything needing judgment about specs, design semantics (#112), or merges."**

And the diagnosis that set the session's agenda:

> **"The real blocker isn't capability, it's that iteration-0007 was never closed out. Want me to start by landing those three stale PRs so iteration-0008 has a clean base?"**

The operator said yes, in the session's most quotable line:

> **"Yes let's land whatever's still flying, so to speak, can you walk me through what's needed there?"**

### What this chapter is evidence of

Three things, held apart.

**The dormancy is itself a datum.** Six weeks passed with a half-closed iteration, three unmerged PRs, and a frozen journal anchor. Nothing rotted structurally — the gates all still passed on the first try, `main` was clean, the worktrees were gone, the plan was recoverable — but nothing self-started either. The machinery is durable at rest; it is not autonomous at rest. Everything in this session was initiated by the operator's question, and the *queue* the session then worked was the one Chapter 135 had staged six weeks earlier.

**The plan survived the gap intact.** Chapter 135 closed by recommending a merge order — **#305 → #311 → the journey PR** — and stating that iteration-0008 would open pinned at the result. That recommendation was rediscovered from the artifacts alone (PR bodies, the iteration log, `CLAUDE.md`) by a session with no memory of writing it, and followed exactly. The written record functioned as designed: a six-week-old decision was executable by a cold start without re-litigation. That is what the journal and the iteration logs are *for*, and this is the first time the log can record them being cashed at that distance.

**The audit was cold and it agreed.** The strongest evidence in this chapter is not any claim made about the experiment but the fact that an assistant which ran the gates before reading the saga arrived at the same structural conclusions the saga had been building — rule #3 buys conflict-free parallelism, rule #5 buys the coverage gate, rule #1 buys durability at the cost of patch-level autonomy. The counterweights it added (the death catalogue, the never-auto-merge rule) were also the log's own. The record and the reality were not out of sync — which, after six weeks of silence, was not guaranteed.
