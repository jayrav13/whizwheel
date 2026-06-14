# Iteration 0003

**Status:** closed
**Opened:** 2026-06-14
**Closed:** 2026-06-14
**Pinned agent SHA:** `0ca4a02` (`main` HEAD at open)
**Tag:** `iteration-0003`
**Calculators:** BMI Calculator (#52 BE / #53 FE), Ohms Law Calculator (#54 BE / #55 FE) — **2 new builds**; plus the regeneration sweep of every prior calculator.

**Headline outcome:** The project's **first multi-calculator parallel build** — BMI and Ohms
Law, 2 calculators × 2 layers fanned out as four concurrent build agents in isolated worktrees
(BE wave merged first: #58, #57; then FE: #60, #62), validating the fan-out model end-to-end;
the one real collision (both FE agents touched `_result.html.erb` / `home/index.html.erb` /
`calculators_helper.rb`) was resolved by an **additive rebase**, not a rewrite. The headline
*learning*, though, came from the **UI/taste layer**: trying the live app, the user spotted
BMI's US/Metric pills looked **scrunched** — and the diagnosis was not a spacing regression
(iteration 0002's scale was correctly applied) but a **wrong-element** problem: a 2-option
selector shouldn't wrap pills. That surfaced an axis the design system hadn't pinned —
**element choice is separate from spacing** — and drove a **mode-picker rule** codified into
**`DESIGN.md §4` + `frontend.md`** (PR #64), then swept across all calculators (Ohms #63,
Percentage #66 → option-list for N≥4/multi-word; BMI units #65, Percentage's Increase|Decrease
→ segmented control for N≤3/short). A user eyeballing the running app drove a design-system
rule, encoded once, propagated to all — the **convergence loop demonstrated on the taste
layer**. **Bookkeeping caveat:** this iteration is **not** a clean controlled A/B like 0002 —
`frontend.md` gained the picker rule *mid-iteration* in response to the build, so the agent set
evolved within the iteration (see "Bookkeeping honesty" below).

---

## What this iteration is

The first **multi-calculator** iteration: it adds **two new calculators** — BMI and Ohms
Law — and runs the full **regeneration sweep** of every previously-built calculator
(Percentage) with the pinned agent set. The new builds *and* the regen deltas are the
iteration's evidence (`ARCHITECTURE.md §3.1`).

Both new calculators are **complexity 2** and deliberately stress two patterns the agents have
only lightly exercised so far:
- **BMI** — a **unit-system mode switch** (US lb/in vs metric kg/cm) feeding one BMI scale,
  plus a **text classification output** (the WHO band) alongside the numeric result. Tests
  whether the agents handle a second output key that is *derived text*, and a mode selector
  that changes input *meaning* rather than the formula family.
- **Ohms Law** — a **six-mode "any two of four" solver** (V/I/R/P): supply two, solve the
  other two (plus power). A broader multi-mode surface than Percentage's, with
  division-by-zero guards and one square-root mode (`rp`). Tests multi-mode dispatch at higher
  fan-out and conditional input presence.

## Why this SHA

Pinned to **`0ca4a02`** — the current `main` HEAD at open (merge of PR #51). It is the
fully-ingested, clean state the iteration opens against and carries the committed agent set.

## What changed in the agents since iteration 0002 (the delta under test)

Iteration 0002 was pinned to **`1e18ce2`**. Between `1e18ce2` and `0ca4a02`, **no
`.claude/agents/*.md` build-agent definition and no `DESIGN.md`/`ARCHITECTURE.md` build-facing
doc changed in a way that alters how BMI or Ohms Law would be produced.** The intervening
commits are:

- **A new `database-agent`** (`.claude/agents/database-agent.md`, PRs #46/#47) — a read-only DB
  inspector. It is **not** a build agent and does not touch the calculator build path; it does
  not affect how BMI/Ohms Law are generated.
- **`dependabot-agent`** strict-major tightening (PR #24, issue #21) — dependency triage, not a
  build agent.
- **CLAUDE.md tightening** — `ci-monitor` is the sole CI-verification path, and the
  agent-opened-PR CI blind spot was closed (PRs #48, #51). Process/orchestration guidance, not
  calculator-build guidance.
- **PM `inventory.md`** — the Built (PRs) column / slug Source / completed-first sort (PR #49).
  A PM-doc change; no effect on the build agents.

**So this iteration is not a controlled A/B on a build-agent change** the way 0002 was. Its
value is twofold: (1) it **adds the first two non-Percentage calculators**, broadening the
evidence base from one page to three; and (2) the **regeneration sweep of Percentage** under
`0ca4a02` re-confirms the durable 0001/0002 fixes still hold and gives a second sample of the
spacing scale's effect. The new BMI/Ohms Law builds will surface **fresh misses** against the
current agent set — those misses (not a pre-planned doc change) are what point at the next
agent edit, which will close this iteration and open 0004.

## What this iteration builds

- **n = 2 new calculators:**
  - **BMI Calculator** — BE #52 / FE #53.
  - **Ohms Law Calculator** — BE #54 / FE #55.
- **Regeneration sweep:** **Percentage** (BE spec #30 / FE spec #31), regenerated from spec
  under `0ca4a02`. The delta from its iteration-0002 version (PR #41) is sweep data.

## Per-calculator notes

| Calculator | Issues | File | Kind |
|---|---|---|---|
| BMI Calculator | #52 (BE) / #53 (FE) | `bmi.md` | new build |
| Ohms Law Calculator | #54 (BE) / #55 (FE) | `ohms-law.md` | new build |
| Percentage | #30 (BE) / #31 (FE) | `percentage.md` | regeneration |

Per-calculator notes accrue in `docs/logs/iteration-0003/<calculator>.md` as builds land.
These files are disjoint (fan-out-safe).

---

## Outcome (filled at close, 2026-06-14)

### 1. The first multi-calculator parallel build — fan-out validated end-to-end

This is the first iteration to build **two calculators at once**, and it exercised the
**fan-out model** the whole experiment is designed around (`ARCHITECTURE.md §3.1`): four
build agents — BMI-BE, BMI-FE, Ohms-BE, Ohms-FE — each in its **own isolated worktree** on its
own branch, working concurrently and conflict-free because each owns its own calculator file
(no central registration, `CLAUDE.md` rule 3).

The merge ordering was the one real sequencing constraint, and it held cleanly:

- **Backend wave first** — `Calculators::Bmi` (#58) and `Calculators::OhmsLaw` (#57) merged
  at 07:57. Both regenerated from their `spec:v1` issue bodies (#52 / #54), reproduced their
  spec reference-value tables verbatim, and landed at 100% line + branch coverage.
- **Frontend wave second** — Ohms page (#60, 08:11) then BMI page (#62, 08:30). The FE wave
  *must* follow the BE wave because each page's system test renders **real backend results**
  over the §4 envelope; the math has to be on `main` first.

**The one collision, resolved additively.** Both FE agents needed to touch the same three
shared files — `app/views/calculators/_result.html.erb` (the result dispatcher),
`app/views/home/index.html.erb` (the catalog tiles), and
`app/helpers/calculators_helper.rb`. Ohms merged first; the **BMI FE branch was then rebased**
onto those changes and re-merged (#62). The resolution was **purely additive** — each
calculator added its own result-partial dispatch arm, its own catalog tile, its own helper
methods, none overwriting the other. This is exactly the shape the no-central-registration
rule predicts: the only contention is in genuinely shared dispatch/catalog files, and there it
resolves by appending, not rewriting. **The fan-out model is validated end-to-end** — parallel
multi-calculator builds work, and the shared-file seam is a managed rebase, not a rewrite war.

### 2. The headline learning — the mode-picker rule (convergence on the taste layer)

The durable learning this iteration did **not** come from a build miss the agents made on
their own; it came from **the user trying the live app**. Looking at the running BMI page, the
user observed the **US / Metric pills looked scrunched**.

**The diagnosis is the interesting part.** The instinct (after iterations 0001–0002) was
"spacing regression" — but it wasn't. Iteration 0002's spacing scale was **correctly applied**;
the pills had the right gaps. The problem was a **wrong-element** choice: a **2-option**
selector was being rendered as a wrapping pill row, and a 2-option toggle shouldn't wrap pills
at all. This surfaced a gap the design system had never pinned: **element choice is a separate
axis from spacing.** DESIGN.md (post-0002) could tell the agent *how much air* to give a
control, but not *which control* to reach for. No amount of spacing tuning fixes a control
that is the wrong shape for its option count.

**The fix went up into the agent layer (agent-first), then swept.** A frontend advisory
produced a **mode-picker rule**, codified in **`DESIGN.md §4` (new "Mode picker" entry) +
`.claude/agents/frontend.md`** (PR #64). The rule:

- A mode/variant picker is **always** a native radio `<fieldset>`/`<legend>` posting
  single-select `inputs[mode]` (no-JS-safe, accessible). Only the **presentation** varies,
  keyed on **count + label length**:
  - **N ≤ 3, short labels → segmented control** (one connected horizontal track).
  - **N ≥ 4, or any multi-word / long label → `.mode-option` selectable option list**
    (bordered, divided rows; leading radio glyph as a non-colour cue per §6; bold label +
    muted helper; active = accent inset rule + subtle tint).
  - Native `<select>` is **never** the primary picker — reserved for a genuinely long menu
    (N > ~8).

The rule was **prototyped on one calculator first** (Ohms, PR #63 — the option-list, validated
live) *before* codifying, then **swept across every calculator** once it was in DESIGN.md:

| Calculator | Picker | N | Result | PR |
|---|---|---|---|---|
| Ohm's Law | mode pair (vi/vr/…) | 6 multi-word | → **option list** | #63 (prototype) |
| Percentage | main mode | 5 multi-word | → **option list** | #66 |
| Percentage | Increase \| Decrease | 2 short | → **segmented control** | #66 |
| BMI | US \| Metric units | 2 short | → **segmented control** | #65 |

Net: **every calculator now uses one situation-appropriate picker**, and the rule is
**durable** — it lives in DESIGN.md + frontend.md, so the next sweep reproduces it and every
*future* calculator inherits the right control for free. This is the **convergence loop
demonstrated on the UI/taste layer**: a human eyeballing the running app → a rule encoded once
in the agent layer → propagated to all built calculators and all future ones. Iteration 0002
proved the loop on **spacing**; 0003 proves it on **element choice** — a second, distinct axis
of taste, closed the same way.

The sweep also re-confirmed the **agent-first durability** thesis: each picker conversion
reused the **existing** `.mode-option` / `.direction-pill` vocabulary (no new CSS class, no
`application.css` edit), so the sibling sweep agents stayed collision-free — and the native
radio / no-JS / a11y backbone survived every conversion untouched.

### 3. Bookkeeping honesty — this iteration is not a clean A/B

Iteration 0003 was **tagged at `0ca4a02`**, and per "What changed in the agents since iteration
0002" above, *no build-agent definition changed between 0002 and the open*. But the **agent set
evolved mid-iteration**: `frontend.md` (and `DESIGN.md §4`) **gained the mode-picker rule
during the iteration** (PR #64), in direct response to the BMI build the iteration had just
produced. So unlike iteration 0002 — a deliberately isolated, single-variable A/B (change the
spacing scale, hold everything else, measure) — **0003 is not a controlled experiment.** The
agent change here was *reactive*, discovered by building, not pre-planned to be measured.

That does not diminish the iteration; it just changes **what it is evidence of**. Its value is:

1. **Validating the parallel fan-out** — the multi-calculator, multi-layer concurrent build
   with a managed additive rebase at the shared seam (mechanics of the experiment, proven).
2. **Demonstrating the convergence loop on the taste layer** — observe-in-app → encode-once →
   propagate-to-all, on the *element-choice* axis (the loop, proven on a second axis).

The clean A/B measurement of the **picker rule itself** — does an agent, given only DESIGN.md
§4 + frontend.md, *independently* reach for the right picker on a fresh calculator it has never
seen? — is **deferred to a future iteration's regeneration sweep**, where the rule is part of
the *pinned* agent set from the open and the sweep is the controlled test. That is the honest
read recorded here so the experiment's evidence ledger stays accurate.

### Regeneration sweep note

The iteration's plan named a **Percentage regeneration sweep** (`percentage.md`) as standing
sweep evidence. In practice, Percentage *was* regenerated this iteration — but as part of the
**picker sweep** (PR #66 rebuilt its main selector to the option list and confirmed its
Increase|Decrease toggle as a segmented control), folding the sweep into the picker-rule
propagation rather than running it as a separate spacing re-measurement. The durable 0001/0002
fixes (label-based errors, hero result, the spacing scale) carried through that rebuild intact.
