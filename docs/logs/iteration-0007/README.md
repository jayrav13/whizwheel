# Iteration 0007

**Status:** open
**Opened:** 2026-06-16
**Pinned agent SHA:** iteration-0007 is pinned at the **post-harvest `main` SHA** `e85c47c` (HEAD at
open). The main thread applied the `iteration-0007` git tag at that SHA; the PM does not create the tag.
This log references "iteration-0007, pinned at post-harvest `main` (`e85c47c`)."
**Tag:** `iteration-0007` (applied by the main thread at `e85c47c`)
**Calculators:** **10 new builds, n = 10** (≈20 build PRs) — Auto Loan (BE/FE), Sales Tax (BE/FE),
Pythagorean Theorem (BE/FE), Discount (BE/FE), VAT (BE/FE), Personal Loan (BE/FE), Average Return (BE/FE),
ROI (BE/FE), House Affordability (BE/FE), Income Tax (BE/FE). **Regen set: EMPTY** (rationale below).

**Headline outcome:** _(filled at close)_ —

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

| Calculator | Backend issue | Frontend issue | Notes file |
|---|---|---|---|
| Auto Loan | _(filed by github-agent)_ | _(filed)_ | `auto-loan.md` |
| Sales Tax | _(filed)_ | _(filed)_ | `sales-tax.md` |
| Pythagorean Theorem | _(filed)_ | _(filed)_ | `pythagorean-theorem.md` |
| Discount | _(filed)_ | _(filed)_ | `discount.md` |
| VAT | _(filed)_ | _(filed)_ | `vat.md` |
| Personal Loan | _(filed)_ | _(filed)_ | `personal-loan.md` |
| Average Return | _(filed)_ | _(filed)_ | `average-return.md` |
| ROI | _(filed)_ | _(filed)_ | `roi.md` |
| House Affordability | _(filed)_ | _(filed)_ | `house-affordability.md` |
| Income Tax | _(filed)_ | _(filed)_ | `income-tax.md` |

The `github-agent` will file all 20 issues — two per calculator (`backend` + `frontend`), both carrying the
identical full `spec:v1` body — reading the spec files from this branch. Its dedupe scan should find **no prior
issues** for any of the ten (confirmed at open: the only related open issue is #215, a Right Triangle FE
follow-up, not one of these). Issue numbers will be recorded here once filed.

---

_Build outcome, Evaluate verdict, Harvest, and Close sections are filled as the iteration progresses (mirroring
iteration-0006's structure). The predictions and metrics above are the round's instruments — at close, each
prediction is marked **held / falsified** and the two consistency metrics are summarized._
