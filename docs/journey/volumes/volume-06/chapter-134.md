## Chapter 134 — The once-over: the operator clicks through iteration-0007 live and returns three product-feedback items (2026-06-25)

After a long gap (the previous session closed on 2026-06-19; Dependabot bumps #299–#304 merged 2026-06-21 in between), a fresh session opened not with a directive but with a status question. The operator wanted to know whether the work was actually done before declaring it so:

> **"What's the current status of things? Have I already reviewed the last set of calculators that we built? Did we already harvest?"**

The orchestrator checked the real state rather than answering from memory — journey log, iteration logs, recent git/PR activity — and reported everything at rest: working tree clean, no open PRs, `iteration-0007` the last tag, **iteration-0008 not yet opened.** Its summary of where 0007 landed: 10/10 calculators delivered (catalog 14 → 24), evaluated, harvested (PRs #289/#290), journaled (chapters 127–129), and then a follow-on 2026-06-19 orchestration session that shipped the concurrency-cap-of-2 (#294), the all-GitHub-mechanics-through-`github-agent` rule (#297), and other fixes (chapters 130–133). Its read: "The decks are clear," and the natural next move is opening iteration-0008.

### "I want to do a once over before calling it closed for sure"

The operator did not take the offered next step. Instead, the instinct to verify deepened:

> **"Was there any harvesting on the actual calculators? Which calculators did we ship? I want to do a once over before calling it closed for sure"**

This is the experiment's own discipline turned back on the orchestrator by the operator: *was anything fixed in calculator code?* The orchestrator's answer was a clean restatement of rule #1 in practice — **"No — by design."** The 0007 harvest was deliberately shared-layer / agent-level, never per-calculator patches: backend results were clean across all 10, and the operator's three UI nits from the prior round were fixed in shared code/DESIGN.md so they propagate and survive the next regen (money-always-2-decimals → DESIGN.md §2; segmented-pill centering → shared component; data-table overflow → DESIGN.md §4). "Nothing edited an individual `app/calculators/*.rb` as a harvest fix." It also re-surfaced the four PM judgment calls worth the operator's eye — Income Tax (2025 single-filer only), House Affordability (non-iterative), Average Return (geometric-mean headline), Auto Loan (trade-in tax credit) — as the most likely places intent might need confirming.

The operator chose to look live:

> **"Fire up the web UI"**

### A stale-server false-green, caught

Standing the app up was not clean, and the orchestrator's narration of *why* is a small but honest operational note. `bin/serve-headless` reported failure even though a poll to `localhost:3000` returned `200` almost instantly. The orchestrator did not trust the 200:

> **"The 200 my poll saw was a **stale server from a previous session** still bound to port 3000, not this app."**

The root cause was the recently-merged Dependabot bumps (tailwindcss-rails 4.6.0, selenium-webdriver 4.45.0) sitting in `Gemfile.lock` but not installed locally, so boot couldn't materialize them — and a stale Ruby server (PID 46230) from a prior session was squatting on port 3000, giving the false green. The orchestrator ran `bundle install` (114 gems), killed the stale process, booted clean, and only then confirmed a real render (homepage showing all 24 calculator cards, sample pages 200) before handing the operator a table of direct links to the 10 iteration-0007 calculators. This is the same "verify the side-effect, don't trust the surface signal" reflex the previous session drew as a lesson (Chapter 133) — here applied to a server health check rather than an agent death.

### The three product-feedback items

The operator clicked through and returned the substantive feedback that defines this session — three items, each pitched at the product/principle level rather than as a per-page bug:

> **"1. Can the X axis hover over on the "Balance Over Time" chart on Auto Loan be the actual month/year instead of Month number? Can we standardize this for monthly X axis on all charts?**
>
> **2. The Income Tax Calculator is relatively simple, yeah. Can we maybe make it a product decision to find some moderate balance between the simplest possible solution and the most complex possible solution? Also, can we link to the original calculator.net calculator on every page for easy comparison. This is a product completeness piece of feedback - we technically implemented the simplest version of the income tax calculator, but I don't quite think that's enough**
>
> **3. Can we make sure to always have hover over tool tips for acronyms? A good example is - "House Affordability" asks for "DTI" - I have no idea what that is!"**

And, critically, the operator set the session's boundary explicitly — do all the prep, but do not start the build:

> **"This is all of my substantive product feedback for us to take into account - please update as necessary and do all work required to prep for the next iteration. However, we will not start the next iteration in this session - a note"**

This frames the entire session as a **Harvest phase staged but unmerged**: feedback → durable convention/spec/doc changes + a filed backlog, with iteration-0008 deliberately *not* opened.

### Routing the feedback before touching anything

The orchestrator's first move was to name the rule and route each item to the durable layer — not to patch the three calculators:

> **"the experiment's rule is **fix the agent, not the code** — so this feedback becomes durable convention/spec/doc changes plus a filed backlog, not per-calculator patches."**

Its routing:
1. **Chart X-axis → calendar `Mon YYYY`** — a `DESIGN.md §4` + `frontend.md` convention (time-series charts label ticks/crosshair as real month/year from a start date, not a raw month index), so the next iteration's frontend regen propagates it across every time-series chart.
2. **Income Tax depth + "Compare on calculator.net" link** — two parts: a `PRODUCT.md` **completeness principle** (target a moderate band, not the toy version), and a **registry source-link feature** (each calculator carries its calculator.net `source_url` through `INVENTORY` → the `calculators` table → the §4 envelope → a link in the page chrome).
3. **Acronym tooltips (DTI!)** — a `DESIGN.md §2` + `frontend.md` convention: any acronym renders with a hover tooltip, the expansion text supplied **per-field in the §4 envelope** so the knowledge lives with the calculator (authored in the spec), not in a separate frontend glossary; backend spec-authoring (`ARCHITECTURE.md §3.2`) gains a "define every acronym" rule.

### Two decisions surfaced as a question, not guessed

Two of the three needed a genuine product steer before the PM could draft specs, and the orchestrator surfaced them as an explicit `AskUserQuestion` rather than presuming. The first asked how far to widen Income Tax (options ranged from "Filing status + deductions" through "+ Payroll & take-home," "+ State & credits," to "Let the PM propose"); the second asked how broad the completeness pass should be (Income Tax only / audit the iter-0007 ten / audit all 24). The operator's answers:

> **"For Income Tax… = "Filing status + deductions", … How broad should this completeness pass be… = "Income Tax only now"."**

The orchestrator locked them precisely: **Income Tax v2 = filing status + standard deduction**, and **completeness pass scope = Income Tax only now** — "principle governs future builds/regens, no retroactive audit." This is a deliberate scoping of the experiment's cost: the completeness *principle* becomes general and durable, but it is *not* retroactively applied to the existing 24 — only the one calculator the operator judged too thin gets re-spec'd now. The general rule is cheap to write; the retroactive audit is the sizable PM job, and the operator declined it.

### What this chapter is evidence of

This is the Evaluate phase of the iteration loop done live and unhurried — the operator standing the app up and clicking through, returning feedback pitched deliberately at the principle level ("make it a product decision," "standardize this for all charts," "always have… tooltips for acronyms"). Every item is a candidate for the durable layer, and the orchestrator routed all three there without proposing a single per-calculator patch. The two product decisions were elicited by an explicit question rather than guessed — the same "surface the choice, don't presume" discipline that recurs throughout this log. The actual harvest execution — the conventions PR, the product PR, the backlog, and a notable double agent-death — is the next chapter's material.
