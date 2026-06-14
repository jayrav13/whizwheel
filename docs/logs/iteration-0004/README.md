# Iteration 0004

**Status:** open
**Opened:** 2026-06-14
**Closed:** —
**Pinned agent SHA:** `3f2ac29` (`main` HEAD at open — merge of PR #73)
**Tag:** `iteration-0004`
**Calculators:** Tip (#75 BE / #76 FE), Simple Interest (#77 BE / #78 FE), Mean·Median·Mode·Range
(#79 BE / #80 FE), Age (#81 BE / #82 FE), Amortization (#83 BE / #84 FE) — **5 new builds**;
plus the **regeneration sweep** of every prior calculator (Percentage, BMI, Ohms Law),
shipped as **its own separate PR(s)**, kept distinct from the new-build PRs.

**Headline outcome:** _— (filled at close)_

---

## What this iteration is

The largest iteration so far: it adds **five new calculators** spanning the complexity gradient
from 2 → 4, and runs the full **regeneration sweep** of every previously-built calculator
(Percentage, BMI, Ohms Law) with the pinned agent set. As always, the sweep — not just the new
builds — is the iteration's primary evidence (`ARCHITECTURE.md §3.1`). Two structural things make
0004 distinct from 0001–0003:

1. **It is the first iteration whose pinned agent set already carries the mode-picker rule** — so
   the regen sweep is the **first clean A/B of that rule** (see "The experimental question" below).
2. **The regeneration sweep ships as separate PR(s)** from the new-calculator build PRs, by
   explicit human directive — so the sweep's diff stays cleanly isolated as A/B evidence and never
   tangles with new-build review. Track the sweep PRs distinctly from the build PRs (see
   "Regeneration sweep — tracking & separation").

## The five new calculators (what each stresses)

Chosen (user-confirmed) to climb the complexity gradient and exercise input/output shapes the
agents have not yet faced:

| Calculator | Cx | New stressor for the experiment |
|---|---|---|
| **Tip** (#75/#76) | 2 | A gentle warm-up + the **first per-person split** (derived secondary figures); plain multi-input, **no** mode picker. |
| **Simple Interest** (#77/#78) | 2 | The **financial primitive** `I = P·r·t`; first **unit selector** (`years`/`months`) → a **segmented control** (N=2, short) — a fresh, clean test of the picker rule on a brand-new calculator. |
| **Mean·Median·Mode·Range** (#79/#80) | 3 | The project's **first variable-length list input** (parse a numbers string) and a **non-scalar output key** (`mode` is an array — empty / one / many). |
| **Age** (#81/#82) | 3 | The project's **first date-math** calculator — `:date` inputs, a **leap-aware borrowing** algorithm, and **date validation** (invalid dates, birth-after-end). |
| **Amortization** (#83/#84) | 4 | The **stretch** — first **`tabular-output` + `charts`**: a full month-by-month `schedule` array and a `chart` series (donut + balance curve) over the §4 envelope, with last-payment rounding reconciliation. |

Specs are the issue bodies (`spec:v1`, `ARCHITECTURE.md §3.2`). Every reference-value table was
**PM-derived from the Source page and verified by independent computation** (date-borrowing,
amortization schedule, and statistics were each computed deterministically — not taken on the
WebFetch model's word — so the figures the backend agent must reproduce are authoritative). The
Amortization summary figures and month-1 row are pinned as the schedule's correctness anchors
(plus `schedule.length`, final-balance = `0.00`, and the column-sum reconciliations).

## Why this SHA

Pinned to **`3f2ac29`** — the current `main` HEAD at open (merge of PR #73, the historian's
iter-0003 journey chapters). It is the fully-ingested, clean state the iteration opens against and
carries the committed agent set — crucially, the agent set **already including the mode-picker
rule** (added to `frontend.md` + `DESIGN.md §4` during iteration 0003).

## What changed in the agents since iteration 0003 (the delta under test)

Iteration 0003 was tagged at **`0ca4a02`**. Between `0ca4a02` and `3f2ac29`, the build-facing
changes are:

- **`.claude/agents/frontend.md`** — gained the **mode-picker rule** (PR #64): a mode/variant
  picker is **always** a native radio `<fieldset>` posting `inputs[mode]`; presentation keyed on
  count + label length — **segmented control** at N≤3/short, **`.mode-option` option list** at
  N≥4/multi-word, never a raw `<select>` as the primary picker. Points at `DESIGN.md §4` as source
  of truth.
- **`docs/DESIGN.md §4`** — the matching **"Mode picker" component entry** + the Tab-pills clarification
  (page-level tabs vs. mode picker) + the `bg-accent/8` candidate-token note (PR #64).
- **`.claude/agents/project-manager-agent.md`** + **PM inventory rule** (PRs #69/#70) — the
  iteration-close-must-regenerate-inventory rule and the completed-block-sorts-by-BE-PR# rule.
  PM-facing only; **no effect on how the build agents produce calculators.**

So the **one build-facing delta** under test this iteration is the **mode-picker rule**, now part
of the pinned agent set. (Process/PM changes aside, no other build-agent or `DESIGN.md`/
`ARCHITECTURE.md` build guidance moved.)

## The experimental question (the clean A/B deferred from 0003)

Iteration 0003 added the mode-picker rule **reactively, mid-iteration**, so it explicitly logged
the controlled measurement as **deferred**: *does an agent, given only `DESIGN.md §4` +
`frontend.md`, **independently** reach for the right picker on a calculator — without a human
flagging a scrunched control?* (See `iteration-0003/bmi.md` and `ohms-law.md`,
"[OPEN — deferred to a future controlled sweep]".)

**Iteration 0004 is that controlled sweep.** The rule is now in the **pinned** agent set from the
open, so two independent lines of evidence test it:

1. **The regeneration sweep (A/B on prior calculators).** Percentage, BMI, and Ohms Law are
   regenerated from their specs under `3f2ac29`. In 0003 their pickers were converted by an explicit
   *post-hoc sweep* (PRs #63/#65/#66); the question now is whether the agent, regenerating each
   from spec alone, **lands the correct picker unprompted** — Percentage main mode → option list,
   Percentage Increase|Decrease → segmented, BMI US|Metric → segmented, Ohms 6-mode → option list.
   If the regenerated pages reproduce the correct pickers with no hand-tweak, the rule is durable
   and self-applying. **The sweep's diff vs. the iteration-0003 versions is the core A/B data**, and
   it ships in its **own PR(s)** so that diff stays isolated.
2. **A fresh, never-seen calculator (Simple Interest).** Its `years`/`months` unit selector (N=2,
   short labels) is a brand-new picker the agent has never built. Per the rule it should come out a
   **segmented control** on the first try — the cleanest possible test that the rule generalizes to
   unseen calculators, not just the three it was retrofitted onto.

A secondary question rides along on **Amortization**: the first `tabular-output` + `charts` page —
does the FE render a schedule table + CSS donut/curve to DESIGN §4 from the `schedule`/`chart`
envelope keys without the BE/FE seam leaking math into the view?

## Regeneration sweep — tracking & separation

**Decision (lightest correct approach): no new issues for the regen sweep. Reuse the prior
calculators' existing closed `spec:v1` issues as the specs; track the sweep here in the log + by
its own PR(s).**

Rationale:

- The spec **is** the issue body, and Percentage/BMI/Ohms already have complete `spec:v1` bodies on
  their original issues (Percentage #30/#31, BMI #52/#53, Ohms #54/#55). A regeneration is
  *regenerate-from-that-spec* — the spec hasn't changed, so **no new spec artifact is needed.**
- Creating fresh issues per regen would imply new specs and pollute the `backend`/`frontend` kanban
  with duplicate-titled issues that no PR is meant to "close" (a regen PR shouldn't `Closes #N` a
  brand-new issue — the calculator is already built). It would also distort the inventory's
  `Built (PRs)` column, which keys off the **most recent merged PR per layer**.
- The right home for "we regenerated these three this iteration" is **this iteration log** (the
  per-calculator regen notes below) and the **inventory refresh at close** (which recomputes
  `Built (PRs)` to the most-recent merged PR per layer — so a regen PR that re-touches a layer
  naturally floats into the coverage column without any new issue).

**Separation directive (human-mandated): the regen sweep ships as its own separate PR(s), kept
distinct from the new-calculator build PRs.** Operationally:

- New-build PRs are the 10 issues #75–#84 (each `Closes #N`).
- Regen-sweep PRs **do not** `Closes` anything (the calculators are already built and their issues
  already closed) — they are titled as regenerations (e.g. `regen: Percentage [iteration-0004]`) and
  reference this iteration. They are reviewed and merged on their **own** thread so the A/B diff is
  clean.
- At close, the inventory's `Built (PRs)` column will reflect each calculator's **most recent
  merged** PR per layer (a regen PR that re-touches a layer updates that cell), and the
  per-calculator regen notes here record the **delta vs. the iteration-0003 version**.

## What this iteration builds

- **n = 5 new calculators:**
  - **Tip** — BE #75 / FE #76.
  - **Simple Interest** — BE #77 / FE #78.
  - **Mean·Median·Mode·Range** — BE #79 / FE #80.
  - **Age** — BE #81 / FE #82.
  - **Amortization** — BE #83 / FE #84.
- **Regeneration sweep (separate PR(s)):** **Percentage** (spec #30/#31), **BMI** (spec #52/#53),
  **Ohms Law** (spec #54/#55), each regenerated from spec under `3f2ac29`. The delta from each
  calculator's iteration-0003 version is this iteration's core A/B data on the mode-picker rule.

## Per-calculator notes

| Calculator | Issues | File | Kind |
|---|---|---|---|
| Tip | #75 (BE) / #76 (FE) | `tip.md` | new build |
| Simple Interest | #77 (BE) / #78 (FE) | `simple-interest.md` | new build |
| Mean·Median·Mode·Range | #79 (BE) / #80 (FE) | `mean-median-mode-range.md` | new build |
| Age | #81 (BE) / #82 (FE) | `age.md` | new build |
| Amortization | #83 (BE) / #84 (FE) | `amortization.md` | new build |
| Percentage | #30 (BE) / #31 (FE) | `percentage.md` | regeneration (separate PR) |
| BMI | #52 (BE) / #53 (FE) | `bmi.md` | regeneration (separate PR) |
| Ohms Law | #54 (BE) / #55 (FE) | `ohms-law.md` | regeneration (separate PR) |

Per-calculator notes accrue in `docs/logs/iteration-0004/<calculator>.md` as builds and regens
land. These files are disjoint (fan-out-safe).

---

## Outcome (filled at close)

_— pending. At close: set the `INDEX.md` row to `closed`, fill the closed date + headline, write
the per-calculator deltas (especially the picker A/B verdict for the three regen calcs and the
Simple-Interest first-build picker), and **regenerate `docs/inventory.md`** (recompute
`Built (PRs)` from live GitHub state; float the five new calculators into the completed block)._
