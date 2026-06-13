<!-- coverage-anchor: 2026-06-13T14:39:02.914Z — through Chapter 20, the frontend-agent design brainstorm: user sequenced frontend (#7) before backend (#6) to dogfood it on the stubbed login/home pages; the visual companion was used to explore aesthetic taste (setting aside Chapter 2's describe-in-words method, at the user's request — "Can you show me examples of these on a webpage?"), narrowing across three rounds to the settled BLEND aesthetic ("Let's codify BLEND"); the user chose Tailwind over plain CSS (an informed override reversing the celebrated no-build-step property; CLAUDE.md "Starting the app" slated for rewrite), and decided the main thread does the initial Tailwind install while the frontend agent owns theme/views/tests. Design only — committed as spec 5d92c25, awaiting the user-review gate; no agent def or app code yet. PRE-Chapter-19 note retained: (PM was the first agent built and the least used; mainly because no calculator has been built, but also because the orchestrator bypassed it for routine tracking — issues #4/#6/#7 and PRODUCT.md written directly — since its heavyweight full-context launch ingestion is disproportionate for one-off tracking, and it isn't a registered subagent type yet; the pending design question: route all tracking through the PM vs. orchestrator-handles-routine + PM-for-synthesis/sequencing/iteration-boundaries; its real test comes with calculators). The historian journals transcript activity AFTER this anchor and advances it. -->

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

## Chapter 13 — "Time for the foundation" — the implementation plan (2026-06-13)

After the snapshot/durability stretch, the assistant laid out the state of the world plainly — three working agents, the knowledge layer, green CI — and then the gap, in its own words: *"**No app foundation** (auth, RBAC, `Calculation` model, `Discardable`, CLI tasks, the first migration). **Zero calculators. Zero user-facing features.**"* The honest read it offered on the experiment was unchanged from the running assessment: *"Every decision has landed in an agent or a doc … But the experiment hasn't started *measuring* yet … Everything so far is foundation and instrumentation."* It framed the next move as *"the line we keep (rightly) walking up to: **the app-foundation plan** → **the backend agent** → **the Percentage calculator**,"* and called the repo *"a remarkably complete *workshop*"* whose next job was *"to actually forge the first thing in it."*

The user said go:

> "Time for the foundation, yes. Where do we begin?"

The assistant made one design point about *where* to begin that is itself a data point on the method: **no new brainstorm was needed**, because the design already lived in a doc. In its words: *"We already did the design work; `ARCHITECTURE.md` *is* the foundation's spec (schemas, the layering, soft-delete, auth, RBAC, the coverage gate are all pinned there). So the foundation goes straight to an **implementation plan** → build."* It enumerated the foundation's scope — `Discardable`; auth (`User`/`Session`/`Current`, no email/reset/signup); RBAC (`RoleType` seeded `ADMIN`, `Role`, `User#admin?`); `Calculation` + the `calculation_logs` view + first migration; CLI rake tasks; the SimpleCov 100% gate — and drew a deliberate **scope boundary**: the *calculator scaffolding* (`Calculators::Base`, the dynamic controller, the route, the autoload initializer) is **not** in the foundation, because *"'how a calculator is built and wired' is exactly its [the backend agent's] specialty. The foundation gives the backend agent a platform … to build *on*."*

One genuine, experiment-design decision was put to the user — how to execute — and it was resolved as **subagent-driven, per the docs**: *"general subagents executing the plan while reading `ARCHITECTURE.md` + `CLAUDE.md`, so your style rides in through the conventions."*

**The plan.** The assistant used the **writing-plans** skill and, before writing, grounded it in *ground truth* rather than assumptions — confirming the Rails 8 `authentication` generator exists (but choosing to **hand-write auth for determinism**, *"generator output varies by version"*), that `bcrypt` was commented in the Gemfile, that `simplecov` wasn't yet a dependency. The result — **5 TDD tasks** (Authentication; Soft-delete + RBAC; `Calculation` + the `calculation_logs` view; CLI rake tasks; the 100% coverage gate) — was committed docs-only as `d012985` (`docs: app-foundation implementation plan`). Two notes the assistant flagged for the user's eye: auth is hand-written (*"Task 1 is the security-sensitive one"*), and **the coverage gate is the last task** because *"turning on `minimum_coverage 100` before code exists trips on the empty state."*

It also named what this run *was*, beyond a feature: *"This is also the first time we **dogfood the full intended workflow**"* — PM mints the issue, branch off `main`, subagent-driven build with two-stage review, PR closing the issue, `ci-monitor` watches, human merges.

**Agent-driven?** ✅ The foundation went straight from the conventions doc to a plan, with no redesign — the architecture doc earned its keep as the spec. The plan is a doc; no app code yet.

---

## Chapter 14 — The subagent-driven build: five TDD tasks, a real bug caught (2026-06-13)

The user gave a one-word green light — **"go"** — and the assistant executed via the **subagent-driven-development** skill: a fresh implementer subagent per task, each instructed to *first read `ARCHITECTURE.md` + `CLAUDE.md`*, with independent review between tasks. Issue **#4** was minted (`engineering`), branch **`foundation`** checked out. This is the first real product code in the repo, and it was built **entirely by subagents** following the conventions docs.

The five tasks, each verified independently rather than on the implementer's word (*"not trusting the report"*):

- **Task 1 — Authentication** (`2811a45`). Implementer reported DONE (7 runs, 22 assertions). The assistant ran an independent **spec-compliance review** — *"✅ compliant — independently verified (code read, suite run green, `structure.sql` checked, no out-of-scope code, cookie signed + httponly, auth not globally required)"* — then a **deep code-quality review**, because *"Task 1 is the security-sensitive one."* That review earned its keep: it **found a real bug** — *"failed logins set a flash alert but **nothing renders it**, so users get silent rejection. That's a legitimate must-fix."* The assistant applied judgment to the reviewer's minor points rather than blind agreement: it **deferred** password-length (*"would break fixtures — revisit at Task 4"*), form labels (*"the frontend agent's job"*), and multi-session (*"by design"*). The flash fix landed via a focused fix subagent (SendMessage being unavailable to continue the warm one) as `09cadde` (7 runs, 26 assertions, green). For a fix *"this small and exactly-specified,"* the assistant verified directly rather than spinning up another full review.
- A process decision logged here: for the *remaining* mechanical tasks (models, migrations, rake) the assistant chose to run the independent **spec review per task** plus **one holistic code-quality review of the whole branch at the end**, rather than a full two-stage cycle on each — *"Task 1 was the security-sensitive one that warranted the deep per-task quality pass."*
- **Task 2 — `Discardable` + RBAC** (`4d0b3ab`, 12 runs, 39 assertions). The implementer *"caught a real fixture collision (the new `bob` fixture vs. the existing normalize test) and fixed it sensibly."* Spec review ✅.
- **Task 3 — `Calculation` + the `calculation_logs` view** (`8ab8103`, 16 runs, 46 assertions). *"Crucially the view round-trips through `structure.sql`, which was the risk I flagged"* — i.e., the SQL-schema-format decision from Chapter 9 paid off exactly where predicted. No calculator code leaked in (*"correctly the backend agent's job"*).
- **Task 4 — CLI rake tasks** (`b16541c`, 19 runs, 50 assertions, 3 files): `users:create` / `set_password`, `admins:grant` / `revoke`.
- **Task 5 — the 100% coverage gate** (`635e392`). *"Genuine **100% line (98/98) + 100% branch (6/6)** coverage, the gate verified to bite (removing a test → exit 2), 22 runs/57 assertions green."* The task most likely to surface uncovered lines did not — the TDD build had kept coverage whole.

**Agent-driven?** ✅ Every line of the foundation was written by subagents reading the conventions docs; every correction — including the flash bug — went through a subagent, not a manual patch. The discipline held under the first real build.

---

## Chapter 15 — The final holistic review, and judgment over agreement (2026-06-13)

With all five tasks done, the assistant ran the **final holistic review of the entire branch** before the PR. Verdict: **READY TO MERGE**, with one must-fix and some noted follow-ups — and the assistant again *"appl[ied] judgment (not blind agreement)"*:

- **I-1 (cookie `secure`)** — the assistant judged the finding *"partly over-stated: `force_ssl` *does* mark cookies secure in production … and the current code matches the Rails 8 generator."* But it adopted the change anyway as *"cheap, standard defense-in-depth,"* with a sharp correctness caveat: *"it must be env-gated, not unconditional — `secure: true` everywhere would break the HTTP test/dev login."*
- **m-1 (RoleType `dependent: :destroy`)** — *"legitimately off-convention (we soft-delete, never cascade hard-deletes). One-word fix to `:restrict_with_exception`."* Adopted.
- **m-2 (partial unique index)** — *"real but low (CLI-only, `find_or_create_by` mitigates); **defer** as a follow-up (it's a migration)."*

The two cheap, correct fixes landed as `9f406ec` (`fix: secure session cookie in production; RoleType restrict hard-delete`) — *"suite green, coverage still 100%/100%."* This is the same receiving-code-review discipline seen earlier: the reviewer's findings were weighed on technical merit, two adopted, one re-scoped, one deferred with a reason.

**Agent-driven?** ✅ Review findings resolved through reasoning and a subagent-built branch, no hand-improvised product logic.

---

## Chapter 16 — Adopting tenor's branching strategy (2026-06-13)

Before pushing, the assistant **held the push** to honor a prior request — *"you asked me to check tenor's branching strategy first."* It reviewed the sibling project `../tenor` and summarized its full **`Issue → Branch → Commit → PR → Merge → Deploy → Cleanup`** workflow: GitHub issue with a Success-Criteria checklist; *always* a git worktree (`.claude/worktrees/<name>/`) for concurrent-session safety; branch named **`fix/<issue#>-<brief-description>`**; **`Closes #<issue>`** in commit bodies; `gh pr create` with **merge commits, never squash**; `bin/ci-watch`, never auto-merge; merge only on explicit say-so; deploy-watch; then cleanup.

It laid the comparison against the just-built `foundation` branch in a table — the deltas being branch naming (`foundation` vs `fix/N-desc`), no worktree, and `Closes #N` planned for the PR body rather than the commits — and kept the project's *intentional* differences (the `engineering`/`agents` label taxonomy; the `Co-Authored-By: Claude Fable 5` trailer, *"per our env's instruction"*). Its recommendation: **adopt tenor's flow, keep the intentional differences** — concretely: rename `foundation` → `fix/4-app-foundation`; close #4 via the PR body (adding `Closes #4` retroactively *"means rewriting 8 commits; the PR-body close is equivalent and clean"*); merge-commit-not-squash to *"preserve the per-task commit story (which this experiment values)"*; adopt worktrees *going forward* but not retrofit; and **codify a "Branching" section in CLAUDE.md.**

The user approved all of it, and stacked on two more requests:

> "1, 2, 3, 4, and 5 yes
>
> Also, add a section in CLAUDE.md that whenever I ask you to spin up the app, fire up whatever the appropriate server startup command is - maybe here it's foreman run start? Let's review
>
> We may want to verify that migrations happen if needed on startup too
>
> So let's rename / push / open PR with Closes #4 and monitor CI. Then, add all of the listed items. Then, add a section in CLAUDE.md on what it means to start up the app. Then, successfully start it up so we can see the results and test"

**Agent-driven?** ✅ A cross-project convention was reviewed, adapted (not copied wholesale), and slated for the inherited contract.

---

## Chapter 17 — The first time the app ran: a live end-to-end login test (2026-06-13)

The assistant executed the user's ordered plan exactly.

**Rename / push / PR.** `foundation` was renamed → **`fix/4-app-foundation`** and pushed; **PR #5** opened with `Closes #4`. Per convention, `ci-monitor` was fired in the background to watch it — and reported **green** (all 5 jobs). The assistant *"await[ed] your explicit say-so to merge"* — never auto-merging, per the project's own rule.

**The startup review** the user asked for resolved a small assumption: *"no Procfile, no foreman — this is an importmap + propshaft app (no JS/CSS build step), so `bin/dev` is just `exec bin/rails server`. So the start command is simply **`bin/dev`**, and `bin/rails db:prepare` is the idempotent 'migrate-if-needed' (creates DB, applies pending migrations, seeds). No foreman needed here."* The user's instinct (*"maybe here it's foreman run start? Let's review"*) was reviewed and corrected with evidence, and the migrate-if-needed concern was answered by `db:prepare`.

**CLAUDE.md gained two sections** — committed to **`main`** (not the feature PR, because *"conventions belong on `main`, not in the feature PR"*) as `0eb429d` (`docs: add branching/PR workflow and app-startup conventions to CLAUDE.md`): the **Branching & PR workflow** (the adopted tenor-style flow — `fix/N-desc`, worktrees-going-forward, `Closes #N` in the PR, merge-commit-not-squash, never auto-merge, cleanup) and **Starting the app** (`bin/rails db:prepare && bin/dev`; no foreman).

**Then — the first time the app actually ran.** Back on the feature branch, the assistant prepared a real Postgres DB and exercised the CLI: *"`db:prepare` seeded the ADMIN role, created user #1 (`demo`), granted admin — verified `users=1, admins=1, roletypes=1`."* It started the server (HTTP 200) and ran a **full live end-to-end login test** through the running server with a CSRF token and cookie jar. The result, in its words:

| Test | Result |
|---|---|
| Anonymous root | `not signed in` ✅ |
| Login form | `<h1>Sign in</h1>`, CSRF token present ✅ |
| Login as `demo` → root | **`Signed in as demo`** ✅ |
| Wrong password | **`Invalid username or password`** flash shown ✅ |

As the assistant put it: *"That exercises the *whole* stack live — CSRF, the signed session cookie, `authenticate_by`, the flash fix from review — plus the CLI."* The app was *"**running at http://localhost:3000** (login `demo` / `password123`, an admin)."* Note the last row: the *"Invalid username or password"* flash is precisely the bug the code-quality reviewer caught in Chapter 14 — its fix, verified live against a real server.

The assistant closed with the experiment data point in plain terms: *"This was **the first real product code**, and it was built **entirely subagent-driven** — five TDD tasks, each reading `ARCHITECTURE.md` + `CLAUDE.md`, with reviews that caught a genuine bug (the silent failed-login), all fixes applied through subagents. The agent-first discipline held: every correction went through the process, not a manual patch. So far, on this evidence, the loop produces working, tested, reviewed code."* PR #5 was left green and unmerged, awaiting the user's explicit instruction — pointing next at *"the **backend agent → the Percentage calculator** — where the convergence experiment finally starts *measuring*."*

**Agent-driven?** ✅ The first product was built and corrected entirely by subagents reading the conventions docs; the only hand-typed steps were git mechanics (rename/push/PR), the CLAUDE.md convention edits, and the manual run that *verified* the agents' output. The conventions docs proved sufficient to carry the user's style into code written by agents that never saw the conversation.

---

## Chapter 18 — "Does this meet your expectations?" — the screenshots, the merge, and closing the first cycle (2026-06-13)

This chapter closes the session — and with it, the first complete feature cycle — on the most direct test the experiment had yet faced: the user putting the running app in front of their own eyes.

**The screenshots.** The user attached three browser screenshots of the live foundation and asked, simply:

> "Does this meet your expectations?"

The three captures were the same three states the Chapter 17 live test had exercised, now rendered in a real browser (Safari, against `localhost`):
1. **Anonymous root** — *"You are not signed in."* followed by a plain "Sign in" link.
2. **Authenticated root** — *"Signed in as demo."* with a default blue "Sign out" button.
3. **Failed login** — the *"Invalid username or password."* flash sitting above a bare **"Sign in"** heading and an unstyled username/password form. All three in raw, default-browser typography (Times New Roman, native form controls).

**The answer drew a deliberate line between two kinds of expectation.** The assistant answered yes, but split the judgment in two — *"there are two and they pull in opposite directions"*:

> "**Functionally: it's exactly right.** All three states render correctly … And screenshot 3 is genuinely satisfying: that **"Invalid username or password."** flash is the *exact bug the code review caught* — the controller set the alert but no view rendered it — now visibly working in a real browser. The review-caught fix, in the wild."

> "**Visually: it's intentionally barebones — and that's the correct outcome, not a miss.** Those are the *placeholder* views … `HomeController` is literally commented "the frontend agent replaces this." So raw Times-New-Roman HTML with default browser buttons is *exactly* what this should look like right now. In fact, if it looked polished, that would be a **scope violation** — the foundation reaching into UI/design it has no business owning."

The assistant framed the screenshots as evidence of *the backend/frontend seam holding*: *"the foundation produces correct, functional, *ugly* output, and making it beautiful is a job that doesn't exist yet — the **frontend agent**, whose entire charge (per `PRODUCT.md`) is "the UI should be genuinely good.""* Its honest read: *"the foundation met its bar; the ugliness is a feature of scope discipline, not a defect. The beauty comes later, deliberately, from a different agent."* This is a notable data point: shown an unpolished result, the assistant did *not* reflexively offer to fix the appearance — it identified the bareness as the *correct* boundary of the foundation's scope, and named which (not-yet-built) agent owns the gap.

**The merge.** Offered two next moves — merge #5, or build the backend agent first — the user chose to land the foundation:

> "Merge, this is a great first PR to step us towards where we're heading"

The assistant merged on the explicit instruction (never auto-merging), with a **merge commit** per the just-adopted convention — *"preserving the per-task commit story."* **PR #5 merged to `main` (merge commit `a8b6f5d`), issue #4 closed.** The foundation had landed.

**A reconciliation the merge surfaced — the historian had committed to the wrong branch.** Immediately after the merge, the assistant caught a coordination problem and surfaced it rather than hiding it:

> "the background historian just finished and committed its chapters (13–17) to the *feature* branch (that's where HEAD was when it ran), not `main`."

Because the mid-session historian had been fired in the background while HEAD was on `fix/4-app-foundation`, its JOURNEY commit (`62a4e6f`, Chapters 13–17) lived on the feature branch, not `main`. The assistant **cherry-picked it onto `main`** — *"Cherry-pick clean — `main` now has the foundation **and** JOURNEY through Chapter 17"* — before deleting the branch, so the journal entry would survive cleanup. This is a small but real wrinkle in the background-historian mechanism: a backgrounded run commits to wherever HEAD happens to be, which during feature work is the feature branch; the main thread had to reconcile it back to `main` by hand (a git mechanic, not a code edit).

**The cleanup, and one loose end caught by the project's own discipline.** Per the new convention, the assistant deleted the feature branch (remote + local). Then the "no unstaged files" check earned its keep: `git status` showed **one uncommitted change**, which the assistant surfaced rather than leaving silently — *"per our own "no unstaged files" discipline."* It was `coverage/`, SimpleCov's generated output the foundation had produced but never gitignored. The fix was a small hygiene commit — **`coverage/` gitignored** (`00fe0b0`, `chore: gitignore SimpleCov coverage/ output`). The end-of-session checklist item from Chapter 11 caught exactly the kind of loose end it was written to catch.

The assistant summarized the cycle in plain terms: *"That's the **first complete feature cycle** — Issue → branch → subagent-driven build → reviews → PR → merge → cleanup → journaled — with the first real product code now on `main`. The workshop built itself, then built something."*

**Ending the session — where next steps live.** The user declined to start the backend-agent brainstorm and called the session:

> "No, let's end session - where should we document next steps?"

The assistant's answer reaffirmed the tracking split established back in Chapter 4: *"**next steps belong as GitHub `engineering` issues** (that's exactly what the kanban is for), with the high-level sequence already living in `docs/PRODUCT.md`'s roadmap."* It created two issues so the next session (and the PM) would pick them up, and stopped the dev server:

- **Issue #6 — Build the backend agent** (`engineering`).
- **Issue #7 — Build the frontend agent** (`engineering`).

The assistant recorded its own instinct on sequencing — build the **backend agent next**, because *"it's the more objective, measurable half (math verifiable against calculator.net to the decimal), so it's the cleanest first read on whether agent-iteration converges"* — but left the decision to the next session. Then it began the End-of-session checklist: stop the server (done), and **Step 1: run the historian to completion** in the foreground (not backgrounded, since the session is closing — the Chapter 11 inversion), *"and conveniently we're on `main`, so it commits there directly."* That foreground run is the one writing this very chapter.

**Agent-driven?** ✅ The product code was not touched. Every action here was either a git mechanic (merge, cherry-pick, branch delete), a one-line gitignore hygiene commit, or tracking (issues #6/#7) — and the appraisal of the screenshots reaffirmed the scope boundary (foundation = functional/bare; frontend agent = beauty) rather than reaching across it. The historian-on-the-feature-branch reconciliation is the one piece of friction the cycle surfaced in the journaling mechanism itself, resolved by a hand cherry-pick.

---

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

## Chapter 20 — Frontend before backend, and "Can you show me?": the visual companion meets the describe-taste-in-words philosophy (2026-06-13)

A fresh session opened on inventory and immediately made a sequencing decision that inverted the assistant's standing instinct — then spent its length brainstorming the *frontend* agent's design, with a methodological wrinkle worth recording carefully: the experiment that began (Chapter 2) by deliberately choosing to **describe taste in words** instead of deriving it from examples now reached for a browser-based **visual companion** to *show* aesthetic options. This chapter is design only — no agent definition, no view, no Tailwind install has been written yet — so it documents a set of *decisions and a committed spec*, not an implementation.

**The queue, and the sequencing inversion.** The user asked *"What do we have queued?"* The assistant reported the two open `engineering` issues — **#6 (build the backend agent)** and **#7 (build the frontend agent)** — and recommended backend first, restating the Chapter-18 instinct: *"#6 (backend) is the natural next pick — the math layer is the foundation the frontend renders, and `ARCHITECTURE.md` makes the math layer pure/testable first."* The user overruled it with a concrete plan:

> "Let's do #7 first., Go grab all of the history about this project. I'd like to work on the frontend agent and use that on the currently stubbed login pages to get that standing. It'll be a good experiment. Then we can do the first backend piece of work + set up the backend agent, then when we do the frontend for it, we'll have an agent to work with"

The reasoning is sequencing-by-dogfood: the foundation already shipped two **stubbed pages** (login, home) in Chapter 18, so the frontend agent has a real, non-calculator surface to be tested against *now*, before any backend exists. By the time the first calculator's UI is needed, the frontend agent will already be a working tool. The assistant adopted the order without further argument.

**The agent-as-design-work framing.** The assistant opened by invoking the brainstorming skill — *"building a new agent definition is creative/design work, and getting the frontend agent's 'shape' right is the whole point of this experiment"* — then ingested the full project history (19 JOURNEY chapters, both north-star docs, `pm.md` as the agent-definition model, and the actual stubbed views). Its synthesis named the structural parallel that would anchor everything downstream:

> "a lean agent def (role/discipline/boundaries) that reads a **design source of truth**, with the **login-page dogfood doubling as the first reference implementation** that establishes the design system. That's the elegant parallel: `ARCHITECTURE.md : backend :: design-system : frontend`."

This is the Chapter 5 insight ("don't put the vision *in* the agent — point the agent at a doc that carries it") applied symmetrically to the frontend: the taste lives in a design doc the agent reads, not in the agent itself; the login pages become to the frontend agent what Percentage would be to the backend agent — the first reference build.

**The methodological tension, recorded honestly.** Reviewing the stack, the assistant noted Propshaft + importmap + Hotwire with **no CSS/JS build step** — *"the journey explicitly celebrates this"* — and that plain CSS with custom properties is the path of least resistance. Then it explicitly tied its *method* to the experiment's founding choice:

> "The experiment's philosophy. Chapter 2: you chose to *describe your style in words*, not derive an agent from a golden example. So I'll drive this **text-first** rather than reaching for mockup-picking. (The visual companion is available if you'd rather see options side-by-side — say the word — but I'm defaulting to words, in keeping with the experiment.)"

It then asked a single text question (`AskUserQuestion`) offering four aesthetic directions — **Swiss / editorial**, **Technical / instrument**, **Warm / approachable**, **Bold / distinctive-modern**. The user's answer reversed the text-first default in one line:

> "Can you show me examples of these on a webpage?"

The assistant accepted immediately — *"You've answered the question for me — you want to *see* them. Let me set up the visual companion."* This is a genuine data point for the experiment, and it cuts against the Chapter-2 premise rather than confirming it: when the question was *taste*, the user did **not** want to work in words — he wanted to look. The "describe my work with great intent in words" philosophy held for process, conventions, and architecture; for *visual aesthetics specifically*, the user reached for examples. Whether that's a limit of describing taste in prose, or simply the right tool for one narrow class of decision, is left open — but it is recorded as the first time the founding method was set aside at the user's request.

**The aesthetic exploration, narrowed in three rounds.** Rather than render abstract swatches, the assistant rendered the *same realistic product content* in all four directions so the comparison would be honest — first a **Percentage calculator page** (wordmark, heading, form, inputs, button, result: *"the exact ingredients the login dogfood needs"*), then served on a local port via the companion. The user narrowed:

> "I'm leaning towards A and C. Now, for each, can you show me a bit more complex example for each? Let's think about mortgage calculator, start simple but show me a potentially complex implementation in each design"

The assistant stress-tested A (Swiss) and C (Warm) on a full **mortgage calculator** — six-field input column, a headline result, a payment-composition chart (A: a thin Swiss stacked bar; C: a warm donut), a three-up stats row, and a tabbed amortization table — chosen precisely because dense financial data with a chart and a schedule is *"where a design system either scales gracefully or falls apart."* The user first said *"Let's go with C, the details of the layouts for something like the mortgage calculator can be looked at later"* — then, a minute later, reopened it into a synthesis:

> "Actually, can you keep both of these but show me an example of a blend? Slightly sharper font but same sweeping characters. The pie chart of #2, and find a potential for a touch of green in the warm colors if able / Keep #1 and #2 for comparison"

**The settled aesthetic — BLEND.** The assistant rendered a third screen (the **BLEND**, with A and C kept below for comparison) answering the three notes precisely: a crisp grotesk with tight `-0.035em` headlines that still sweep, **tabular numerals** everywhere numbers line up (borrowing A's table discipline), C's donut chart kept but recolored, and *"a touch of green"* threaded into specific places (the brand dot, the donut's largest slice, the active tab, the "Total interest" stat) while **coral stays the primary action color**. The hero became a clean white card with a coral edge instead of C's full gradient block, *"so the data reads sharper."* After a session gap (the server was restarted on a new port and the mockups re-served), the user gave the settle:

> "Let's codify BLEND"

**The Tailwind pivot — an informed override that reverses a celebrated property.** Before writing the spec, the assistant flagged *"exactly one infrastructure fork that shapes everything downstream (and all 191 future calculators)"* — how to author CSS. Its default recommendation was plain CSS with custom properties (preserving the no-build-step property the JOURNEY repeatedly celebrated). The user chose **Tailwind** instead. The assistant named this as a deliberate trade, not a drift:

> "Noted — Tailwind it is. That's an informed override of my default, and it has one concrete consequence I want to flag up front because it reverses a property the JOURNEY specifically celebrated."

The concrete consequence: `tailwindcss-rails` reintroduces a **build step** — `app/assets/builds/tailwind.css`, a `Procfile.dev`, and a `bin/dev` rewired to run **foreman** (web + a CSS watcher) — which directly contradicts CLAUDE.md's current *"Starting the app: no Procfile, no foreman"* line (Chapter 17's hard-won correction). So part of this work will be **rewriting that CLAUDE.md section** to the new foreman reality. The assistant noted the mitigations: no Node required (the gem ships a standalone Tailwind binary), and design tokens live in CSS via Tailwind v4's `@theme`. This is the first time a property the journey celebrated as a *win* is being knowingly given up at the user's direction — recorded plainly as a trade the user chose with the cost in front of him, not a regression.

**The lane split — who installs what.** The assistant asked whether the **frontend agent itself** should run the Tailwind install (a fuller end-to-end agent test) or whether **the main thread** should do the one-time toolchain install (as CI/infra setup had been main-thread work) and let the agent own only theme + views + tests. The user decided:

> "This thread should do the initial install"

That settles the division for this effort: **main thread** does the Tailwind install (Gemfile + generator + `bin/dev`/`Procfile.dev`), authors `docs/DESIGN.md`, writes `.claude/agents/frontend.md`, and makes the CLAUDE.md edits; the **frontend agent** (the dogfood) owns the BLEND `@theme` tokens, the layout chrome + restyled pages, and the tests. It mirrors the Chapter-13 pattern where toolchain/infra was main-thread work and the *product* was the agent's.

**The committed spec.** Per the brainstorming flow, the design was captured before any code as **`docs/superpowers/specs/2026-06-13-frontend-agent-design.md`** (commit `5d92c25`, `docs: frontend agent + BLEND design system design spec`), which also gitignored the visual-companion working directory (`.superpowers/`). The spec codifies: §3 the Tailwind trade-off; §4 the full BLEND design system (exact tokens — cream `#fdf8f3`, coral `#ef6c4d` primary, green `#2f9e6f` accent, amber, ink — the sharp-grotesk type scale with tabular numerals, the component vocabulary, a11y/responsive rules, destined for `docs/DESIGN.md`); §5 the frontend agent's shape; §6 the dogfood scope and the install lane split.

**The agent's shape, as designed (not yet built).** Per the spec, the frontend agent will **read first** `CLAUDE.md`, `ARCHITECTURE.md`, `PRODUCT.md`, and the new **`DESIGN.md`** (mirroring the pm launch protocol); **own** `app/views/`, `app/helpers/`, `app/assets/` (Tailwind config + tokens), and `app/javascript/controllers/` (Stimulus), coding only against the **JSON envelope (`ARCHITECTURE.md §4`)** and the DESIGN system; and **never touch** `app/calculators/` (math), models, controller business logic, migrations, or the backend's gems — a hard boundary like pm's. Its interaction model is Hotwire/Turbo with *minimal* Stimulus and progressive enhancement. The assistant also named an **honest asymmetry** for the experiment: the backend gets an objective gate (100% coverage + reference values to the decimal), but *"the frontend can't be gated that way"* — so its bar is Capybara system tests for render + key states, 100% coverage on any Ruby helpers, conformance to DESIGN.md, and **human visual review** (screenshots, like Chapter 18). ERB itself isn't coverage-counted. The dogfood's scope is explicitly the UI foundation + the two existing pages (`home/index` signed-in/out, `sessions/new` with the Chapter-14 flash); calculator UI, history/stats, and admin pages are deferred to the frontend agent's later jobs.

The session ended at the brainstorming skill's **user-review gate**: the spec is committed and the assistant asked the user to read it before it is turned into an implementation plan. Nothing has been installed or implemented yet.

**Agent-driven?** N/A so far — this chapter is design, not a build. No agent definition, no app code, no Tailwind install exists yet; the only committed artifact is the spec (`5d92c25`) plus the `.superpowers/` gitignore. The decisions that landed — frontend-before-backend, the BLEND aesthetic, the Tailwind pivot, the main-thread-installs lane split — are all *pending implementation*. The two data points worth carrying forward: (1) the founding "describe taste in words" method was set aside, at the user's request, for the one domain it covers least well (visual aesthetics) — the user wanted to *see*; and (2) a property the journey celebrated as a win (no build step / no foreman) is being knowingly traded away, with the cost surfaced before the choice.

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
- **The first real product code was built — and it was agent-built, per the docs (Chapters 13–17).** The app foundation (auth, RBAC, `Discardable`, `Calculation` + `calculation_logs` view, CLI tasks, the 100% coverage gate) was produced by **five subagents**, each instructed only to read `ARCHITECTURE.md` + `CLAUDE.md` first — none saw the conversation. The conventions docs were sufficient to carry the user's intent into code. This is the strongest evidence yet that the method *produces working software*, not just documents: the build is green, 100% line+branch covered, and **ran live end-to-end** (anonymous → "not signed in"; login as `demo` → "Signed in as demo"; bad password → flash). Notably, no app code had ever run before this point — the foundation is the first executable product.
- **The review loop caught a real bug, and it was fixed through the process (Chapter 14).** The code-quality reviewer found that failed logins set a flash that *nothing rendered* — a genuine silent-rejection bug. The fix went through a subagent, not a manual patch, and was then **verified live** (the "Invalid username or password" flash appearing on the running server is that exact fix). The two-stage review + judgment-over-agreement discipline (defer-with-reason on three minor findings; re-scope the cookie-`secure` finding while still adopting it) held across both the per-task review and the final holistic review.
- **The conventions doc paid off exactly where predicted.** Two earlier decisions proved load-bearing under the first build: the SQL schema format (Chapter 9) was *needed* for the `calculation_logs` **view** to round-trip through `structure.sql`; and `ARCHITECTURE.md` was complete enough that the foundation went *straight to a plan with no redesign* — the assistant explicitly noted *"we don't need a new brainstorm."* The heavy upfront investment began to discharge here.
- **The full intended workflow was dogfooded once, end-to-end (Chapters 13–17):** PM-minted issue (#4) → branch → subagent-driven build with two-stage review → PR (#5, `Closes #4`) → `ci-monitor` green verdict → human-gated merge (left unmerged, awaiting say-so). A cross-project convention (tenor's `Issue → Branch → PR → Merge → Cleanup` flow) was reviewed, *adapted* rather than copied, and codified into `CLAUDE.md` — keeping the project's intentional differences (label taxonomy, the `Claude Fable 5` trailer).
- **The cost is real and visible, but is beginning to convert:** the dialogue-and-docs investment now has its first tangible return — a running, tested foundation other agents can build *on*. The bet (reusable infrastructure making the next 191 calculators cheap) is still mostly unproven, but no longer at zero user-visible output.
- **A recurring pattern:** the user repeatedly caught structural improvements (Issues, ARCHITECTURE, PRODUCT.md, CLAUDE inheritance, the historian, the branching strategy, the app-startup convention) that the assistant then designed. The "describe my work with great intent" challenge is being met largely through this catch-and-refine rhythm — and in Chapter 17 the assistant *corrected* one of the user's instincts with evidence (no foreman; `bin/dev` + `db:prepare`).

- **The first complete feature cycle closed, and the user judged the output with their own eyes (Chapter 18).** Shown three browser screenshots of the running foundation and asked *"Does this meet your expectations?"*, the assistant answered yes by *splitting* the judgment: functionally correct (all three auth states render; the review-caught flash bug visibly fixed in a real browser) but *intentionally* bare — and named the bareness as the **correct** scope boundary, not a defect (*"if it looked polished, that would be a scope violation"*). This is the backend/frontend seam holding under direct visual inspection: the foundation owns function, the not-yet-built frontend agent owns beauty. The cycle then completed end-to-end — PR #5 merged to `main` (merge commit, per convention), issue #4 closed, branch cleaned up, journaled.
- **The "no unstaged files" discipline caught a real loose end (Chapter 18).** At cleanup, the end-of-session `git status` check (added in Chapter 11) surfaced an uncommitted `coverage/` directory the foundation had generated but never gitignored — fixed with a one-line hygiene commit. The checklist item caught exactly what it was written for.
- **The journaling mechanism surfaced its first friction, and it was reconciled by hand (Chapter 18).** The mid-session background historian had committed Chapters 13–17 to the *feature* branch (HEAD's location when it ran), not `main`. The main thread caught this post-merge and **cherry-picked** the journal commit onto `main` before deleting the branch. A backgrounded historian commits to wherever HEAD is — during feature work, that's the feature branch — so the main thread had to reconcile it. A small, honest wrinkle in the otherwise-clean fire-and-forget design.
- **Next steps were documented per the established split (Chapter 18):** the two upcoming builds became GitHub `engineering` issues — **#6 (backend agent)** and **#7 (frontend agent)** — with the sequence living in `PRODUCT.md`'s roadmap. The assistant recorded an instinct (backend agent first, because math is *"verifiable against calculator.net to the decimal"* — the cleaner first read on convergence) but left the call to the next session.

- **The PM was the first agent built and so far the least used — a pending design question, not a verdict (Chapter 19).** Asked to comment on PM usage, the assistant confirmed the user's hypothesis (low usage is *mainly* because no calculator has been built — the PM's machinery is calculator-shaped: iterations, sequencing, synthesis, iteration logs) but named two honest secondary reasons: (1) the orchestrator **bypassed** the PM for the routine tracking that did happen (issues #4/#6/#7 created via `gh issue create` directly; `PRODUCT.md` written directly) because the PM's mandatory full-context launch ingestion is *heavyweight to invoke for one `gh issue create`*; and (2) the PM isn't a registered subagent type yet, so every call was the higher-friction read-and-adopt fallback. The inventory it *did* produce (191 calculators) was real and verified, and it correctly refused out-of-boundary work — *"low usage ≠ unproven, just unexercised in production."* The open design decision, stated as pending rather than settled: whether **all** tracking routes through the PM (at the cost of its heavy launch protocol), or the **orchestrator handles routine tracking with the PM reserved for synthesis/sequencing/iteration-boundaries** (possibly with a lighter "quick mode"). The next session — when calculators finally exercise the PM — is its real test, and `JOURNEY.md` will record whether it earns its keep or gets designed-around.

- **The founding "describe taste in words" method was set aside, at the user's request, for visual aesthetics (Chapter 20).** Brainstorming the frontend agent, the assistant deliberately defaulted to text-first *"in keeping with the experiment"* (Chapter 2's choice). The user reversed it in one line — *"Can you show me examples of these on a webpage?"* — and the assistant brought up a browser-based visual companion, rendering the same realistic product content (a Percentage page, then a complex mortgage page) in four directions, narrowing across three rounds to a settled **BLEND** aesthetic (C's warmth + donut, A's table discipline + tabular numerals, a sharper grotesk, "a touch of green" with coral staying primary). The data point: the describe-in-words philosophy held for process/conventions/architecture, but for *visual taste specifically* the user wanted to look, not read. Recorded as the first time the founding method was set aside — open whether that's a limit of prose-taste or just the right tool for one narrow class of decision.
- **A celebrated property is being knowingly traded away (Chapter 20).** Asked how to author CSS, the user chose **Tailwind** over the assistant's recommended plain-CSS path — an *informed override* the assistant flagged surfaces-cost-first: `tailwindcss-rails` reintroduces a build step (`Procfile.dev` + foreman), reversing the "no Procfile, no foreman" property the journey celebrated (Chapter 17). The cost was put in front of the user before the choice; CLAUDE.md's "Starting the app" section is slated to be rewritten to match. First time a journey-celebrated *win* is deliberately given up.
- **The frontend agent's design mirrors the backend's structure, and was captured as a spec before any code (Chapter 20).** The Chapter-5 parallel was extended symmetrically: `ARCHITECTURE.md : backend :: docs/DESIGN.md : frontend`, with the stubbed login/home pages as the frontend's *first reference implementation* (the role Percentage plays for the backend). The user inverted the assistant's standing instinct to sequence frontend (#7) **before** backend (#6) — to dogfood the agent on a real non-calculator surface now. An honest asymmetry was named for the experiment: the backend gets an objective gate (100% coverage + decimal-exact reference values); the frontend *can't* be gated that way, so its bar is system tests + helper coverage + DESIGN conformance + human visual review. The lane split for this effort: main thread installs Tailwind / authors DESIGN.md / writes the agent def; the agent owns theme + views + tests. All of this is **design only** — committed as a spec (`5d92c25`), pending the user-review gate; no agent definition or app code exists yet.

**Open question:** the convergence experiment *still* hasn't started measuring — the foundation is platform, not a calculator built by the (not-yet-existent) backend/frontend agents. But the precondition is now firmly met: the platform exists, runs, is reviewed, **merged to `main`**, and was judged acceptable by the user against their own visual expectations. The real test begins when the backend agent (issue #6) produces the first calculator (Percentage) and we see whether corrections keep landing in agent definitions and shrink over successive calculators.

---

## Artifact ledger

**Agents:** `pm` (Opus; tracking/docs/Issues), `ci-monitor` (Sonnet; report-only CI watcher), `historian` (Opus; writes only `JOURNEY.md`, background fire-and-forget, anchor-driven). *Pending:* backend, frontend.
**North-star docs:** `JOURNEY.md` (this), `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `CLAUDE.md`.
**App foundation (first product code, subagent-built):** session auth (`User`/`Session`/`Current`, no email/reset/signup), RBAC (`RoleType` seeded `ADMIN`, `Role`, `User#admin?`), `Discardable` soft-delete concern, `Calculation` model + `calculation_logs` DB view (real schema in `db/structure.sql`), CLI rake tasks (`users:create`/`set_password`, `admins:grant`/`revoke`), SimpleCov 100% line+branch gate. Ran live end-to-end; **PR #5 (`Closes #4`) merged to `main`** (merge commit `a8b6f5d`), issue #4 closed, branch cleaned up. The placeholder views (`home/index`, `sessions/new`) are intentionally bare — the frontend agent's territory.
**Tracking:** `docs/inventory.md` (191 calculators), `docs/logs/` (iterations), GitHub Issues (`engineering`/`agents`). Issue #4 (foundation) → PR #5, **merged + closed**. Next steps minted as issues **#6 (backend agent)** and **#7 (frontend agent)**, both `engineering`.
**Specs/plans:** `docs/superpowers/specs/2026-06-12-project-tracking-pm-agent-design.md`, `docs/superpowers/plans/2026-06-12-pm-agent.md`, `docs/superpowers/plans/2026-06-13-app-foundation.md`, `docs/superpowers/specs/2026-06-13-frontend-agent-design.md` (the BLEND design system + frontend agent shape; commit `5d92c25`, awaiting user-review gate). *Pending from this spec (not yet built):* `docs/DESIGN.md` (BLEND tokens/components), `.claude/agents/frontend.md`, the Tailwind install, and a CLAUDE.md "Starting the app" rewrite (Procfile.dev + foreman).
**Conventions added:** `CLAUDE.md` now carries a **Branching & PR workflow** (tenor-adapted: `fix/N-desc`, worktrees-going-forward, `Closes #N` in PR, merge-commit-not-squash, never auto-merge) and a **Starting the app** section (`bin/rails db:prepare && bin/dev`; importmap/propshaft, no foreman).
**Tooling:** `bin/ci-watch`, `bin/snapshot-transcripts` (mirrors all session + subagent transcripts into the gitignored `conversations/` on every historian run), `bin/dev` (server start).
