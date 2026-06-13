<!-- coverage-anchor: 2026-06-13T05:38:31.872Z — through Chapter 10, "The historian: an agent argues itself into, out of, and back into existence" (commit 23c0b8c; historian dogfood dispatch). The historian journals transcript activity AFTER this anchor and advances it. -->

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

## Running assessment — "Does this work?"

*Evidence to date; updated as the experiment proceeds. Deliberately unopinionated — observations, not verdicts.*

- **Every product and process decision so far landed in an agent definition or a doc, never in hand-written app code.** The two hand-edits (CI config, a `.keep` file) were infra, not the product. The experiment's discipline has held.
- **The clearest single data point:** when the user changed their mind about issue-seeding, the fix was a six-line edit to `pm.md`, committed as `feat(pm):`. Changing behavior meant changing the agent. That is the loop working.
- **The method produced a layered structure quickly** — three agents (`pm`, `ci-monitor`, `historian`), two north-star docs, a conventions doc, a tracking spine, and green CI — *before a single calculator was built.* This is the "heavy upfront investment" the user anticipated; whether it pays off is the open question the later chapters will answer.
- **A new kind of data point appeared in Chapter 10:** the decision about whether the historian should exist was reversed *four times* before settling, and every reversal happened in dialogue and resolved into an agent definition + a `CLAUDE.md` convention — not into code. The "describe my work with great intent" challenge here took the form of the user repeatedly catching that *the premise had changed underneath the previous conclusion*, with the assistant re-deriving rather than flip-flopping silently. The historian then journaled its own contentious origin as its first task — the loop closing on itself.
- **One verification habit is visible and held:** before committing to the transcript-reading design, the assistant *checked that the transcript was actually readable and parseable* (size, structure, real text) rather than assuming. Design feasibility was confirmed empirically.
- **The cost is real and visible:** this is a great deal of dialogue and documentation for what is, so far, zero user-facing features. The bet is that the agents and docs are reusable infrastructure that makes the *next* 191 calculators cheap. Unproven yet.
- **A recurring pattern:** the user repeatedly caught structural improvements (Issues, ARCHITECTURE, PRODUCT.md, CLAUDE inheritance, the historian) that the assistant then designed. The "describe my work with great intent" challenge is being met largely through this catch-and-refine rhythm.

**Open question:** the convergence experiment hasn't started measuring yet — no calculator has been built by the (not-yet-existent) backend/frontend agents. Everything above is *foundation*. The real test begins when those agents produce calculators and we see whether corrections keep landing in agent definitions and shrink over time.

---

## Artifact ledger

**Agents:** `pm` (Opus; tracking/docs/Issues), `ci-monitor` (Sonnet; report-only CI watcher), `historian` (Opus; writes only `JOURNEY.md`, background fire-and-forget, anchor-driven). *Pending:* backend, frontend.
**North-star docs:** `JOURNEY.md` (this), `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `CLAUDE.md`.
**Tracking:** `docs/inventory.md` (191 calculators), `docs/logs/` (iterations), GitHub Issues (`engineering`/`agents`).
**Specs/plans:** `docs/superpowers/specs/2026-06-12-project-tracking-pm-agent-design.md`, `docs/superpowers/plans/2026-06-12-pm-agent.md`.
**Tooling:** `bin/ci-watch`.
