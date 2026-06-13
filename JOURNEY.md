<!-- coverage-anchor: 2026-06-13T05:55:36.801Z — through Chapter 12, "Keeping the raw record: the conversations/ snapshot, and a durability question answered with evidence" (commits 51c0b41 end-of-session checklist, 6b2a100 snapshot feature). The historian journals transcript activity AFTER this anchor and advances it. -->

# whizwheel — The Journey

This is the running record of an experiment: **can you build a real application by iterating on AI *agent definitions* rather than by hand-editing code?** Every decision, pivot, and route taken is documented here, in detail, with verbatim quotes from the conversation that produced it. The goal is to be able to look back and answer one question honestly:

> **Does this work?**

**How this document is maintained.** The main thread (Claude) owns it. At each meaningful decision or pivot, the main thread fires a background **historian** worker that reads the session transcript (the raw messages) plus this file, and appends new chapters — verbose, faithful, unopinionated, with real quotes. It is read by the main thread (only) at the start of a fresh session. See `CLAUDE.md` → "JOURNEY.md".

**How to read it.** Chronological. Each chapter records *what was decided, in whose words, why, and which artifact changed* — and notes whether the change was made in an **agent/doc** (the experiment working as intended) or in hand-written code (the experiment's discipline slipping). Dates are when things happened.

---

## Chapter 1 — The premise (2026-06-12)

The user opened with a thought experiment, not a feature request:

> "I'd like to create an agent for the two major portions of the app, the frontend and the backend. Then, I want you to use those agents in order to actually build the app."

The motivating question, in their words:

> "does it make sense to iterate on and focus on the agents (from my perspective) which can encapsulate my engineering style and approach and can mimic each and then ask you to use them to build?"

And the reason it mattered beyond this one app:

> "while on small scale, this might be overkill, i want to start understanding how I can use this methodology for larger and larger apps … my goal becomes to fine tune my expectations for how each section is built, and then expect better and better results over time as I essentially converge on perfection."

**What the app is.** A reimagining of [calculator.net](https://www.calculator.net): *"All calculators with some potential differences."* A beautiful client UI; **all math on the backend.** The user framed quality precisely:

> "the highest quality will come from the best inputs, so the result will invariably match that. Our goal is to make those inputs as fantastic as possible."

The repo was a fresh Rails 8.1 app (Postgres, Hotwire, Minitest), zero commits. A blank canvas.

**The framing that stuck:** the durable, improvable artifact is the *agent definition*, not any calculator. Code from a session is disposable; an agent file compounds. The core discipline that falls out: **when output disappoints, fix the agent definition, not the code.**

---

## Chapter 2 — Choosing the hard path (2026-06-12)

Offered three ways to start the loop — (a) agent-first, (b) derive agents from a hand-built golden example, (c) heavy upfront style interview — the recommendation was (b), the safer path. The user deliberately chose (a):

> "the intent of this experiment is (a) :D the goal is to see how I can work with you to work on JUST the definitions and see the outputs emerge."

And named *why* the harder path was the point:

> "It's to challenge me (and in a way you too) really to be able to describe my work with great intent. And I say it could be a challenge for you because it's on you to interpret my intent in times that I'm not precise."

This set the rule of engagement for everything after: decisions get codified **in the agent, not the code**, and breaking changes are fine because *"the commit history will tell the full story."*

**Agent-driven?** This *is* the methodology. ✅

---

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

## Chapter 4 — The GitHub Issues pivot (2026-06-12)

Mid-stream, the user caught something:

> "should we not loop in GitHub Issues into this flow? … 2 key tags maybe could be 'engineering' and 'agents'."

This produced a clean **two-layer split**: **task state (the kanban) → GitHub Issues**; **knowledge (the lessons) → `docs/` in the repo**. The principle: the kanban may live off-git (it's a board); the *knowledge* stays in the repo so "git history is the ledger" still holds for what matters. `PROGRESS.md` was retired (issues replaced the board). Crucially, Issues also **dissolved the hardest fan-out problem** identified earlier — the user had asked:

> "would we be able to use agent fan-out or dynamic workflow to kick off all of the work and result in 10 or more PR's …" (and later) "we'll want to do a worktree approach."

With one issue per calculator and one PR closing it (`Closes #N`), parallel builds never contend on a shared progress file. Two forward-looking constraints were banked: **disjoint files + serial reconcile**, and **auto-discovered, self-contained calculators** (no central registration), so parallel builds stay conflict-free.

This pivot also added the PM's mandatory **full-context launch ingestion** and an explicit **Opus** pin — both recorded in the spec (rev. 2) and the agent.

**Agent-driven?** ✅ All changes landed in the spec + the PM agent.

---

## Chapter 5 — "How does the agent know our vision?" → ARCHITECTURE.md (2026-06-12 → 06-13)

The pivotal scaling question, in the user's words:

> "does the agent get all the information about what the structure looks like so then when we ask it to create, it knows our vision? How is that managed?"

The answer reframed the whole experiment: **don't put the vision in the agent.** Split it three ways — the **agent definition** holds durable role/style/discipline; a versioned **`docs/ARCHITECTURE.md`** holds the *current structural vision* (the conventions every agent ingests); and **reference implementations** become living templates. The agent gets one instruction — read the architecture doc first — exactly mirroring the PM's launch protocol. *"Onboard it like a human engineer."* This is why agents stay lean as the app grows.

So the next artifact designed was not the backend agent but the **conventions doc it would read.**

**Agent-driven?** ✅ The realization is the load-bearing insight for scaling the method.

---

## Chapter 6 — The product takes shape (2026-06-13)

Designing `ARCHITECTURE.md` surfaced the real product, decision by decision:

- **Calc objects = ActiveModel POROs (option A).** The user asked plainly, *"What is a PORO?"*, then chose A: plain Ruby objects with `ActiveModel` for validation + typed `:decimal` (BigDecimal) attributes, **no database** — which is what makes the math layer purely, exhaustively testable.
- **Persistence, deliberately layered.** The user: *"I'd like users to be able to log into the website and to have all calculations tied to a user … This might seem like a privacy nightmare, but remember this is an experiment, not a product that I'm looking to ship viably."* Then a sharp layering refinement: a calculator *"can instantiate a DB record that hasn't been created yet and return it … the controller should be the one that actually creates the model"* — so the response is decoupled from persistence, and recording can later move to a background job with no contract change.
- **Auth:** *"We collect username and password from a user, no emails for now"* — adapted Rails 8 auth, no email, no password reset, no sign-up; users via CLI.
- **RBAC:** `RoleType`/`Role` with a seeded `ADMIN`; revoking = soft-deleting the `Role`. Then a simplification: *"No portion of this app handles user creation or role creation"* — roles are DB/CLI-managed; the ADMIN role only *gates* a site-wide stats view.
- **Soft-delete** became a cross-cutting convention (`Discardable`); per-user views hide discarded rows, site-wide usage counts all.
- **Naming/ontology:** the user asked, *"should it be called app/calculators/* instead of app/calculations/*"* — yes, clarifying the ontology: a **calculator** is the type/code; a **calculation** is one run (a DB row); `calculation_logs` is a reporting view. Calculators are **code, append-only** — *"discourage deleting calculators … we'll lose some comparability."*

**Agent-driven?** ✅ All of it landed in `ARCHITECTURE.md`, the doc agents read — not in code.

---

## Chapter 7 — PRODUCT.md (2026-06-13)

The user noticed a gap: *"are we tracking the 'product' at the moment? … Should the PM also manage a PRODUCT.md doc that keeps the overall vision in mind."* Yes — the two north-star docs became explicit: **`ARCHITECTURE.md` (how we build)** and **`PRODUCT.md` (what we build, for whom)**. The PM **stewards** `PRODUCT.md` (keeps it current as decisions land) but does not *decide* direction. Captured now, deliberately, because the vision lived mostly in the conversation — exactly the thing that's lost when context compacts.

**Agent-driven?** ✅ New doc + a one-line PM stewardship edit.

---

## Chapter 8 — CLAUDE.md and inheritance (2026-06-13)

The user: *"we don't have a CLAUDE.md file. Can you consider any other documentation we might want."* Created `CLAUDE.md` as a lean **router + rulebook** (read-these-first pointers, the experiment's discipline, the agent roster, commit conventions, the five rules that matter most) and rewrote the boilerplate `README.md`. Then a precise extension:

> "can we just make it more explicit to all agents that they should inherit from CLAUDE.md … it'll work now when you spawn a generic subagent … and it'll codify this in both directions for the future."

So `CLAUDE.md` now declares it is inherited by *all* agents/subagents, instructs that spawned subagents be pointed at it (they don't auto-inherit it), and requires every new agent definition to read it first. The PM's launch protocol was updated to read `CLAUDE.md` too. This is also where the project-wide commit conventions live — including a real lesson learned: **plain `git commit`, never the `-c commit.gpgsign=false` override** (signing was off; the override was a no-op the user asked us to drop).

**Agent-driven?** ✅ Conventions codified in the file all agents inherit.

---

## Chapter 9 — CI/CD green + the ci-monitor agent (2026-06-13)

CI was failing on every push. Root causes, diagnosed from the logs: (1) no `db/schema.rb` (a fresh app with zero migrations) — fixed by switching to **SQL schema format** and committing `db/structure.sql` (the *correct* long-term choice, since the upcoming `calculation_logs` **view** can't be represented in Ruby schema); (2) `test:system` `LoadError` — fixed by adding a tracked `test/system/` dir. All five jobs went green.

Then: *"Let's codify a CI/CD monitor similar to in ../tenor for all pushed commits and PR's — they should be pushed to generic subagents (or hell, we create one?)."* We created one: **`bin/ci-watch`** (deterministic status: `0`=pass/`1`=fail/`2`=pending/`3`=none) plus a **report-only `ci-monitor` agent** (Sonnet) that watches a run and, on failure, diagnoses the root cause from the logs — never edits, never merges. CLAUDE.md now requires watching CI after every push/PR and forbids auto-merge. The agent was dogfooded immediately: dispatched via read-and-adopt, it watched its own commit and reported a correct green verdict.

**Agent-driven?** ✅ A third agent (`ci-monitor`) + a script + a convention. The CI fixes themselves were infra (config + a `.keep`), honestly noted as hand-edits — but small and outside the calculator-build path the agents own.

---

## Chapter 10 — The historian: an agent argues itself into, out of, and back into existence (2026-06-13)

This chapter is the document writing its own origin story — the first entry authored by the historian agent it describes.

The user opened a new line of work:

> "Next, I'd like to create a JOURNEY.md file at the root of the project with new instructions in CLAUDE.md. Your job here is to, at regular intervals, dispatch a subagent that is responsible for documenting the journey of this experiment. This is to be done in extensive detail. I'd like you to document every decision and route we've taken thus far to deliver a product that is entirely driven by adjustments in the agents. This can be as specific as including specific quotes from messages I've sent and you've responded with. The goal of this document is going to be to summarize the journey and answer the question: 'does this work?' Though it will be long, this too should be consumed, but only by the main thread on each startup … Again, very verbose and generally unopiniated."

And, in the same breath, the seed of the idea that would seesaw across the next several exchanges:

> "create the nomenclature in CLAUDE.md to indicate we should push a generic agent to go do this on a regular basis (unless... we could make a historian agent?? I love that thought)"

**Position 1 — yes, an agent (with a caveat).** The assistant embraced the name immediately — *"it completes a nice trio (`pm` tracks, `ci-monitor` watches, `historian` remembers), and it's the agent that literally answers the experiment's core question"* — but flagged the design constraint that would drive the whole debate: *"A subagent historian does not have our conversation in its context — it gets an isolated context with only the repo. So it can't, on its own, quote messages it never saw."* The proposed split: write the initial `JOURNEY.md` now, by hand, while the live conversation (and its quotes) still exist; let an ongoing agent maintain it afterward from durable sources.

**Position 2 — no, not an agent.** The user interrupted and pushed back on the premise itself:

> "Let's discuss first - maybe this means we shouldn't have a separate agent. Because really, all that would be happening is that you'd be pushing context to an agent that just writes it to a file. It's the raw messages context + the results of it that are important. So let's not go the agent route, let's have this be a responsibility the main thread (you) has via CLAUDE.md. Is that feasible?"

The assistant conceded fully and sharpened the reasoning: *"A subagent only earns its keep when it has something the main thread doesn't … Here it's the inverse: the source material is this conversation, which only the main thread holds. A historian subagent would start with strictly less than me, so I'd have to serialize my context into its prompt — at which point I've done all the thinking and it's just a file-writer. That's indirection with loss and no gain."* It accepted main-thread-via-CLAUDE.md as feasible, with one honest limit: there is no autonomous timer, so *"regular intervals"* must become **checkpoint-driven** — journal when a decision lands, while context is live, because *"the reliable capture is in-session."*

**Position 3 — yes, an agent, for a different reason.** The reversal came from a requirement the user cared about: *no friction.* If the main thread writes entries inline, the narrative pours into the conversation and the user feels every word. The assistant reasoned that backgrounding *narrative* prose can only be done by an async **model** worker — *"A background shell task can't synthesize prose; a hook can't either"* — and that this didn't actually contradict "no agent," because of **how the agent gets its context**:

> "The agent we rejected was a dumb writer I push my context to — pointless indirection. The agent this needs is one that reads the session transcript itself — the raw messages are on disk, so it pulls its own source material. I'm not pushing context; I just point it at 'journal up to the decision we just made,' and it mines the verbatim record. That's the opposite of indirection-with-loss."

The whole design now hinged on a single empirical question — *can a subagent actually read this session's transcript?* — which the assistant went and verified rather than assumed. First it confirmed the file: **"1.8 MB, live (updated this minute), readable."** Then the structure: **"the transcript is fully parseable — 156 user turns, 296 assistant turns, each with `message: {role, content}` and timestamps, and it contains the real text (it found 'PORO' ×6, 'historian agent' ×2, 'calculator.net' ×50). So a background worker can mine verbatim quotes from it."** At this midpoint the assistant proposed a *generic, stateless* background worker following a CLAUDE.md recipe — *"no `historian.md`"* — honoring the user's earlier instinct.

**Position 4 — the settled answer: yes, a named historian agent.** The user reversed it one last time, and named the property that made the difference:

> "Write the initial JOURNAL.md, but in this case, doesn't this actually suddenly *warrant* a historian-agent? We can background it and forget it - it now has every piece of context. We might want some creative way for the agent to mark the last time the historian was invoked and make sure it sees the latest mark … everything after the second-last marker are in context for journaling … but otherwise it also has full context + the entire current JOURNAL.md to lean on to cross reference decisions"

The assistant agreed, noting the premise had genuinely changed under the earlier conclusion: *"When I said 'no agent,' the agent would've been a dumb writer I push context to. Now that it reads the transcript, it 'has every piece of context' — it's a self-sufficient background worker, not an empty vessel. That dissolves the original objection completely."* The user's marker idea became a concrete, durable mechanism — **belt and suspenders**:

> "the conversational marker (my '📝 journaling…' line) is the visible heartbeat/trigger, but the authoritative boundary lives as a coverage anchor written into JOURNEY.md itself (the timestamp of the last transcript message it covered). The historian reads its own anchor → journals the transcript span from there to the latest marker → cross-references the existing JOURNEY.md to keep the narrative continuous → updates the anchor."

A small naming correction was logged in passing: the user had typed `JOURNAL.md`, but the file would be **`JOURNEY.md`**, *"matching 'document the journey.'"*

**What got built.** The assistant wrote the initial `JOURNEY.md` (Chapters 1–9, the premise through the CI-monitor build) from live context — the richest source, captured before compaction could eat it. Then it created the **`historian` agent** (`.claude/agents/historian.md`, Opus, tools limited to Read/Edit/Bash) whose hard boundaries are exactly the experiment's discipline turned inward: *writes only `JOURNEY.md`, commits only `JOURNEY.md` via path-scoped staging, never fabricates a quote, stays unopinionated.* It wired the convention into `CLAUDE.md` under a new **"JOURNEY.md — the experiment log"** section: main-thread-only startup read; fire the historian *in the background* (`run_in_background: true`) at each meaningful decision; emit one visible marker line (`📝 journaling that in the background`) and never block. All of this was committed as `23c0b8c` (*"feat: JOURNEY.md experiment log + historian agent + journaling convention"*).

**Placing the anchor precisely.** A subtle correctness step: the coverage anchor had to sit *between* the CI-monitor work (Chapter 9, already written) and the journaling discussion (not yet written), or the historian would duplicate or skip. The assistant pulled the real transcript timestamps — CI/CD work ran through ~05:04Z; the JOURNEY discussion began at **05:19:00Z** — and set the anchor between them so the historian's *first* job would be to journal *exactly the saga of its own creation.* As the assistant put it: *"a fitting first auto-entry."*

**The dogfood.** The chapter closes on the test itself: the historian was dispatched (read-and-adopt, Opus, backgrounded) to journal the single uncovered window — the journaling discussion. In the assistant's words, *"the real test — dogfooding the historian … If it works, the historian writes its own origin story."* This chapter is that output.

**Agent-driven?** ✅ A fourth agent (`historian`) plus a new `CLAUDE.md` convention. No app code touched. Notably, the design itself was reached the agent-first way: the *decision* of whether the historian should exist was reversed four times and resolved entirely in dialogue, then encoded in the agent definition and the inherited contract — not improvised in code.

---

## Chapter 11 — The End-of-session checklist (2026-06-13)

With the journaling system live and verified end-to-end, the assistant offered the obvious next move — *"the **backend agent → the Percentage calculator** … that's where corrections either keep landing in agent definitions and shrink over time, or they don't"* — and asked whether to start measuring or keep sharpening tooling. The user kept sharpening, and added a new piece of process hygiene:

> "Mehehe not yet - let's also document a set of 'End of session' action items. I'll do my best to remind you to run end session steps before closing the session. For now, add 'dispatch historian agent' and 'verify no unstaged files' as the two items to check on for end of session"

The assistant accepted and folded in one refinement of its own, born from the mechanics of how the historian runs: at session *end*, the historian dispatch should **run to completion**, not fire-and-forget. In its words: *"a backgrounded run could get cut off before it commits when the session closes."* This is a deliberate inversion of the mid-session rule (Chapter 10), where the historian is explicitly fired *in the background* so the user never feels it. The two contexts call for opposite handling, and the checklist now says so.

**What got built.** A new **"End of session"** section in `CLAUDE.md` (commit `51c0b41`), with two items: (1) *"Dispatch the historian — and let it finish"* — journal everything since the coverage anchor, waiting for completion rather than backgrounding, *"since the session's closing"*; (2) *"Verify no unstaged files"* (`git status`; surface anything left so leaving it is a deliberate choice). The assistant wrote it as an explicitly **growing list** — the section text reads *"This list will grow"* — so future end-of-session hygiene just gets appended. It is framed as a main-thread responsibility triggered by the user's *"end session"* nudge.

A small meta-note closes the chapter, and it is itself a data point on the journaling discipline: the assistant **deliberately did not fire the historian** for this change. Its reasoning: *"a checklist addition is a minor process tweak, below the 'decision/pivot' bar, so it'll get swept up at the next real checkpoint or at end-of-session. Keeping the journaling signal-to-noise high."* (And so it was — this chapter was written in exactly that sweep.)

**Agent-driven?** ✅ A process convention added to the inherited contract (`CLAUDE.md`). No app code touched.

---

## Chapter 12 — Keeping the raw record: the conversations/ snapshot, and a durability question answered with evidence (2026-06-13)

The user surfaced one more idea, framed as indulgent but pointing at something real — preserving the *raw* history, not just the synthesis:

> "One last insane thing, can we have the historian agent also write the entire history as is to a file on every run? This could be a gitignore'd (for now) folder of conversations. If this can be done by the subagents too, I'd be over the moon. A way to replay every decision and every action. The synthesis done on a regular cadence in JOURNEY.md IS uniquely important, I want the raw stuff kept too"

The key distinction the user drew: `JOURNEY.md`'s synthesis is *"uniquely important"*, but it is lossy by nature — the historian quotes and narrates, it does not preserve every word. The user wanted **both**: the synthesized story *and* the verbatim, replayable record underneath it.

**Why it was more feasible than it sounded.** The assistant's response opened with genuine enthusiasm — *"this one's genuinely satisfying — and it's *more* feasible than you might expect, because the raw history already exists on disk as JSONL."* The insight that made the whole feature nearly free: the harness *already* writes every message to disk, so the historian doesn't need to *generate* a transcript — it just **snapshots** what is already there into a folder outside `~/.claude`. And the *"subagents too"* wish — the part the user would be *"over the moon"* about — fell out for free, because **subagent conversations are also transcripted to disk** as `agent-<id>.jsonl`. The assistant verified this rather than assuming it: it found **10 subagent transcripts** under `<session>/subagents/` — *"every `pm`, `ci-monitor`, `historian` run I dispatched"* — plus the main session JSONL. As it put it: *"a snapshot of the project's transcript dir captures *every* main-thread message **and** every subagent conversation … Your 'over the moon' is achievable with zero per-subagent work."*

**What got built** (commit `6b2a100`):
- **`bin/snapshot-transcripts`** — a small reusable script that mirrors every session transcript and every subagent conversation for this project into `./conversations/`. The first run copied **11 transcripts** (1 main + 10 subagent) and git correctly ignored the folder.
- **`.gitignore`** — a `conversations/` entry, so the raw snapshot is a *local* copy (gitignored "for now," per the user's framing).
- **`.claude/agents/historian.md`** — taught to run `bin/snapshot-transcripts` **first, on every invocation, unconditionally** — *"even if there is nothing new to journal."* Its hard-boundary clause was widened accordingly: the historian now writes *only* `JOURNEY.md` **plus** the gitignored `conversations/` snapshot, and still commits **only** `JOURNEY.md` (the snapshot is gitignored — nothing to commit). The raw record is *"the raw, replayable counterpart to your synthesized narrative."*

**The durability question, answered with evidence.** Having built the snapshot, the assistant turned to a concern the user had raised about history being lost, and answered it deliberately — *"with evidence, not reassurance"* — by pulling the transcript's integrity end-to-end rather than reasoning from memory. The findings:

- **The main transcript is complete and continuous:** `530f44b9-….jsonl`, **901 lines / 2.35 MB**, spanning **`01:43:56Z` → `05:52:24Z`**. The assistant grepped for the user's literal opening words — *"use this project as an experiment"* — and confirmed them **present**, proving nothing was missing from the front: *"a continuous record from message one to now."*
- **All 10 subagent conversations present**, none missing; and *"this experiment has been a single session, so there's exactly one main transcript, whole."*

The assistant then drew a distinction it called out as commonly conflated — *"two things people conflate, and only one is a deletion"*:

> "**Context compaction ≠ disk deletion.** When *my* working context gets summarized, that only trims what's in the model's window. **The on-disk `.jsonl` is append-only and complete** — every raw message stays."

The only thing that actually deletes is **age-based retention cleanup** (`cleanupPeriodDays`, unset → default **30 days**), which removes *whole transcripts untouched for 30 days* — it *"does not truncate an active session,"* and nothing qualified now (the session was hours old). The assistant laid out the real exposure (~30 days out) and three layers of protection in order of strength: the snapshot just built (already mitigates it, since `conversations/` lives outside `~/.claude` and is re-run every historian invocation); **un-gitignoring** `conversations/` to commit it for true permanence; or **raising `cleanupPeriodDays`** (e.g., 3650) so cleanup never fires. It offered to do the latter two *"right now … both are reversible,"* or leave it as the local snapshot.

The user scoped the concern precisely, and declined the heavier options:

> "That's fine, I'm only looking for in-session durability (i.e. history being scrubbed while a discussion is still going). We're good here."

So the snapshot stayed gitignored, retention untouched — the in-session integrity (confirmed empirically) was all that was needed. The user then asked *"Where are we now?"*, and the assistant fired the historian in the background to journal this very stretch — the marker line being *"📝 Journaling the recent stretch (snapshot feature + durability) in the background while I bring you up to date."*

**Agent-driven?** ✅ A new tool (`bin/snapshot-transcripts`) + a widened historian boundary + a `.gitignore` entry — all encoded in the agent definition and tooling, no app code. The durability answer is also a clean instance of the verification habit first seen in Chapter 10: rather than reassure, the assistant *pulled the actual byte count, line count, timestamp span, and grepped for the literal first message* before making any claim about integrity.

---

## Running assessment — "Does this work?"

*Evidence to date; updated as the experiment proceeds. Deliberately unopinionated — observations, not verdicts.*

- **Every product and process decision so far landed in an agent definition or a doc, never in hand-written app code.** The two hand-edits (CI config, a `.keep` file) were infra, not the product. The experiment's discipline has held.
- **The clearest single data point:** when the user changed their mind about issue-seeding, the fix was a six-line edit to `pm.md`, committed as `feat(pm):`. Changing behavior meant changing the agent. That is the loop working.
- **The method produced a layered structure quickly** — three agents (`pm`, `ci-monitor`, `historian`), two north-star docs, a conventions doc, a tracking spine, and green CI — *before a single calculator was built.* This is the "heavy upfront investment" the user anticipated; whether it pays off is the open question the later chapters will answer.
- **A new kind of data point appeared in Chapter 10:** the decision about whether the historian should exist was reversed *four times* before settling, and every reversal happened in dialogue and resolved into an agent definition + a `CLAUDE.md` convention — not into code. The "describe my work with great intent" challenge here took the form of the user repeatedly catching that *the premise had changed underneath the previous conclusion*, with the assistant re-deriving rather than flip-flopping silently. The historian then journaled its own contentious origin as its first task — the loop closing on itself.
- **One verification habit is visible and held:** before committing to the transcript-reading design, the assistant *checked that the transcript was actually readable and parseable* (size, structure, real text) rather than assuming. Design feasibility was confirmed empirically. The habit recurred in Chapter 12: asked about durability, the assistant pulled the transcript's actual byte/line count, timestamp span, and grepped for the user's literal first message before claiming the record was intact — *"evidence, not reassurance."*
- **The journaling discipline is showing self-restraint, not just activity (Chapter 11):** the assistant *deliberately declined* to fire the historian for a minor checklist addition, judging it below the "decision/pivot" bar and choosing to keep the journaling signal-to-noise high. The system is being used with judgment about *when not* to use it — and that minor change was correctly swept into the next checkpoint anyway.
- **A second durable artifact now backs the synthesis (Chapter 12):** the raw, verbatim transcripts (main + every subagent) are snapshotted to `conversations/` on every historian run. The experiment now keeps *both* the lossy synthesized narrative and the complete replayable record — and the historian's "does this work?" account can be audited against the raw source at any time.
- **The cost is real and visible:** this is a great deal of dialogue and documentation for what is, so far, zero user-facing features. The bet is that the agents and docs are reusable infrastructure that makes the *next* 191 calculators cheap. Unproven yet.
- **A recurring pattern:** the user repeatedly caught structural improvements (Issues, ARCHITECTURE, PRODUCT.md, CLAUDE inheritance, the historian) that the assistant then designed. The "describe my work with great intent" challenge is being met largely through this catch-and-refine rhythm.

**Open question:** the convergence experiment hasn't started measuring yet — no calculator has been built by the (not-yet-existent) backend/frontend agents. Everything above is *foundation*. The real test begins when those agents produce calculators and we see whether corrections keep landing in agent definitions and shrink over time.

---

## Artifact ledger

**Agents:** `pm` (Opus; tracking/docs/Issues), `ci-monitor` (Sonnet; report-only CI watcher), `historian` (Opus; writes only `JOURNEY.md`, background fire-and-forget, anchor-driven). *Pending:* backend, frontend.
**North-star docs:** `JOURNEY.md` (this), `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `CLAUDE.md`.
**Tracking:** `docs/inventory.md` (191 calculators), `docs/logs/` (iterations), GitHub Issues (`engineering`/`agents`).
**Specs/plans:** `docs/superpowers/specs/2026-06-12-project-tracking-pm-agent-design.md`, `docs/superpowers/plans/2026-06-12-pm-agent.md`.
**Tooling:** `bin/ci-watch`, `bin/snapshot-transcripts` (mirrors all session + subagent transcripts into the gitignored `conversations/` on every historian run).
