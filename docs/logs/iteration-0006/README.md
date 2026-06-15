# Iteration 0006

**Status:** open
**Opened:** 2026-06-14
**Pinned agent SHA:** iteration-0006 is pinned at the **post-harvest `main` SHA** (the iteration-0006
tag is applied by the main thread at `main` HEAD after PR #182 — the QA-output-format change —
merged, so the pin captures the full post-iteration-0005 harvest agent set). The PM does not create
the tag; this log references "iteration-0006, pinned at post-harvest main."
**Tag:** `iteration-0006` (applied by the main thread at the post-harvest `main` SHA)
**Calculators:** **6 new builds, n = 6** — Loan (BE/FE), Mortgage (BE/FE), Compound Interest (BE/FE),
Standard Deviation (BE/FE), Right Triangle (BE/FE), Date (BE/FE). **Regen set: EMPTY** (rationale
below).

**Headline outcome:** — (open)

---

## What this iteration is

Iteration 0006 is a **new-build iteration of six calculators** climbing the complexity gradient into
the project's hardest cluster so far — the **loan family** (Loan → Mortgage, both built on the
amortized-payment primitive already proven by Amortization in 0004), plus **Compound Interest**
(exponential growth with a compounding-frequency selector), **Standard Deviation** (population vs.
sample), **Right Triangle** (geometry + trig solve-for-missing), and **Date** (date difference vs.
add/subtract). Five of the six are **multi-mode**, so this iteration is also the broadest test yet of
the mode-picker rule (`DESIGN.md §4`) on fresh, never-seen calculators.

## Scope (operator-decided)

### New-build set (6) and build sequence

| # | Calculator | Cx | Tags | Build order |
|---|---|---|---|---|
| 1 | **Loan** | 4 | multi-input, multi-mode, tabular-output | **first** |
| 2 | **Mortgage** | 5 | multi-input, iterative-solve, tabular-output, charts | **second** |
| 3 | **Compound Interest** | 4 | multi-input, multi-mode, charts | parallel (after Mortgage) |
| 4 | **Standard Deviation** | 3 | statistical, multi-mode, text-output | parallel |
| 5 | **Right Triangle** | 3 | geometry, multi-mode | parallel |
| 6 | **Date** | 3 | date-math, multi-mode | parallel |

**Sequence rationale (operator):** **Loan first, then Mortgage.** Loan **generalizes the built
Amortization** (it adds a multi-mode solve — payment vs. amount vs. term — on top of the same
amortized-payment math) and establishes the **loan-cluster primitive** that Mortgage builds on
(Mortgage = a loan plus property-tax / insurance / extra-cost components and a charts page). Building
Loan first lets Mortgage inherit a proven loan core rather than re-deriving it. The other four
(Compound Interest, Standard Deviation, Right Triangle, Date) are independent and **fan out in
parallel** once Loan + Mortgage are under way. For **every** calculator BOTH layers ship — **backend
before frontend** (the FE codes against the BE's §4 envelope).

### Regen set: EMPTY — and why

**No regeneration sweep this iteration.** This is a deliberate, reasoned call (and the PM concurs
after full ingestion — see the agreement note below), not an omission:

- **The #109/#110 numeric guard lives in shared `Calculators::Base`.** The iteration-0005 harvest
  encoded the numeric input guard (reject non-numeric input / fractional input for `:integer`
  attributes) at the **cast seam in `Calculators::Base`** (PRs merged to `main`: the parse-based guard
  + the `backend.md` convention, #109/#110). Because it is in the **shared base class**, it
  **auto-applies to every calculator** already on `main` — there is nothing to regenerate to propagate
  it; the priors inherit it at runtime today. A backend regen would re-emit identical math.
- **The #143 stat-grid component migration was applied to all 7 stat-grid priors *inside the harvest
  PRs themselves*.** The shared-component refactor (the single BLEND stat-grid component + the
  `frontend.md` convention + `DESIGN.md §4` rewrite) **already swept the existing stat-grid views** as
  part of landing #143 — the priors are on the shared component now, on `main`. A frontend regen would
  re-emit views that already use it.

So **the iteration-0005 harvest is already propagated to the priors** — the two harvested changes
reached every existing calculator either by living in the shared base (backend) or by being applied
in-place across the views during the harvest PR (frontend). A regen sweep's sole purpose is
propagation; with propagation already complete, a sweep would carry **no new signal** — it would
re-emit identical backend math and views-on-the-shared-component. The iteration's evidence this round
therefore comes entirely from the **six new builds** (and what the mode-picker rule does on five
never-seen multi-mode calculators).

> **PM agreement note.** After full-context ingestion (CLAUDE.md, ARCHITECTURE.md, the iteration
> 0001–0005 logs, DESIGN.md §4, the git log confirming the #109/#110 base-class guard and the #143
> in-harvest stat-grid sweep all on `main`), the PM **concurs** with the empty regen set. The standing
> rule is that a regen sweep *propagates a harvest*; here the harvest self-propagated (shared base
> class + in-PR view migration), so there is genuinely nothing left for a sweep to carry. The new
> builds will, of course, be built on the post-harvest agents — so they inherit the guard and the
> stat-grid component natively, which is its own light confirmation that the harvest "took."

### Pin

Iteration-0006 is pinned at the **post-harvest `main` SHA**. The iteration-0005 harvest (the
build-facing pieces) is fully merged to `main`:

- **#111** — SimpleCov parallel-fork coverage merge (the local-undercount fix).
- **#109 / #110** — the numeric input guard at the `Calculators::Base` cast seam (code) **and** the
  matching `backend.md` convention.
- **#143** — the shared BLEND stat-grid component (code) **and** the `frontend.md` convention **and**
  the `DESIGN.md §4` rewrite (single component + bounded modifier set; the "never a per-page inline
  `grid-cols-[repeat(auto-fit,…)]`" rule).
- **#182** — the QA-agent verdict-table output format (process; rides in the pin).

The **main thread applies the `iteration-0006` git tag** at `main` HEAD once #182 has merged (it had
merged at the time this log was opened — `main` HEAD `7f15521`), so the pin captures the **complete**
post-harvest agent set. The PM does not create the tag.

## The harvest this iteration builds on (iteration-0005 → 0006)

The agent set iteration-0006 pins at carries the iteration-0005 harvest. The build-facing deltas
since iteration-0005 (`e84b05a`):

| Change | Layer | PR(s) | What |
|---|---|---|---|
| **Numeric input guard** | backend | #109 / #110 (code + `backend.md`) | At the `Calculators::Base` cast seam, **non-numeric input is rejected** (no longer silently coerced to 0) and **fractional input for an `:integer` attribute is rejected** (no longer silently truncated). Lives in the shared base → applies to every calculator. **Consequence for spec authoring: `:integer` attributes no longer need an `only_integer` workaround — the guard enforces it at the seam.** |
| **Shared stat-grid component** | frontend | #143 (code + `frontend.md` + `DESIGN.md §4`) | The responsive stat grid is now **one shared BLEND component with a bounded modifier set**; the standing rule is **use the component + its modifiers, NEVER a per-page inline `grid-cols-[repeat(auto-fit,…)]` width** (the six-divergent-min-widths problem from 0005 is closed). |
| **SimpleCov fork-merge** | backend (test infra) | #111 | Local parallel-fork coverage is merged so a local `bin/rails test` reports the true total (no spurious under-100% locally). |
| **QA verdict-table format** | process | #182 | The `quality-assurance-agent` returns a fixed verdict table (#169 refinement). Rides in the pin; no build-shaping effect. |

These are the **only** build-facing deltas since 0005. The mode-picker rule (validated 0004), the
`DESIGN.md §4` chart / Today-button conventions (validated 0005), and the FE per-calculator
registration guarantees ride along unchanged — and are **exercised** by this iteration's six new
builds (five multi-mode; Mortgage charts; no date-free calc gets a Today button; etc.).

## The experimental questions this iteration carries

The six new builds are the evidence. The sharpest questions:

1. **Does the mode-picker rule generalize to five fresh multi-mode calculators at once?** Loan
   (solve-for: payment / amount / term — 3 short-ish), Compound Interest (compounding frequency —
   N≥4, multi-word → option list), Standard Deviation (population vs. sample — N=2, short →
   segmented), Right Triangle (solve-from: which two knowns — a small mode set), and Date (difference
   vs. add/subtract — N=2 → segmented). Per the rule the agent should pick **segmented for N≤3/short**
   and **option list for N≥4/multi-word**, unprompted, on never-seen calculators. This is the broadest
   single-iteration test of the rule so far.
2. **Does the loan primitive transfer Loan → Mortgage cleanly?** Loan generalizes Amortization;
   Mortgage extends Loan with tax/insurance/extra components + a charts page. Building Loan first,
   does Mortgage's backend reuse the amortized-payment core without re-deriving it, and does its FE
   reach for the §4 charts convention (donut of payment components + balance curve) the way
   Amortization did in 0005?
3. **Does the numeric guard (now in `Base`) hold on fresh `:integer` inputs without per-calc
   workarounds?** Loan/Mortgage term-in-months/years, Compound Interest periods, Date day/week/month
   offsets are `:integer`; per the harvest the spec declares them `:integer` with `greater than 0`
   rules and **no `only_integer` workaround** — the build should inherit rejection of fractional input
   from `Base`. A light confirmation the harvest took.
4. **Does the shared stat-grid component get used (not re-inlined) on the new stat pages?** Standard
   Deviation (mean / variance / SD / count / sum), Right Triangle (sides / angles / area / perimeter),
   Compound Interest (final balance / total interest) are stat-grid pages — they should use the shared
   component + modifiers, never a per-page inline auto-fit width (the #143 rule).

## The six specs

Each calculator's `spec:v1` body is authored as a **separate file** under
`docs/logs/iteration-0006/specs/` so the `github-agent` can consume each verbatim into the two GitHub
issues it files per calculator (a `backend` issue and a `frontend` issue, **both carrying the
identical full spec body**, title = the calculator name, layer conveyed by the `backend`/`frontend`
label):

| Calculator | Spec file | Modes (multi-mode picker rule applies) |
|---|---|---|
| Loan | `specs/loan.md` | solve-for: **monthly payment** / **loan amount** / **term** |
| Mortgage | `specs/mortgage.md` | single primary mode (fixed-rate, full payment breakdown + charts) |
| Compound Interest | `specs/compound-interest.md` | compounding frequency: annually / semiannually / quarterly / monthly / daily |
| Standard Deviation | `specs/standard-deviation.md` | **population** / **sample** |
| Right Triangle | `specs/right-triangle.md` | solve-from: which two of {a, b, c} are known (two-legs / leg+hypotenuse) |
| Date | `specs/date.md` | **difference between two dates** / **add or subtract from a date** |

Every reference-value table in these specs was **PM-computed deterministically** (standard formulas,
full `BigDecimal`/calendar-aware precision) — not taken on a web model's word — so the figures the
backend agent must reproduce are authoritative. Where calculator.net's page only described the
formula/inputs (Compound Interest, Right Triangle, Date), the formula was confirmed against the
Source and the figures computed from it; where the Source showed worked numbers they were matched.

## Per-calculator notes

Per-calculator build + feedback notes accrue in `docs/logs/iteration-0006/<calculator>.md` as each
build lands (these files are disjoint, fan-out-safe). They will record what each agent produced, what
was right, what missed, and what agent-definition change a miss suggests — and at close, the build
PRs per layer.

| Calculator | Backend issue | Frontend issue | Notes file |
|---|---|---|---|
| Loan | (to be filed) | (to be filed) | `loan.md` |
| Mortgage | (to be filed) | (to be filed) | `mortgage.md` |
| Compound Interest | (to be filed) | (to be filed) | `compound-interest.md` |
| Standard Deviation | (to be filed) | (to be filed) | `standard-deviation.md` |
| Right Triangle | (to be filed) | (to be filed) | `right-triangle.md` |
| Date | (to be filed) | (to be filed) | `date.md` |

(Issue numbers are filled in once the `github-agent` files the 12 issues — two per calculator.)
