# BMI Calculator — iteration 0003 (new build)

**Kind:** new build (backend + frontend).
**Spec:** issues #52 (`backend`) / #53 (`frontend`) — identical `spec:v1` body.
**Source:** https://www.calculator.net/bmi-calculator.html
**Pinned agent SHA:** `0ca4a02`.
**Complexity / tags:** 2 — multi-input, health, unit-conversion.

What this calculator stresses for the experiment:
- A **unit-system mode** (`us` vs `metric`) where the mode changes the *meaning* of the
  `weight`/`height` inputs (and the `703 ×` factor), not just which formula branch runs.
- A **derived text output** (`category`, the WHO band) returned alongside the numeric `bmi` —
  the first calculator with a non-numeric result key.

**Build status:** **shipped.** Backend #52 → **PR #58** (merged); frontend #53 → **PR #62**
(merged, rebased onto the Ohms FE shared-file changes). Both issues closed.

---

## Backend (#52) — PR #58

The backend agent regenerated `Calculators::Bmi` from the `spec:v1` body of #52 (not from
prior code — there was none; this is a new build). What it produced:

- **Two formula families behind one scale.** `unit_system` selects
  `BMI = 703 × weight_lb / height_in²` (US) vs `BMI = weight_kg / (height_cm/100)²` (metric);
  both resolve to the same kg/m² number, so the WHO bands apply uniformly across modes. This is
  the "mode changes input *meaning*, not just the branch" pattern the iteration meant to stress —
  handled cleanly.
- **The derived-text output landed correctly.** `category` (the WHO band) is the project's
  **first non-numeric result key**, returned alongside the numeric `bmi`. The agent derived the
  band from the **raw, unrounded** BMI over `[lower, upper)` half-open intervals while displaying
  `bmi` rounded to 1 dp (§10) — and tested the **raw-vs-display seam explicitly** (24.95 displays
  as 25.0 but stays `Normal` because the raw value is below the 25.0 boundary). That is the subtle
  correctness trap on this calculator, and the agent caught it without prompting.
- **Reference-value table reproduced verbatim** — all 8 rows across both modes, plus the
  boundary-band cases (18.5 → Normal, 25.0 → Overweight, 40.0 → Obese Class III) and the
  cross-mode consistency check. Validation (presence / numericality / inclusion) covered.
- **100% line + branch coverage**, rubocop + brakeman clean. Adds only `app/calculators/bmi.rb`
  + its test — no shared files (no central registration, §3).

**Backend verdict:** a clean new build. The agent handled both the meaning-changing mode and
the first derived-text output with no miss worth an agent change. The raw-vs-display band
discipline is a good signal that the §10 rounding guidance is landing.

## Frontend (#53) — PR #62

The FE agent built the BMI page to BLEND from spec #53, rendering the `bmi` + `category` keys
as a **richer-than-single-number** result:

- **The result render is a highlight.** The coral-ruled hero holds the big `tabular-nums` BMI,
  a green **category badge** (the WHO band), and a **WHO classification scale** — a thin stacked
  bar + text legend with the active band lifted to accent green and a marker pinning the exact
  BMI. Classification never relies on colour alone (DESIGN §6). This is a strong answer to "how do
  you surface a derived-text output next to a number" — the band is shown as *position on a scale*,
  not just a word.
- **Unit-system UX.** A shared **weight** field whose affix swaps `lb ↔ kg`; US offers
  friendly **feet + inches** helpers summed into a canonical total-inches field over a no-JS
  baseline, metric a single **cm** field. The `bmi_controller.js` is progressive-enhancement only
  — the form works fully without JS.
- Tests: helper units, integration render/state, system test + 4 full-page screenshots,
  reviewed against DESIGN.md. 100% line + branch.

**The miss — and it's the iteration's headline.** The page shipped (#62) with the **US / Metric
unit selector rendered as a wrapping `.mode-pill` row** — and on the live app **those two pills
looked scrunched.** Crucially, this was **not** a spacing-scale failure: the iteration-0002
spacing scale was applied correctly. It was a **wrong-element** choice — a **2-option** selector
should never be a wrapping pill row in the first place. See the picker arc below; the BMI unit
selector was the calculator that *surfaced* the gap.

## The picker feedback (the cross-calculator learning BMI triggered)

The user, trying the running app, flagged BMI's scrunched US/Metric pills. Diagnosis:
**element choice is a separate axis from spacing**, and DESIGN.md pinned the latter but not the
former. The fix went **up into the agent layer** — the **mode-picker rule** in `DESIGN.md §4` +
`frontend.md` (PR #64) — then swept. For BMI specifically:

- **PR #65** converted the US / Metric unit selector from the wrapping `.mode-pill` row to a
  **segmented control** (N≤2, short labels → one connected, bordered track), reusing the existing
  `.direction-pill` vocabulary Percentage already used — **no new CSS class, `application.css`
  untouched**, so it stayed collision-free with the sibling sweep agents. The native radio
  `<fieldset>` / `peer sr-only` / no-JS painting / `bmi_controller` hooks all carried over
  **unedited**; only the markup shape changed. New integration assertion + screenshots (20–23)
  capture the un-scrunched selector.

So the BMI build is what *exposed* the missing axis, and the BMI unit selector is one of the two
calculators (with Percentage's Increase|Decrease) that the rule resolved to the **segmented**
side. Full rule + sweep table in `README.md`.

## Misses → agent-change candidates

- **[RESOLVED this iteration] Wrong-element picker.** BMI's 2-option unit selector was a
  wrapping pill row → looked scrunched. **Not** a spacing bug — an element-choice bug. Fixed by
  the **mode-picker rule** (DESIGN.md §4 + frontend.md, PR #64) and applied to BMI as a segmented
  control (PR #65). Durable: future calculators inherit the rule.
- **[OPEN — deferred to a future controlled sweep]** Does an agent given *only* DESIGN.md §4 +
  frontend.md **independently** reach for the right picker on a fresh, unseen calculator? This
  iteration's picker fix was *reactive* (encoded mid-iteration), so it is **not** a clean A/B.
  The controlled test is a future regeneration sweep where the rule is part of the pinned agent
  set from the open.
