## Chapter 135 — The harvest, staged for iteration-0008: a double agent-death, two PRs, seven issues, and an effective-rate judgment call (2026-06-26)

With the three feedback items routed and the two decisions locked (Chapter 134), the orchestrator drove the harvest as three parallel workstreams under the hard 2-subagent cap, each producing durable artifacts that land *ready for* iteration-0008 without opening it. The work spanned a session break (an API error truncated the run on 2026-06-25; the operator resumed with a one-word "Continue" on 2026-06-26) and included the round's most instructive process event: the first PM + `github-agent` dispatches *both* died simultaneously, producing nothing.

### Three workstreams, the agent-vs-doc split honored

The orchestrator named the division of labor precisely — and the reason the conventions PR is the *main thread's* job, not an agent's:

> **"Three workstreams, respecting the 2-subagent cap:**
> **- PM (product docs + Income Tax v2 spec + source URLs) → PR-B**
> **- github-agent (file the buildable backlog)**
> **- Main thread, me (agent-definition + DESIGN/ARCHITECTURE conventions) → PR-A"**

The split is structural: agent definitions and the design/architecture conventions that govern agents **cannot be agent-written** (an agent editing the rules it runs under is a conflict the experiment forbids), so the main thread authors PR-A by hand; the PM owns `PRODUCT.md` + the spec; `github-agent` owns issue mechanics. This is the contract's ownership map enacted, with the orchestrator taking the one piece no subagent may.

### The double death — both first dispatches died at the 600s watchdog, producing nothing

After the orchestrator kicked off the PM and `github-agent` and began its own DESIGN.md/ARCHITECTURE.md edits, an `API Error: Connection closed mid-response` truncated the session. On resume ("Continue"), the orchestrator assessed and found both subagents dead:

> **"Both subagents died mid-run (the 600s watchdog stall — the known mid-run death failure mode), neither completing."**

It applied the death-recovery protocol correctly: **assess actual state before re-dispatching, so as not to duplicate work.** Its assessment:

> **"Assessment of the double-death: **both agents produced nothing** — github-agent filed zero issues (none created today), and the PM never even created its worktree/branch/PR. Clean slate, no dedup needed. The simultaneous 600s stalls smell like the known environmental agent-death (#140), not task error."**

This is a *fourth* shape in this log's growing catalogue of agent deaths. iteration-0007's were mid-run rate-limit kills (lost uncommitted work, Chapter 128); the 2026-06-19 session's two were "death-on-completion" (work landed, only the report lost, Chapter 133); the bare #140 silent deaths produced no verdict. This pair is **mid-run-with-nothing-produced** — both stalled at the 600s watchdog before any side-effect existed, so recovery was a clean re-dispatch from a verified clean slate, no dedup needed. Notably, the orchestrator diagnosed it by checking side-effects (zero issues created today, no PM branch) rather than reading transcripts — the same verify-the-side-effect reflex from the prior session.

The re-dispatch was not a blind retry; the orchestrator **tightened the prompts to remove the likely stall cause.** The original PM brief had included an INVENTORY `source_url` backfill driven by `WebFetch` (verifying calculator.net URLs live); the orchestrator descoped that on retry:

> **"re-dispatching the two subagents (tightened — PM with no WebFetch since the Income Tax schedule is computable from knowledge, the likely stall cause)"**

The hypothesis: a `WebFetch`-heavy task is the plausible thing to hang for 600s. The per-calculator `source_url` backfill into INVENTORY was deferred to iteration-0008's Open phase rather than forced through a flaky web-fetch path now. Both retried agents returned cleanly — the `github-agent` in ~152s and the PM in ~376s — confirming the descope was the right cut.

### PR #305 — the conventions, authored by the main thread

While the agents re-ran, the orchestrator finished and pushed PR-A itself — a small hand-edit episode worth noting for its honesty about anchor mismatches. Two edits applied cleanly (DESIGN.md, backend.md), but the frontend.md anchor didn't match; the orchestrator re-read and found the actual text differed from what it had assumed ("precision — do **not** force them to 2dp"), and redid the edit against the real lines rather than forcing it. **PR #305** landed encoding, in the agent/design/architecture layer, all four pieces of the feedback so the regen sweep propagates them:

- Time-series charts → real calendar `Mon YYYY` axis (the Auto Loan observation)
- Acronym tooltips from a spec-authored `help` field in the §4 envelope (the DTI fix)
- Per-page "Compare on calculator.net" link via a registry `source_url`
- A rule that specs target the moderate completeness band

Its QA gate came back clean: **"QA on PR #305 → PASS** (CI 5/5 green on the exact head; non-UI visual lane adjudicated to zero real pixel movement — only #87 capture noise; DB N/A)." (QA again flagged the `bin/ci-watch --pr` rc=3 NO-RUN quirk on a plainly-green run — the same #261 watch-item from Chapter 133 — "noting it; not acting unless it recurs.")

### PR #311 — the product layer + the Income Tax v2 spec

The re-dispatched PM opened **PR #311** with two `PRODUCT.md` additions and a full Income Tax v2 spec, all isolated to its worktree (the main checkout stayed clean — the worktree-isolation discipline the PM is required to honor). The two product additions:

1. **"The completeness band" principle** — every calculator targets *moderate* completeness: meaningfully more than the toy version, deliberately short of the source page's maximal everything-config. The heuristic: cover the inputs/modes a typical user actually reaches for plus the common variants; defer the rare/edge/expert configurations. It cites Income Tax as the motivating example — 0007 shipped federal-single-filer-only, judged too thin, and the v2 widening (four filing statuses + standard deduction) *is* the band.
2. **"Compare on calculator.net"** — every calculator page links to its original calculator.net page for side-by-side verification, driven by `source_url` (the user-facing complement to the reference-value tests).

The **Income Tax v2 spec** is the round's most rigorous artifact: all four filing statuses (`single`/`mfj`/`mfs`/`hoh`) each with their 2025 standard deduction and full 2025 bracket schedule pinned as data, ten hand-computed reference rows, worked per-bracket anchors, edge/validation cases, and breakdown-shape assertions. It honors the acronym-tooltip convention from the same harvest — every filing-status acronym (MFJ/MFS/HoH) carries its expansion in the spec's `help` text. The PM also caught two status-specific subtleties the backend "must honor, not hard-code away": MFS diverges from Single only at the top two brackets (35% band $250,525–$375,800), and HoH's 32% band ends at $250,500, $25 below Single's $250,525 — the schedules are *data, one per status*, never four hard-coded polynomials.

### The effective-rate judgment call — surfaced, then decided on principle

The PM did something the experiment prizes: it **surfaced a genuine product decision rather than guessing.** The spec defines `effective_rate` as `total_tax / taxable_income` (continuing the v1 definition), but flagged in the Notes that, with `gross_income` now the primary input, the operator might prefer `effective_rate` over *gross* income — the more intuitive "share of my paycheck" reading (single 50k would read 7.9230% rather than 11.3186%):

> **"I flagged this in the spec Notes rather than guessing — if you want the gross-income denominator, it's a one-line spec change plus re-pinning that one reference column (I have the gross-denominator figures ready)."**

The orchestrator put the choice to the operator, who deferred it to the orchestrator's judgment. The orchestrator **chose taxable income**, with explicit reasoning:

> **"It's the standard definition. "Effective tax rate" conventionally means total tax ÷ *taxable* income — the average rate on what's actually taxed… Benchmark comparability is now a feature. With the "Compare on calculator.net" link, matching the conventional definition our source uses keeps the side-by-side honest."**

Three grounds: it is the standard definition of "effective tax rate"; benchmark-comparability with calculator.net (now a shipped feature via the source link) demands the same denominator the source uses; and consistency with the v1 definition. The intuitive "share of gross" reading is already served because the output shows the full chain (gross → standard deduction → taxable → tax). One refinement baked in with no spec change needed: **label it unambiguously** — "Effective rate (of taxable income)." This is a clean instance of the source-link feature *informing a math decision* — adding a comparison surface created a reason to match the comparator's convention.

### The backlog — seven issues filed via github-agent

All issue mechanics routed through `github-agent` (the all-mechanics-through-the-agent rule from Chapter 132, here honored without a single inline `gh` shortcut). Two dispatches filed seven net-new issues:

- **#306** — time-series chart calendar month/year axis (`frontend`)
- **#307 / #309** — source-link backend (registry `source_url` column + envelope field) / frontend ("Compare on calculator.net" link), #309 cross-linked as depending on #307
- **#308 / #310** — acronym tooltips backend (per-field `help` text in the §4 envelope) / frontend (shared hover-tooltip component), #310 depending on #308
- **#312 / #313** — Income Tax v2 backend / frontend, both carrying the identical 277-line v2 spec + the effective-rate decision note, **explicitly superseding** the v1 issues #250/#260 (closed). Per the append-only/deprecate-never-delete ethos, v1 remains for historical comparability; v2 is "regenerate from this spec, not from prior code."

### The staged-but-unmerged close

The orchestrator's final summary captured the exact state the operator's note demanded — everything prepared, nothing committed to:

> **"Two PRs (await your merge — nothing merged, iteration-0008 not opened): PR #305 — conventions… ✅ QA PASS; PR #311 — product… 🔄 QA gating… Decisions locked: Income Tax v2 = filing status + standard deduction · completeness pass = Income Tax only · effective-rate = taxable income."**

The recommended merge order — **#305 → #311 → the journey PR**, after which iteration-0008 opens pinned at that post-harvest `main` — keeps the conventions, product principle, and journal coherent. At journal time PR #305 was gated PASS, PR #311's QA was in flight, the seven issues were filed, and the historian (this) was firing in the background. The app was still up at localhost:3000.

### What this chapter is evidence of

This is the Harvest phase executed as the experiment prescribes — every one of the operator's three feedback items lands in the durable layer (DESIGN.md/ARCHITECTURE.md/frontend.md/backend.md conventions in #305, the PRODUCT.md principle + a regenerate-from-spec Income Tax v2 in #311), with a backlog of seven buildable issues teed up and *nothing built*. Two process notes stand out. First, the double agent-death was recovered by the now-mature protocol: assess actual side-effects before re-dispatching, then tighten the prompt to remove the suspected cause (the `WebFetch` descope) rather than blindly retry — the death catalogue grew a fourth distinct shape. Second, the effective-rate decision shows the chain working as intended: the PM surfaced the ambiguity rather than guessing, the operator delegated, and the orchestrator decided on a stated principle (standard definition + benchmark-comparability) — a product judgment made deliberately and recorded, not stumbled into. The whole session is a Harvest *staged*: the agents and docs absorbed the feedback, the human holds the merge, and iteration-0008 will pin at the result.
