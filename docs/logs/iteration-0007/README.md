# Iteration 0007

**Status:** closed — **after TWO Evaluate→Harvest rounds** (see "Two rounds" below)
**Opened:** 2026-06-16
**Closed:** **2026-08-07** (the r2 close — the real one). ⚠️ This log previously read
`Closed: 2026-06-16`; that is the **r1** close, and it was **premature** — a second
Evaluate→Harvest round (**r2**) ran on 2026-06-25/26 and its harvest merged 2026-08-07,
*after* the date the log claimed the iteration had ended. The r1 close date is preserved
in the body (§ "Close — r1 (2026-06-16)"); the corrected end-of-iteration date is above.
**Pinned agent SHA:** iteration-0007 is pinned at the **post-harvest `main` SHA** `e85c47c` (HEAD at
open). The main thread applied the `iteration-0007` git tag at that SHA; the PM does not create the tag.
This log references "iteration-0007, pinned at post-harvest `main` (`e85c47c`)."
**Tag:** `iteration-0007` (applied by the main thread at `e85c47c`)
**Calculators:** **10 new builds, n = 10** (≈20 build PRs) — Auto Loan (BE/FE), Sales Tax (BE/FE),
Pythagorean Theorem (BE/FE), Discount (BE/FE), VAT (BE/FE), Personal Loan (BE/FE), Average Return (BE/FE),
ROI (BE/FE), House Affordability (BE/FE), Income Tax (BE/FE). **Regen set: EMPTY** (rationale below).

**Headline outcome:** **10/10 calculators shipped (both layers), catalog 14 → 24** — a PROCESS stress test
at 2× fan-out. All 20 build PRs (10 BE + 10 FE) gated PASS and merged; the registry ingest upserted 24 with
**drift = 0**. Four of the five up-front predictions HELD; **P4 (no fixture↔page-coupling surprise) was
FALSIFIED** — the shared `test/fixtures/calculators.yml` caused a merge-conflict cascade across all 7 frontend
merges (filed #286). One new **process** finding (not a results miss): ~7 concurrent heavy frontend agents
tripped a transient server-side API rate-limit and died mid-run; recovery was clean with **zero rebuilds**,
and the lesson was harvested as a **concurrency cap (~3–4)**. Backend results were clean; the operator's UI
review surfaced **3 nits** (money-2dp, mode-picker pill vertical-centering, table cell overflow), all fixed as
shared-layer/agent harvest, not per-calculator patches.

## Two rounds — read this first

Iteration-0007 ran the six-phase lifecycle's **Evaluate→Harvest pair twice**. Anyone reading this log
cold should hold that shape in mind: the long body below is **round 1**; the **r2 addendum at the very
bottom** is round 2, and it is r2 — not r1 — that produced the agent set iteration-0008 pins at.

| Round | Evaluate | Harvest | Journal | Close | What it produced |
|---|---|---|---|---|---|
| **r1** | 2026-06-16 — the build-phase review of the 10 new builds (QA gates + the operator's UI pass) | #284, #285, #287, #288, #289 (+#286 filed) — merged 2026-06-16 | ch. 127–129 (PR #291) | **2026-06-16** (recorded below as "Close — r1") | 3 shared-layer UI fixes, the concurrency cap, `ci-monitor` deprecation, the P4 falsification |
| **r2** | **2026-06-25** — the operator stands the app up headlessly and hand-reviews **all ten** 0007 calculators live | **#305, #311, #314** — opened 2026-06-26, merged **2026-08-07** (+ 7 issues filed: #306–#310, #312, #313) | ch. 134–135 (PR #314) | **2026-08-07** (this addendum) | 4 durable conventions, the `PRODUCT.md` **completeness band**, the Income Tax **v2** spec, and the #306–#310 infra backlog iteration-0008 pins behind |

**Why the record was wrong:** r1's close was declared on the same day the build finished, before the
operator's own hands-on review had happened. When that review landed nine days later it produced real
product-level feedback and a real harvest — so the iteration was, in substance, still open. This
addendum corrects the date rather than back-dating the evidence. See
"**Process observation — a closed iteration reopened**" at the end for the lifecycle question this raises.

---

## What this iteration is — a PROCESS STRESS TEST, not a results round

Iteration 0006 (8 → 14 calculators) proved the **results** are solid: the operator hand-reviewed all six
new builds and returned **"no notes,"** and *every* failure that round was **coordination-at-fan-out**, all
fixed in the harvest (the registry-count collision → derived count #202; the fixture↔page coupling #205; the
agent-def conventions #216; the spec-authoring rounding-boundary rule in `ARCHITECTURE.md §3.2`).

Iteration 0007 therefore **holds RESULTS as the controlled variable and doubles the fan-out to stress-test
the harvested machinery at scale** — **10 calculators (~20 build PRs)**, 2× the 0006 fan-out. The calculator
set is chosen to be *unremarkable on results* (every one reuses a proven primitive — loan core, solve-for-X,
percentage single-formula, geometry, stat-list — except the one new bracket/piecewise primitive in Income
Tax), so that anything that goes wrong is **coordination**, not new math. The point of the round is
**legibility**: if the 0006 harvest "took," the doubled fan-out runs clean; any recurrence is a clean
falsification of a specific harvested fix.

## Predictions (written in up front — falsifiable)

Per the round's purpose, the predictions are stated **before** the build so any recurrence is a clean
falsification, not a post-hoc rationalization. The 0006 harvest predicts each of these holds at 2× fan-out:

| # | Prediction | What would falsify it | Harvest it tests |
|---|---|---|---|
| P1 | **No registry-count collision** across the 10 parallel builds — no build edits a shared "how many are built" constant. | Two builds conflict on a registry/expected-count assertion, or a build hand-bumps a count. | #202 (derived built-calculator count) |
| P2 | **INVENTORY backfilled at Open** — all 10 calculators carry slug + description **before** the builds start (so the registry ingest can project each row the moment its slug resolves). | A build agent has to author/guess an INVENTORY slug or description mid-build. | The Open-phase backfill discipline (done in this PR). |
| P3 | **Derived calculator count holds** — the registry count moves **14 → 24 only on completion**, with **no per-build count bumps** along the way. | The count is edited per-build, or a mid-iteration count assertion drifts. | #202 (count is derived, not hand-maintained) |
| P4 | **No fixture↔page coupling surprise** — FE builds don't trip on missing shared fixtures / derived-helper scaffolding. | An FE build blocks/fails because shared test scaffolding wasn't pre-staged (the #205 failure mode recurs). | #205 (the fixture↔page coupling, pre-scaffolded) |
| P5 | **No cross-seam edits** — no build agent writes another layer's turf (a backend touching ERB/CSS/JS, a frontend touching calculator math/routes — the #199 / #98 worktree-isolation + seam-discipline failure mode). | A backend PR diff touches `app/views`/`app/assets`/`app/javascript`; a frontend PR diff touches `app/calculators`/`routes.rb`/a model. | The seam-discipline + worktree-isolation conventions (#98/#199, `backend.md`/`frontend.md`). |

### Consistency metrics to track this round

Beyond the pass/fail predictions, track two **rates** (these are the legibility instruments — they quantify
whether 2× fan-out degrades the per-PR clean-through rate vs. 0006's 6/6):

- **First-pass gate rate** — the fraction of build PRs that pass the `quality-assurance-agent` gate on the
  **first** attempt (no FAIL → fix → re-gate cycle). 0006 was effectively 12/12 PASS; the question is whether
  20 PRs at 2× hold the rate.
- **Notes / no-notes per calculator** — for each of the 10, did the operator's evaluation return clean
  ("no notes") or surface notes? 0006 was **6/6 clean**. A drop here on a results-controlled round would point
  at fan-out scale, not at the calculators.

_(Both metrics are filled in per-calculator below and summarized at close.)_

## Scope (operator-confirmed 2026-06-15)

### New-build set (10) and build sequence

| # | Calculator | Slug | Cat / Cx | Reuses primitive | Build order |
|---|---|---|---|---|---|
| 1 | **Auto Loan** | `auto_loan` | Financial c3 | loan.rb (loan core + schedule) | **FIRST** |
| 2 | **Sales Tax** | `sales_tax` | Financial c2 | ohms_law.rb (solve-for-X) | parallel |
| 3 | **Pythagorean Theorem** | `pythagorean_theorem` | Math c2 | right_triangle.rb (subset) + inline SVG figure | parallel |
| 4 | **Discount** | `discount` | Financial c2 | percentage.rb (single-formula multi-input) | parallel |
| 5 | **VAT** | `vat` | Financial c2 | structural twin of Sales Tax | parallel (twin-probe) |
| 6 | **Personal Loan** | `personal_loan` | Financial c3 | loan.rb (loan-core skin) | after Auto Loan |
| 7 | **Average Return** | `average_return` | Financial c3 | stat-list (mean/std-dev) → financial geometric mean | parallel |
| 8 | **ROI** | `roi` | Financial c2 | percentage.rb single-formula (+ optional CAGR) | parallel |
| 9 | **House Affordability** | `house_affordability` | Financial c4 | mortgage.rb run in reverse (DTI → max loan) | after Auto Loan |
| 10 | **Income Tax** | `income_tax` | Financial c5 | **NEW primitive: bracket/piecewise math** | parallel |

**Sequence rationale (operator):** **Auto Loan first** — it re-establishes the **loan primitive at this
iteration's pinned agents** (loan core + amortization schedule), which **Personal Loan** (loan-core skin) and
**House Affordability** (the mortgage/loan amortization identity solved in reverse) then inherit rather than
re-derive. **Sales Tax ↔ VAT** are a deliberate **twin convergence-probe** — identical solve-for-X structure
(before/tax/after ↔ net/VAT/gross, three modes), differing only in domain labels; building both this round
tests whether parallel specs yield parallel structure. The rest (Pythagorean, Discount, Average Return, ROI,
Income Tax) are independent **parallel** builds. For **every** calculator BOTH layers ship — **backend before
frontend** (the FE codes against the BE's §4 envelope).

### Regen set: EMPTY — and why

**No regeneration sweep this iteration.** This is a deliberate, reasoned call, not an omission:

- **The 10 new builds are built on the post-harvest agents**, so they **natively inherit** the iteration-0006
  harvest conventions — there is nothing for a separate sweep to *propagate* that the new builds don't already
  exercise. Specifically:
  - **Every chart uses TradingView lightweight-charts (incl. `Histogram` for bars)** — never a hand-rolled
    SVG/`<canvas>` chart (`DESIGN.md §4`, harvested from the admin-stats round: PRs around #227/#228 + the
    `DESIGN.md`/`frontend.md` chart-and-codetag rule). The **chart-bearing new builds this round** (Auto Loan,
    Personal Loan, Income Tax's tabular breakdown, House Affordability's stat grid) using the house library is
    itself the **propagation confirmation** — so a separate regen sweep would carry no new signal.
  - **Raw echoed quantitative data renders in monospace `<code>`/`font-mono`** (`DESIGN.md §2`, same harvest)
    — the new builds inherit it.
  - The **in-`Base` numeric guard** (#109/#110), the **shared `.stat-grid` component** (#143), the
    **mode-picker rule** (`DESIGN.md §4`), and the **derived built-count** (#202) all live in shared code /
    conventions and apply to every build automatically.
- A regen sweep's sole purpose is **propagating a harvest** across the existing catalog. Here the harvest
  reaches the new builds by construction (they're built on the post-harvest agents), and reaches the 14 priors
  via shared base/component/convention already on `main`. With propagation already complete, a sweep would
  **re-emit identical code** — no new signal. The iteration's evidence is therefore the **10 new builds and the
  five predictions above** (does the harvested coordination machinery hold at 2× fan-out).

> **PM note.** After full-context ingestion (CLAUDE.md, ARCHITECTURE.md, DESIGN.md §2/§4, the iteration
> 0001–0006 logs, the git log confirming the admin-stats chart/code-tag harvest, the #202 derived-count and
> #205 fixture-scaffolding landings, and the #214 coming-soon fallback all on `main` at `e85c47c`), the PM
> **concurs** with the empty regen set. The chart-bearing new builds reaching for TradingView unprompted is
> the cleanest available confirmation the chart harvest took; a full sweep would add cost without signal.

### Pin

Iteration-0007 is pinned at **`e85c47c`** — `main` HEAD at open, carrying the **complete** post-iteration-0006
harvest plus the admin-stats build and its harvest (TradingView-for-all-charts + `<code>` for raw echoed data,
`DESIGN.md §2/§4` + `frontend.md`) and the follow-up landings the prior round filed:

- **#213** — optional numeric fields harden: a blank string on a defaulted numeric coerces to its default
  rather than crashing `compute` (merged — relevant to this round's many `default: 0` optional fields:
  Auto Loan trade-in/fees, House Affordability tax/ins/HOA).
- **#214** — a registry-active calculator with no frontend page no longer 500s (MissingTemplate) — a generic
  coming-soon fallback (merged, BE + FE) — so a backend that lands before its frontend renders gracefully.
- **#224 / #229 / #231** — CI-watch SHA resolution, a sign-in system-test flake, and `merge-cleanup` cwd
  safety (test/tooling robustness, ride in the pin).

The main thread applies the `iteration-0007` tag at `e85c47c`; the PM does not create the tag.

## The harvest this iteration builds on (iteration-0006 → 0007)

The agent set iteration-0007 pins at carries the iteration-0006 harvest **and** the admin-stats-round harvest
that landed after 0006 closed. The build-facing deltas since the iteration-0006 pin (`7f15521`):

| Change | Layer | PR(s) | What |
|---|---|---|---|
| **TradingView for ALL charts + `<code>` for raw echoed data** | frontend | ~#227 / #228 (+ `DESIGN.md §2/§4` + `frontend.md`) | Every chart anywhere (calculator **and** dashboard) uses TradingView lightweight-charts (incl. `Histogram` for bars) — **never** a hand-rolled SVG/`<canvas>` chart; raw echoed quantitative data renders in monospace `<code>`. Shapes every chart-bearing build this round. |
| **Spec-authoring rounding-boundary rule** | process (spec authoring) | `ARCHITECTURE.md §3.2` (iter-0006 close) | Reference values must be **unambiguous under the rounding rule** — never on a `ceil`/`floor`/`round` razor's edge. **Applied this round:** Income Tax's marginal-rate references all sit *inside* a bracket; the loan/auto-loan term anchors avoid whole-month boundaries. |
| **Agent-def conventions** | backend + frontend | #216 (iter-0006 harvest) | The `backend.md` / `frontend.md` refinements the 0006 build surfaced. |
| **Derived built-calculator count** | backend (test infra) | #202 | Adding a calculator no longer edits a shared expected-count — removes the fan-out collision point (P1/P3 test this at 2×). |
| **Optional-numeric hardening + coming-soon fallback** | backend / frontend | #213 / #214 | Blank-on-defaulted-numeric → default (not crash); a built backend with no FE page renders a coming-soon fallback (BE-before-FE is graceful). |

These ride along into this iteration's 10 builds; the round tests whether they hold at doubled fan-out.

## The experimental questions this iteration carries

The round is a **process** stress test, so the questions are about **coordination at scale**, not new math:

1. **Does the harvested fan-out machinery hold at 2×?** The five predictions (P1–P5) are the falsifiable form
   of this. 0006 fixed every coordination failure it hit at 6-wide; 0007 asks whether 10-wide re-surfaces any.
2. **Does the Sales Tax ↔ VAT twin converge?** Two near-identical solve-for-X specs built by independent agent
   invocations — do they produce **parallel structure** (same mode set, same segmented-control presentation,
   same output shape)? A divergence between structural twins would be a legibility signal about determinism.
3. **Does the loan primitive re-transfer cleanly at this pin?** Auto Loan re-establishes the loan core; Personal
   Loan (skin) and House Affordability (reverse) inherit it. Does building Auto Loan first let the other two
   reuse the amortized core + schedule rather than re-deriving?
4. **Does the one new primitive (Income Tax bracket/piecewise math) land cleanly from a rigorous spec?** This is
   the *only* new-ground calculator. Its spec pins a concrete, citable 2024 single-filer bracket schedule and
   exact reference tax for incomes spanning multiple brackets — so a miss here is unambiguously about the new
   primitive, not spec ambiguity.

## The ten specs

Each calculator's `spec:v1` body is authored as a **separate file** under
`docs/logs/iteration-0007/specs/<slug>.md` so the `github-agent` can consume each verbatim into the two GitHub
issues it files per calculator (a `backend` issue and a `frontend` issue, **both carrying the identical full
spec body**, title = the calculator name, layer conveyed by the `backend`/`frontend` label). Each spec follows
the `spec:v1` format (`ARCHITECTURE.md §3.2`), calibrated against issue #192 (Right Triangle).

| Calculator | Spec file | Modes / shape |
|---|---|---|
| Auto Loan | `specs/auto_loan.md` | single-mode; loan core + trade-in/down/tax/fees + amortization schedule |
| Sales Tax | `specs/sales_tax.md` | solve-for-X: **after** / **before** / **rate** (segmented) — **twin of VAT** |
| Pythagorean Theorem | `specs/pythagorean_theorem.md` | solve-from: **hypotenuse** / **leg** (option list) + inline SVG figure |
| Discount | `specs/discount.md` | **percent off** / **fixed amount off** (option list) |
| VAT | `specs/vat.md` | solve-for-X: **gross** / **net** / **rate** (segmented) — **twin of Sales Tax** |
| Personal Loan | `specs/personal_loan.md` | single-mode loan-core skin + schedule |
| Average Return | `specs/average_return.md` | variable-length list input; arithmetic + geometric mean |
| ROI | `specs/roi.md` | single-formula + optional annualized (CAGR) |
| House Affordability | `specs/house_affordability.md` | single-mode; mortgage amortization inverted via DTI |
| Income Tax | `specs/income_tax.md` | **NEW primitive** — progressive bracket sum + per-bracket breakdown table |

**Every reference-value table in these specs was PM-computed deterministically** (standard formulas at full
`BigDecimal`/`Decimal` precision — amortized-payment + schedule reconciliation for the loan family, the
solve-for-X algebra for the tax twins, real-precision n-th roots for the geometric mean and CAGR, the pinned
2024 single-filer bracket sum for Income Tax) — **not** taken on a web model's word. Where calculator.net's
page only described the formula (Average Return, House Affordability's iterative tax loop, the full Income Tax
page), the calculator was **scoped to a clean, deterministic primitive** and the figures computed from the
stated formula; where the Source showed worked numbers (Sales Tax $106, VAT coffee $11, Discount $40.50, ROI
40%) they were matched. The backend agents reproduce these verbatim (they have no web access).

**PM judgment calls flagged for operator review** (so any disagreement is caught before the build):

- **Income Tax — bracket schedule chosen (re-pinned to 2025 by operator).** The full calculator.net income-tax
  page (filing status, dependents, many income types, credits) is out of scope; this build implements the
  **core progressive-bracket primitive against a single pinned schedule: the 2025 US federal single-filer
  ordinary-income brackets** (IRS Rev. Proc. 2024-40, tax year 2025 — 10/12/22/24/32/35/37% at the
  11,925 / 48,475 / 103,350 / 197,300 / 250,525 / 626,350 thresholds), **stated in the spec**. Reference tax
  pinned for incomes spanning multiple brackets (10k → $1,000; 50k → $5,914; 100k → $16,914; 250k → $57,063;
  700k → $216,020.25), plus effective and marginal rates, with marginal references chosen **inside** brackets
  (never at an edge). _Note: under the 2025 schedule the $250,000 worked anchor's last dollar lands in
  bracket 5 (197,300–250,525), so its marginal rate is **32%** and the breakdown spans **5** brackets (under
  the prior 2024 pin it was 35% / 6 brackets)._ The operator chose 2025 (superseding the 2024 pin landed in
  #240); year/filing status remains the one knob to change.
- **House Affordability — non-iterative model.** Property tax / insurance / HOA are taken as **fixed monthly
  dollar figures** (as the Source's own worked example does for insurance/HOA), so max home price computes in
  **one pass** — no iterating tax-as-%-of-the-unknown-price. Chosen for deterministic reference values; flagged
  in case the operator wants the iterative percent-of-price variant later.
- **Average Return — geometric mean is the headline.** The Source's page is vague on formula; this build reports
  both the arithmetic average and the **geometric (compounded) average** of a return series, the financially
  correct multi-period average. Returns are bounded **≥ −100%** (a growth factor can't go negative).
- **Auto Loan — trade-in tax credit.** Sales tax is levied on price **net of trade-in** (the common trade-in
  tax credit), and tax/fees roll into the financed amount; this is one of several state-dependent treatments
  calculator.net offers — the spec pins this single deterministic one.

## Per-calculator notes

Per-calculator build + feedback notes accrue in `docs/logs/iteration-0007/<calculator>.md` as each build lands
(these files are disjoint, fan-out-safe). They record what each agent produced, what was right, what missed,
the agent-definition change a miss suggests, and the two consistency metrics (first-pass gate? notes/no-notes?).
At close they record the build PRs per layer.

| Calculator | Backend issue → PR | Frontend issue → PR |
|---|---|---|
| Auto Loan | #241 → #266 | #251 → #280 |
| Sales Tax | #242 → #268 | #252 → #281 |
| Pythagorean Theorem | #243 → #262 | #253 → #272 |
| Discount | #244 → #263 | #254 → #271 |
| VAT | #245 → #264 | #255 → #282 |
| Personal Loan | #246 → #275 | #256 → #277 |
| Average Return | #247 → #270 | #257 → #273 |
| ROI | #248 → #265 | #258 → #278 |
| House Affordability | #249 → #276 | #259 → #279 |
| Income Tax | #250 → #274 | #260 → #283 |

The `github-agent` filed all 20 issues (#241–#260) — two per calculator (`backend` + `frontend`), both carrying
the identical full `spec:v1` body. The dedupe scan found **no prior issues** for any of the ten. All 20 issues
are **CLOSED** by their merged build PRs above.

---

## Close — r1 (2026-06-16)

> **Preserved as written, and now superseded.** This was the iteration's **first** close, declared
> 2026-06-16 the same day the build phase finished. It is accurate about round 1 — the prediction
> scorecard, the metrics, and the r1 harvest below all stand — but it was **premature as an
> end-of-iteration close**: the operator's own hands-on evaluation had not yet happened. That review
> ran 2026-06-25 and produced **round 2**, recorded in the **r2 addendum** at the end of this file.
> Where this section says "iteration-0008 opens pinned at the post-harvest `main`," read it as
> **post-*r2*-harvest** `main` — the r2 conventions (#305) and product harvest (#311) landed after
> this section was written.

### Prediction scorecard — 4/5 HELD, P4 FALSIFIED

The five predictions were written in **at Open** so any recurrence is a clean falsification, not a post-hoc
rationalization. Adjudicated against the delivered builds:

| # | Prediction | Verdict | Evidence |
|---|---|---|---|
| **P1** | No registry-count collision across the 10 parallel builds — no build edits a shared "how many are built" constant. | **HELD** | No build touched a built-calculator count; #202's derived count absorbed all 10 additions without a per-build edit or a merge conflict on a count assertion. |
| **P2** | INVENTORY backfilled at Open — all 10 carry slug + description **before** the builds start. | **HELD** | All ten slugs + descriptions were authored into `INVENTORY.md` at open; no build agent had to author or guess an inventory slug/description mid-build. |
| **P3** | Derived calculator count holds — moves **14 → 24 only on completion**, with **no per-build bumps**. | **HELD (exactly)** | At close the registry ingest reported **upserted = 24, drift = 0** — the count moved 14 → 24 with no intermediate per-build assertion drift. |
| **P4** | No fixture↔page-coupling surprise — FE builds don't trip on missing shared fixtures / derived scaffolding. | **FALSIFIED** | The shared `test/fixtures/calculators.yml` caused a **merge-conflict cascade across all 7 frontend merges** — each FE PR appended its own fixture row to the same file, so every merge after the first conflicted and had to be rebased. The #205 fix pre-staged scaffolding but did **not** anticipate a *shared append-target* file under 2× fan-out. **Filed as #286.** |
| **P5** | No cross-seam edits — no build agent writes another layer's turf. | **HELD** | No backend PR diff touched `app/views`/`app/assets`/`app/javascript`; no frontend PR touched `app/calculators`/`routes.rb`/a model. The new **`array_attribute`** primitive (Average Return's list input) landed entirely in the **backend's `Base`/controller turf** — a clean seam-respecting addition, not a cross-seam edit. |

**The one falsification is itself the round's payoff.** P4 is exactly the kind of coordination failure a 2×
process stress test exists to surface: the #205 harvest hardened *pre-scaffolding* of shared fixtures but
missed that a **shared append-target file** turns N parallel FE merges into N−1 guaranteed rebase conflicts.
That it surfaced *only* at doubled fan-out (it didn't bite 0006's 6-wide round on the same file) confirms the
doubled fan-out did its job as a legibility instrument. The fix is tracked in **#286** (derive the per-calculator
fixture rows, or otherwise remove the shared append-target, so FE merges stop colliding).

### New process finding — concurrency rate-limit (recovered with zero rebuilds)

Beyond the predictions, the round surfaced a **new infrastructure-level coordination limit**: dispatching ~7
concurrent heavy frontend agents **simultaneously** tripped a transient **server-side API rate-limit that
killed them all mid-run**. Recovery was **clean with ZERO rebuilds** — the orchestrator salvaged the
committed-and-uncommitted work in the dead agents' worktrees and CI-validated each, rather than re-dispatching
the builds from scratch. The lesson was harvested as a **concurrency cap (~3–4 heavy agents at a time) — wave
the fan-out**, encoded into `CLAUDE.md` (Orchestration → "Concurrency cap"). This is a **process** finding, not
a results miss — no calculator was wrong, and nothing had to be rebuilt — but it is the sharpest single learning
of the round: the harvested machinery scales on correctness, but the *orchestration* has a concurrency ceiling
the 2× round found.

### Consistency metrics

- **First-pass gate rate — effectively 10/10 BE + 10/10 FE.** Every calculator's backend and frontend passed
  its `quality-assurance-agent` gate; the frontend PRs recovered from the rate-limit deaths passed CI + QA once
  re-dispatched/salvaged. The doubled fan-out did **not** degrade the per-PR clean-through rate vs. 0006's 6/6
  — the gate held at 2×. (One post-gate-push re-gate was needed on #272 — the SHA the gate saw went stale after
  a fix push — which itself drove the "re-gate after a post-gate push" rule into `CLAUDE.md`.)
- **Notes / no-notes — backend clean; FE 3 shared-layer nits.** Backend results were **clean across all 10**
  (reference values reproduced; the one new bracket/piecewise primitive in Income Tax landed correctly from its
  rigorous spec; the Sales Tax ↔ VAT twin converged to parallel structure; the loan core re-transferred cleanly
  Auto Loan → Personal Loan → House Affordability). The operator's UI review surfaced **3 nits**, all
  **shared-layer / agent-level**, none a per-calculator correctness miss: (1) money values not always rendered
  to 2 decimals; (2) the mode-picker segmented pills not vertically centered when a label wrapped; (3) data-table
  cells overflowing on narrow viewports. **All three were fixed as shared-component / `DESIGN.md` / agent harvest
  — not per-calculator patches** — so they propagate to every calculator and survive the next regen sweep.

### Build PRs (all merged)

All 20 build PRs merged green (issue → PR table above). Backends landed before their frontends per the lifecycle
(a calculator's FE codes against its BE's §4 envelope). BE PR range #262–#276; FE PR range #271–#283.

### Harvest manifest (all merged)

The Evaluate phase's findings were applied as agent / design / process harvest — **fix the agent, not the code**
— and landed on `main` before close (this is the agent set iteration-0008 will pin at):

| PR / issue | Layer | What |
|---|---|---|
| **#284** | frontend (`DESIGN.md §2`) | **Money → always 2 decimals (cents)** rule — every displayed monetary figure renders with exactly two decimal places; addresses UI nit (1). |
| **#285** | frontend (shared component) | **Equal-height, vertically-centered segmented-control pills** — a wrapping two-line mode label is vertically centered, not top-pinned; addresses UI nit (2). |
| **#287** | process (`CLAUDE.md`) | **Concurrency cap (~3–4) + post-gate re-gate + `ci-monitor` deprecation + the `array_attribute` pattern** — the concurrency-rate-limit harvest, the stale-gated-SHA re-gate rule (#272), QA proving out so `ci-monitor` is deprecated as the CI watcher, and documenting the registration-free list-input primitive. |
| **#288** | frontend | **Right Triangle SVG clip propagation** — the figure's leg-label is kept inside the viewBox / leg for large legs (figure-clipping fix swept to the geometry calculators). |
| **#289** | frontend (`DESIGN.md §4`) | **Data-table no-overflow + the §4 segmented-vs-list mode-picker decision** — numeric/money/range cells never wrap mid-value and tables scroll rather than clip on narrow viewports (addresses UI nit (3)); plus the harvest settling when a segmented control vs. an option list is used. |
| **#286** | process (filed, not yet fixed) | **Fixture-cascade issue** — the shared `test/fixtures/calculators.yml` append-target that conflicted across the 7 FE merges (the P4 falsification); filed for a future fix. |

**`ci-monitor` is now deprecated** (kept, not deleted, per the deprecate-never-delete ethos): the
`quality-assurance-agent` proved out across all ~26 of this round's PRs with zero deaths, so its CI facet is the
sole CI gate (`CLAUDE.md` → "The pre-merge gate", adoption note #169).

### What iteration-0008 inherits

This close updates `docs/INVENTORY.md` (catalog **14 → 24**; the 10 new calculators floated into the
completed block in BE-PR-ascending ship order, each with its build-time slug + description) and records the
harvest above. iteration-0008 opens pinned at the post-harvest `main`; its regen sweep — if any — is what would
propagate the #284/#285/#289 shared-layer fixes across the 14 priors that predate them, and the open **#286**
fixture-cascade fix should land before the next 2×-scale fan-out.

_(This paragraph was written at the r1 close. It is still true as far as it goes — but the set
iteration-0008 inherits grew substantially in **r2**, below. Continue reading.)_

---

# Addendum — r2: the second Evaluate→Harvest round

**Round:** r2 (the iteration's second Evaluate→Harvest pair)
**Evaluate:** 2026-06-25 — the operator's live hand-review of all ten 0007 calculators
**Harvest authored:** 2026-06-26 (PRs #305 / #311 / #314 opened) — then **stale through a project
pause** until **2026-08-07**, when all three were re-gated and merged
**Journal:** chapters 134–135 (PR #314)
**Close:** **2026-08-07** — this addendum. iteration-0007 is now closed for real.

## What triggered r2

Nine days after the r1 close, a fresh session opened not with a build directive but with the
operator asking whether the round was actually done — *"Have I already reviewed the last set of
calculators that we built? Did we already harvest?"* — and then declining the offered next step:

> **"I want to do a once over before calling it closed for sure."**

The app was stood up headlessly (`bin/serve-headless`; a stale port-3000 server from a prior session
produced a false-green `200` that was caught and killed before the review began), and the operator
clicked through **all ten** iteration-0007 calculators live. That review is the Evaluate phase r1 had
declared complete without it — and it did not come back clean.

## The three operator feedback items

The operator returned **three numbered items**, all pitched deliberately at the *product/principle*
level rather than as per-page bugs. Recorded here in substance (verbatim in ch. 134):

1. **Time-series chart X-axis.** The Auto Loan "Balance Over Time" chart labels its X-axis with a raw
   month **number** (1, 2, 3 …). It should show the **actual month/year** — and the ask was explicitly
   to **standardize this across all monthly-axis charts**, not fix one page.
2. **Income Tax is too thin — make the depth a *product decision*.** "The Income Tax Calculator is
   relatively simple, yeah" — we had technically implemented the *simplest possible* version, and that
   isn't enough. The ask: make it a product decision to find a **moderate balance between the simplest
   possible solution and the most complex possible solution.** ***Bundled in the same item:*** **link to
   the original calculator.net calculator on every page** for easy side-by-side comparison.
3. **Acronym tooltips.** "Always have hover-over tooltips for acronyms" — the worked example being
   House Affordability asking for **"DTI"** with no explanation of what that is.

> **Note on the count.** Three *numbered* items, **four** substantive asks — item 2 bundled the
> completeness question **and** the compare-link request. That is why the harvest below encodes four
> conventions, not three, and why the backlog splits into three feature lines (chart axis, source link,
> tooltips) plus one spec rewrite.

**Two of the asks needed a genuine product steer, and were surfaced as an explicit question rather than
guessed** (the discipline this project prizes). The operator's answers, locked:

- **Income Tax v2 scope = "filing status + deductions"** (not payroll/take-home, not state/credits).
- **Completeness-pass scope = "Income Tax only now"** — the *principle* becomes general and durable, but
  there is **no retroactive completeness audit** of the existing 24. The general rule is cheap; the
  retroactive audit is a large PM job the operator declined.

A third judgment call was surfaced by the PM inside the v2 spec and decided on principle: **`effective_rate`
denominator = *taxable* income**, not gross (grounds: it is the standard definition of "effective tax rate";
benchmark-comparability with calculator.net now matters *because* the compare-link is shipping; and it
continues the v1 definition). The label must read unambiguously — "Effective rate (of taxable income)."

## r2 harvest manifest — the three merged PRs

Every item was routed to the **durable layer** — *fix the agent, not the code*. **Zero per-calculator
patches were made**, exactly as in r1.

| PR | Layer | Opened | Merged | What |
|---|---|---|---|---|
| **#305** | conventions — `DESIGN.md`, `ARCHITECTURE.md`, `.claude/agents/frontend.md`, `.claude/agents/backend.md` | 2026-06-26 | 2026-08-07 | All four conventions: (a) **time-series charts label a real calendar `Mon YYYY` axis** (ticks + crosshair) derived from a start date, never a bare month index (`DESIGN.md §4` + `frontend.md`); (b) **acronym/jargon tooltips** driven by a new **per-field `help` value in the §4 envelope**, spec-authored so the knowledge lives with the calculator rather than in a frontend glossary (`DESIGN.md §2/§4`, `ARCHITECTURE.md §3.2/§4`, both agent defs); (c) **"Compare on calculator.net"** on every page via a registry **`source_url`** (`INVENTORY` → ingest → §4 envelope → link; a `nil` value renders no link — never fabricate one); (d) **specs target the moderate completeness band** (`ARCHITECTURE.md §3.2`). Authored by the **main thread**, not an agent — an agent may not edit the rules it runs under. |
| **#311** | product — `docs/PRODUCT.md`, `docs/logs/income-tax-v2-spec.md` | 2026-06-26 | 2026-08-07 | Two `PRODUCT.md` additions — the **completeness band** principle (moderate, not minimal, not maximal; with the where-the-line-sits heuristic and Income Tax as the motivating example) and **"Every calculator links back to its source."** Plus the full **Income Tax v2 `spec:v1`** (`docs/logs/income-tax-v2-spec.md`): four filing statuses (`single`/`mfj`/`mfs`/`hoh`) with 2025 standard deductions and all four 2025 bracket schedules pinned **as data**, ten PM-computed reference rows, three worked per-bracket anchors, edge/validation cases, and breakdown-shape assertions. |
| **#314** | journey — `docs/journey/` | 2026-06-26 | 2026-08-07 | Chapters **134** (the once-over and the three feedback items) and **135** (the harvest execution, the double agent-death, the seven issues, the effective-rate call). This is r2's **Journal** phase. |

**The six-week stall is part of the record.** All three PRs were authored 2026-06-26 and then sat
**unmerged through a project pause** — the operator's session boundary that round was explicitly *"do all
work required to prep for the next iteration… however, we will not start the next iteration in this
session."* Two QA gates were killed mid-flight at that pause. On **2026-08-07** the gates were re-dispatched,
passed, and the three PRs merged in the prescribed order **#305 → #311 → #314**. (`main` was also
unblocked that day by **#323**, a bundler-audit failure on `crass 1.0.6` that was red-lighting `scan_ruby`
on every PR.) Nothing about the harvest's *content* changed during the stall; only its landing date did.

**Process note carried from ch. 135:** the first PM and `github-agent` dispatches of this round **both
died simultaneously at the 600s watchdog, producing nothing** — a *fourth* distinct agent-death shape
(mid-run-with-no-side-effect, vs. 0007's rate-limit kills and the 2026-06-19 death-on-completion). Recovery
followed the mature protocol: verify actual side-effects (zero issues created, no PM branch) before
re-dispatching, then **tighten the prompt to remove the suspected cause** — the PM's brief was descoped of
a `WebFetch`-driven `source_url` backfill, and both retried agents returned cleanly.

## r2 backlog — seven issues filed, all still open

The **`github-agent`** filed all of them (no inline `gh` shortcuts — the all-mechanics-through-the-agent
rule honored). **Seven** net-new issues, spanning **#306–#313** — note the range is not contiguous:
**#311 in that range is a PR, not an issue.**

| Issue | Label(s) | What | Disposition |
|---|---|---|---|
| **#306** | `frontend` | Time-series chart X-axis → calendar `Mon YYYY` ticks + crosshair | **iteration-0008 infra prerequisite.** Independent of the backend. |
| **#307** | `engineering`, `backend` | Source link — registry **`source_url`** column + §4 envelope field | **iteration-0008 infra prerequisite.** Blocks #309. |
| **#308** | `engineering`, `backend` | Acronym tooltips — per-field **`help`** text in the §4 envelope | **iteration-0008 infra prerequisite.** Blocks #310. |
| **#309** | `frontend` | "Compare on calculator.net" link on every calculator page | **iteration-0008 infra prerequisite.** Depends on #307. |
| **#310** | `frontend` | Acronym tooltips — shared hover-tooltip component for labels and outputs | **iteration-0008 infra prerequisite.** Depends on #308. |
| **#312** | `backend` | **Income Tax v2** — backend (carries the full v2 spec + the effective-rate decision note) | **Deliberately EXCLUDED from iteration-0008.** Rides a later propagation sweep. |
| **#313** | `frontend` | **Income Tax v2** — frontend (identical v2 spec body) | **Deliberately EXCLUDED from iteration-0008.** Rides a later propagation sweep. |

**#306–#310 are the infra layer iteration-0008 pins *behind*** — the `source_url` and per-field `help`
envelope fields plus their three frontend consumers are conventions #305 already *mandates*, so they must
exist in the envelope before a fan-out builds against it. Backend (#307, #308) lands before frontend
(#309, #310); #306 is independent.

**#312/#313 (Income Tax v2) are explicitly out of iteration-0008's scope.** The v2 spec is authored and
filed, but regenerating Income Tax is a *propagation* job, not a new-build one — it rides a later sweep
rather than competing with 0008's new-build set. Per the append-only / deprecate-never-delete ethos the v1
issues (#250 BE / #260 FE, both closed by the r1 builds) remain for historical comparability; v2 is
"regenerate from this spec, not from prior code."

## What r2 did **not** change

Stated explicitly so a future reader doesn't go hunting for a missing update:

- **r2 built no calculators.** No `app/calculators/*.rb` was added, regenerated, or patched; no calculator
  page changed. All three merged PRs are **docs / agent-definition / spec** only.
- **The catalog stays at 24.** `docs/INVENTORY.md` therefore needs **no update at this close** — the r1
  close already floated all ten 0007 calculators into the completed block (14 → 24) with their build-time
  slug + description. There is no `+N / −N` inventory delta for r2 and none should be expected.
- **The `source_url` backfill into `INVENTORY.md` is deliberately deferred** to **iteration-0008's Open
  phase**, per PR #311 ("the per-calculator `source_url` backfill into `INVENTORY.md` happens at
  iteration-0008's Open phase, per the launch plan — not done here"). It was descoped from r2's PM dispatch
  because it was `WebFetch`-driven and the prime suspect for the 600s stall that killed the first dispatch.
  Note the consequence: `ARCHITECTURE.md §3.2`/§4 now reference an `INVENTORY.md` **`source_url`** that the
  inventory does not yet carry as such (it carries a `Source` column with the same URL). Reconciling the two
  — column name and per-row backfill — is **iteration-0008 Open work, not a gap in this close.**
- **No retroactive completeness audit.** Per the operator's locked scope, the completeness band governs
  future builds/regens only; the other 23 calculators were not re-assessed against it.
- **iteration-0008 is not opened by this addendum**, and no tag was moved or created. 0008 pins at the
  **post-r2 `main`** — the state after #305/#311/#314 merged — which is precisely why r2 belongs to
  iteration-0007's log: *0008 pins at r2's output, so r2 is definitionally 0007's harvest.*

## Process observation — a closed iteration reopened

**The finding worth carrying forward:** an iteration that has been *declared closed* can still reopen for a
second Evaluate→Harvest round when the operator's own review lands late. That is exactly what happened here.
r1 closed on 2026-06-16 the day the builds finished, on the strength of the QA gates and an in-flight UI
pass; the operator's unhurried, hands-on click-through happened **nine days later** and produced feedback
substantial enough to reshape the product (a new `PRODUCT.md` principle), the conventions (four of them), and
the next iteration's critical path (five prerequisite issues). By any honest reading the iteration was still
open on 2026-06-16.

Two ways the lifecycle in `CLAUDE.md` could name this case:

1. **An evaluation gate before Close** — Phase 6 may not run until the *operator's* evaluation (distinct from
   the per-PR QA gate) has actually happened and been recorded. This makes the premature close impossible by
   construction, at the cost of a close that can block indefinitely on a human.
2. **A named "reopened close"** — closing stays cheap, but the lifecycle explicitly permits an iteration to
   reopen for an additional Evaluate→Harvest round, with the log required to carry a per-round manifest (the
   shape this addendum improvises). This accepts late feedback as normal rather than exceptional.

There is a real trade-off between them: (1) buys correctness at the cost of throughput; (2) buys throughput
at the cost of a "closed" state that doesn't reliably mean finished. Note also that the two rounds' Evaluate
phases were *different in kind* — r1's was gate-and-glance and surfaced three shared-layer **UI nits**; r2's
was a slow live click-through and surfaced three **product-level** items. That asymmetry is itself an argument
that the operator's hands-on pass is a distinct, non-optional input, not a redundant second look.

> **Open question for the operator — the PM does not own this file.** Whether to encode (1), (2), or neither
> is a change to the **iteration delivery lifecycle in `CLAUDE.md`**, which the PM never edits. Raised here as
> a question, not a decision. **No `CLAUDE.md` change was made by this addendum.**

## r2 close statement

Iteration-0007 is **closed as of 2026-08-07**, having run two full Evaluate→Harvest rounds. Final state:
**10 calculators shipped** (r1), **catalog 24** (unchanged by r2), **two harvests merged** (r1: #284/#285/#287/#288/#289;
r2: #305/#311/#314), **r1's one filed issue #286 since fixed and closed** (the shared-fixture split, PR #296),
and **seven still-open issues from r2** (#306–#310, #312, #313). iteration-0008 opens pinned at the **post-r2 `main`**, behind the
#306–#310 infra prerequisites, with #312/#313 held back for a later propagation sweep.
