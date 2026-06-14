# Iteration 0005

**Status:** closed
**Opened:** 2026-06-14
**Closed:** 2026-06-14
**Pinned agent SHA:** `e84b05a` (`main` HEAD at open — merge of PR #126; the post-0004-harvest agent set)
**Tag:** `iteration-0005`
**Calculators:** **REGEN-ONLY** — no new builds (`n = 0`). A **FRONTEND-ONLY** regeneration sweep of
**all 8** previously-built calculators: Percentage (FE #31), BMI (FE #53), Ohms Law (FE #55),
Tip (FE #76), Simple Interest (FE #78), Mean·Median·Mode·Range (FE #80), Age (FE #82),
Amortization (FE #84).

**Headline outcome:** **SUCCESS — all 8 FE regens merged green; the harvested `DESIGN.md §4`
conventions propagated from spec alone.** Regenerating each page from its frontend `spec:v1` +
the updated `DESIGN.md`/`frontend.md` under `e84b05a`, the three convention-bearing pages came
through cleanly: **Amortization** rebuilt with **interactive JS charts** (the agent **self-installed
the importmap pins unprompted** — vendored lightweight-charts + Chart.js, navigating a chart.js
chunking snag), the stat-bearing pages came out as **responsive auto-fit grids**, and **Age**
regenerated with the explicit **"Today" quick-fill button** (blank-means-today, no silent
prefill, none on the required birth-date). The operator reviewed the live app and **had no notes —
called it "a huge success."** The discrimination controls held (no chart/pin on the 7 chart-free
pages; no Today button on the date-free pages; the mode-picker rule survived untouched). The
**visual gate earned its keep**: it caught two real chart bugs (a blank donut, a 1970 x-axis) that
**every markup test passed over** — both fixed, with a pixel-level chart test added to prevent
recurrence. FE PRs: Tip #133, Ohms Law #134, BMI #135, Percentage #136, Age #137, Simple
Interest #138, MMR #139, Amortization #141 (backend unchanged — FE-only iteration).

---

## What this iteration is

This is a **regeneration sweep, not a new-calculators iteration** (`n = 0` new builds), and it is
deliberately **frontend-only**. Its sole purpose is to **propagate iteration 0004's frontend
harvest** — the UX conventions lifted into `DESIGN.md §4` and the slimmed frontend agent — across
**every** built page, and to measure whether those harvested conventions come through cleanly when
each page is regenerated **from its spec + the updated agent set** (`ARCHITECTURE.md §3.1`). As
always, the sweep — not new builds — is the iteration's evidence.

It is also the **first iteration opened under the codified delivery lifecycle**
(open → build → evaluate → **harvest** → journal → close), and the first whose pinned set carries a
**harvest applied before close**: iteration 0004's harvest was recorded retroactively (see
`iteration-0004/README.md` → "Harvest"), and `e84b05a` is the `main` HEAD *after* that harvest
landed. So 0005 opens against the harvested agent set and tests it under controlled regeneration.

## Why frontend-only

The 0004 harvest's **build-facing** changes are **entirely frontend-facing**:

- **`DESIGN.md §4`** gained three UX conventions (PR #125): interactive JS charts, responsive
  auto-fit stat grids, and the "Today" quick-fill date button.
- **`.claude/agents/frontend.md`** was slimmed to defer UI conventions to `DESIGN.md` (PR #123).

**No backend-relevant agent moved in the harvest.** The two backend findings from 0004 — `:integer`
coercion defeating `only_integer` (#109) and non-numeric input silently coerced to 0 (#110) — were
**deferred, not encoded** (they remain open `agents` issues). Regenerating the backend math under
`e84b05a` would therefore be a **no-op signal-wise**: same `spec:v1`, same unchanged backend agent,
same math. The information this iteration carries lives in the **frontend pages**. Backend is **out
of scope**; the math on `main` stays as-is.

## Why this SHA

Pinned to **`e84b05a`** — the current `main` HEAD at open (merge of PR #126, the parity audit). It
is the fully-ingested, clean state the iteration opens against, and it carries the **post-0004-harvest
agent set** — crucially the updated `DESIGN.md §4` (the three UX conventions) and the slimmed
`frontend.md`. That harvested frontend guidance is the delta under test this iteration.

## What changed in the agents since iteration 0004 (the delta under test)

Iteration 0004 was pinned to **`3f2ac29`**. Between `3f2ac29` and `e84b05a`, the **build-facing**
changes (the iteration-0004 harvest) are:

- **`docs/DESIGN.md §4`** — three new/expanded component conventions (PR #125):
  1. **Charts** — result charts use a **hover/crosshair/tooltip-capable JS charting library**,
     delivered via **importmap (no build step)**: TradingView **lightweight-charts** for
     line/time-series (Amortization's balance curve), a **complementary hover-capable library** for
     donut/breakdown (lightweight-charts has no pie type), slice order largest green → coral → amber,
     reading the §4 envelope, with a **no-JS data-table/legend fallback always retained**.
  2. **Stat grid** — a **responsive auto-fit grid**
     (`grid-cols-[repeat(auto-fit,minmax(<min>,1fr))]`), never a pinned column count; `tabular-nums`,
     values must **never clip**.
  3. **Date field with "Today" quick-fill** — for an *optional* date whose blank value means
     "today"; an explicit **Today button**, **never** a silent auto-prefill, and **never** on a
     required/primary date input.
- **`.claude/agents/frontend.md`** — **slimmed to defer UI conventions to `DESIGN.md`** (PR #123),
  keeping only agent-process notes. (Plus the earlier worktree-isolation hardening, PR #118 —
  process, not page-shaping.)

These are the **only** build-facing deltas. The mode-picker rule (validated in 0004) is unchanged
and rides along untouched. So the question 0005 answers is narrowly about the **three new UX
conventions** reaching the pages from the design system alone.

## The experimental question

**When the frontend agent regenerates all 8 calculators from spec + the updated `DESIGN.md` /
`frontend.md` (with UI conventions now living in `DESIGN.md`, not the agent), do the harvested
conventions come through cleanly — without a human flagging anything?** Concretely, per the
convention's natural test calculators:

1. **Interactive JS charts (Amortization).** The 0004 Amortization page shipped a **CSS
   conic-gradient donut + an SVG balance curve** — *before* the JS-charts convention existed. Under
   `e84b05a`, regenerating from spec + the new `DESIGN.md §4` "Charts" entry, does the page now come
   out with **hover/crosshair/tooltip JS charts** (lightweight-charts for the balance curve, a
   hover-capable donut)? **And does the agent self-install the charting importmap pin** (add the
   library to `config/importmap.rb` / vendor it) as part of the build, or does it stall on the
   missing dependency? This pin-installation is the sharpest open risk — the convention names
   importmap delivery but the agent must wire it up itself.
2. **Responsive auto-fit stat grids (all stat-bearing pages — Tip, MMR, Age, Amortization, etc.).**
   Do the stat grids regenerate as **auto-fit** `minmax` grids (no pinned column count, no clipping
   on 6+ digit values), per the new convention — replacing any fixed-column grids from 0004?
3. **The Today-button (Age).** Age's optional `end_date` ("age as of") — does it regenerate with an
   explicit **"Today" quick-fill button** beside the field, with the field left **blank** (no silent
   auto-prefill), per the new convention? And does the agent correctly **not** add a Today button to
   the **required** birth-date input?

**Discrimination checks (the conventions must not over-apply):**

- Calculators with **no chart** (Percentage, BMI, Ohms Law, Tip, Simple Interest, MMR, Age) must
  **not** sprout a JS chart or pull in the charting pin.
- Calculators with **no optional date** (all but Age) must **not** grow a Today button.
- The **mode-picker rule** (0004's validated convention) must survive the regen unchanged — option
  list for Percentage main / Ohms 6-mode, segmented for BMI US|Metric / Percentage Increase|Decrease
  / Simple-Interest years|months.

A secondary, lighter question: with `frontend.md` **slimmed to defer to `DESIGN.md`**, does the
agent still produce correct pages — i.e. did moving the conventions out of the agent and into the
design system leave the agent with enough to build well, or did the slim cause regressions? This is
a small A/B on the "conventions belong in `DESIGN.md`, not the agent" decision itself.

## What this iteration builds

- **n = 0 new calculators.** No new selections; **no new issues created.** (Per the regen-sweep
  convention established in 0003/0004: a regeneration reuses each calculator's existing closed
  `spec:v1` issue as its spec — the spec hasn't changed — and is tracked here in the log + by its
  own PR(s). A regen PR does **not** `Closes` anything; the calculators are already built and their
  FE issues already closed.)
- **Regeneration sweep — FRONTEND ONLY, all 8 calculators**, each regenerated from its frontend
  `spec:v1` issue under `e84b05a`. The delta from each page's iteration-0004 version is this
  iteration's core data on whether the harvested UX conventions propagate.

## Regeneration sweep — tracking & separation

Same lightest-correct approach as iteration 0004: **no new issues.** The spec **is** the issue body,
and all 8 calculators already have complete `spec:v1` frontend issues (the FE numbers below). A
regeneration is *regenerate-from-that-spec*; no new spec artifact is needed. Each regen ships as its
**own PR** (e.g. `regen: Age frontend [iteration-0005]`), **does not `Closes`** anything, and
references this iteration. At close, the inventory's `Built (PRs)` column will reflect each
calculator's **most recent merged FE PR** (a 0005 regen PR re-touches the FE layer and floats into
that cell); the per-calculator regen notes here record the **delta vs. the iteration-0004 version**.

## Per-calculator notes

| Calculator | FE issue (spec) | File | Kind |
|---|---|---|---|
| Percentage | #31 | `percentage.md` | regeneration (frontend) |
| BMI | #53 | `bmi.md` | regeneration (frontend) |
| Ohms Law | #55 | `ohms-law.md` | regeneration (frontend) |
| Tip | #76 | `tip.md` | regeneration (frontend) |
| Simple Interest | #78 | `simple-interest.md` | regeneration (frontend) |
| Mean·Median·Mode·Range | #80 | `mean-median-mode-range.md` | regeneration (frontend) |
| Age | #82 | `age.md` | regeneration (frontend) |
| Amortization | #84 | `amortization.md` | regeneration (frontend) |

Per-calculator notes accrue in `docs/logs/iteration-0005/<calculator>.md` as each regen lands.
These files are disjoint (fan-out-safe). The three convention-bearing pages —
**Amortization** (charts), **Age** (Today-button), and the stat-grid pages — carry the iteration's
sharpest evidence; the chart-free / date-free pages are the discrimination controls.

---

## Outcome (closed 2026-06-14)

**Result: SUCCESS.** All 8 frontend regenerations are **built and merged to `main`, CI green**, and
the operator reviewed the live app and **had no notes** — they called it **"a huge success."** This
was the first **regen-only, layer-scoped (frontend-only)** iteration, and the central question —
*do iteration 0004's harvested `DESIGN.md §4` conventions come through cleanly from spec + the
updated agent set, without a human flagging anything?* — resolved **yes**.

FE regen PRs, verified against GitHub (each titled as a regeneration, **does not `Closes`** anything
— the calculators were already built and their FE issues already closed):

| Calculator | FE issue (spec) | FE regen PR (iteration-0005) | Prior FE PR (iteration-0004) |
|---|---|---|---|
| Tip | #76 | [#133](https://github.com/jayrav13/whizwheel/pull/133) | #106 |
| Ohms Law | #55 | [#134](https://github.com/jayrav13/whizwheel/pull/134) | #100 |
| BMI | #53 | [#135](https://github.com/jayrav13/whizwheel/pull/135) | #101 |
| Percentage | #31 | [#136](https://github.com/jayrav13/whizwheel/pull/136) | #99 |
| Age | #82 | [#137](https://github.com/jayrav13/whizwheel/pull/137) | #104 |
| Simple Interest | #78 | [#138](https://github.com/jayrav13/whizwheel/pull/138) | #103 |
| Mean·Median·Mode·Range | #80 | [#139](https://github.com/jayrav13/whizwheel/pull/139) | #102 |
| Amortization | #84 | [#141](https://github.com/jayrav13/whizwheel/pull/141) | #105 |

**Backend unchanged** — this was a deliberately frontend-only iteration, so every calculator's
`Built (PRs)` backend cell stays at its iteration-0004 value; only the FE cell advances to the
0005 regen PR above.

### The experimental question — answered: PASS (conventions propagated from spec alone)

Regenerating each page from its frontend `spec:v1` + the updated `DESIGN.md`/`frontend.md` under
`e84b05a`, the three convention-bearing pages came through cleanly:

1. **Interactive JS charts (Amortization, #141).** The 0004 page shipped a CSS conic-gradient donut +
   an SVG balance curve — *before* the JS-charts convention existed. Regenerated under the new
   `DESIGN.md §4` "Charts" entry, the page now renders **hover/crosshair/tooltip JS charts**, and the
   sharpest open risk resolved in our favor: **the agent self-installed the charting importmap pins
   unprompted** — it pinned + vendored **lightweight-charts** (balance curve) and **Chart.js** (donut),
   navigating a **chart.js chunking snag** on its own rather than stalling on the missing dependency.
   The importmap self-install bet paid off.
2. **Responsive auto-fit stat grids (all stat-bearing pages).** The stat grids regenerated as
   **auto-fit `minmax` grids** (no pinned column count, no clipping), per the new convention.
3. **The Today-button (Age, #137).** Age's optional "age as of" date regenerated with an explicit
   **"Today" quick-fill button**, the field left **blank** (no silent auto-prefill), and the agent
   correctly did **not** add the button to the **required** birth-date input.

**Discrimination controls held.** The 7 chart-free pages did **not** sprout a JS chart or pull the
charting pin; the date-free pages did **not** grow a Today button; and the **mode-picker rule**
(0004's validated convention) survived the regen unchanged. Moving the UI conventions out of the
agent and into `DESIGN.md` (the slimmed `frontend.md`, #123) left the agent with enough to build
well — no regressions from the slim.

### The visual gate earned its keep — real bugs that markup tests missed

The headline process finding: **the visual gate caught two real chart bugs that every markup/render
test passed over** — a **blank donut** (the chart element present and tested-as-rendered, but
painting nothing) and a **1970 x-axis** (a date/epoch bug on the balance curve). Markup-level tests
assert the canvas/structure exists; they cannot see that *no pixels were drawn* or that the axis is
wrong. Both were **fixed**, and a **pixel-level "chart actually painted" test was added** so the
class of bug can't recur silently. This is direct evidence for the visual gate as a non-optional
step for chart-bearing pages — and it drove deferred-harvest issue **#144**.

### Harvest (this iteration)

Applied **before** close, per the codified delivery lifecycle (open → build → evaluate → **harvest**
→ journal → close):

| Change | PR / Issue | What |
|---|---|---|
| **`ci-monitor` reworked to retries-only** | [#142](https://github.com/jayrav13/whizwheel/pull/142) (merged with this close) | `ci-monitor` now retries through transient/inconclusive results rather than reporting a flaky non-result (origin: #140, recurring dispatched-agent socket deaths / inconclusive CI polls). This is the iteration's **encoded** harvest — it lands on `main` as part of the close. |

**Deferred-harvest backlog (filed as issues, not yet encoded):**

| # | Label | What |
|---|---|---|
| [#143](https://github.com/jayrav13/whizwheel/issues/143) | engineering | **Promote the responsive stat grid to one shared BLEND component** — the 8 regens implemented the auto-fit grid **6 different ways**; the convention is right but its realization diverged, so it belongs as a single shared component rather than re-derived per page. |
| [#144](https://github.com/jayrav13/whizwheel/issues/144) | agents | **Codify the chart pixel-test + importmap chart-lib packaging rule in the FE agent** — make the "chart actually painted" pixel test and the importmap charting-pin install/vendor step standing FE-agent requirements (origin: the two chart bugs the visual gate caught + the self-install navigation this iteration).

### Process note

Iteration 0005 was the **first regen-only, layer-scoped (frontend-only) iteration** run under the
newly-codified **iteration delivery lifecycle** (`CLAUDE.md`, PR [#130](https://github.com/jayrav13/whizwheel/pull/130)) —
and the first whose pinned set carried a **harvest applied before close** (0004's harvest landed on
`main`, then 0005 opened pinned at it). It validated three things at once: that a **regen-only**
iteration is a legitimate unit of delivery, that a **layer-scoped** sweep correctly touches only the
moved layer (backend stayed put), and that the harvest-before-close ordering works in practice.
