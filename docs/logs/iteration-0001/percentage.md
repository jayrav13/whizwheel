# Percentage — iteration 0001

**Kind:** new build (the first calculator; no prior version to diff against).
**Spec:** issues #30 (`backend`) / #31 (`frontend`), identical `spec:v1` bodies.
**Source:** https://www.calculator.net/percent-calculator.html
**Complexity:** 3 (multi-mode). **Tags:** multi-mode, multi-input.

This is the first calculator built end-to-end by the agent-driven loop — spec → backend
math → page-serving seam → frontend page — and the first full `spec → build → measure`
turn of the experiment. It shipped across three merged PRs:

| Layer | Issue | PR | What it delivered |
|---|---|---|---|
| Backend (math) | #30 | #32 | `Calculators::Percentage`, 5 modes |
| Page-serving infra | #33 | #34 | `GET show` + `create respond_to(turbo_stream, json)` |
| Frontend (page) | #31 | #35 | The multi-mode page (Turbo + Stimulus + BLEND) |

---

## Backend — `Calculators::Percentage` (#30 → PR #32, merged)

**What the agent produced.** A single multi-mode calculator: a required `mode` selects one
of five operations (`percent_of`, `what_percent`, `percent_of_what`, `difference`,
`change`); the other inputs and the output key(s) depend on the mode. Full `BigDecimal`
precision (`:decimal` attributes per §10), reference-value tests lifted verbatim from the
spec across all five modes, plus validation cases. 100% line + branch coverage; rubocop +
brakeman clean.

**What was right.**
- **Conditional, per-mode validation.** Only the selected mode's required inputs are
  validated for presence (`required_inputs_present_and_numeric` drives off a
  `REQUIRED_INPUTS` table); `direction` is required/constrained only in `change` mode.
- **Division-by-zero as a 422, not an exception.** `what_percent` (v2≠0),
  `percent_of_what` (percent≠0), and `difference` (v1+v2≠0) guards are surfaced as
  validation errors through the §4 envelope — never raised. This matched the spec's explicit
  "validation failure, not a 500" instruction exactly.
- **Reference values reproduced verbatim** — no values invented or altered.

**Notable agent choices / flags.**
- **`send(:"compute_#{mode}")` dispatch (the reusable pattern).** `compute` dispatches to a
  per-mode `compute_<mode>` method rather than a `case/when`. The agent chose this
  *specifically* to avoid an unreachable `case/else` fallback branch: `mode` is validated
  into `MODES` before `compute` runs (it only runs when `valid?`), so a `case` with no
  `else` would have an uncovered path and a `case` *with* an `else` would have an
  unreachable branch — either way the 100% branch gate fails. The `send` table sidesteps
  both. **This is a reusable multi-mode pattern** and the strongest reusable artifact this
  build produced (see suggested change (c) below).
- **Numericality-vs-`:decimal` coercion limitation (flagged by the agent).** The spec asks
  for "presence + numericality," but ActiveModel `:decimal` attributes (mandated by §3.2)
  eagerly coerce a non-numeric string like `"abc"` to `0` and a blank `""` to `nil`, and a
  plain ActiveModel object exposes no `*_before_type_cast`. So truly garbage text is
  indistinguishable from `0` at validation time. The calculator therefore enforces
  **presence** (catches nil/blank) and leans on the type system to guarantee a numeric
  `BigDecimal`. This is an inherent property of the architecture's required attribute type,
  not a math gap — but it means "reject non-numeric text" would need a different attribute
  type or a custom caster, a `Base`-level decision. **Left as an open observation, not yet
  a queued change.**
- **Data observation — persisted `inputs` carries the whole attribute set.** `Base#to_record`
  persists `inputs: attributes`, i.e. the *entire* ActiveModel attribute hash. So a
  `percent_of` calculation row stores `{mode:"percent_of", v1:.., v2:nil, percent:..,
  direction:nil}` — the unused mode's fields ride along as `nil` (and `change` rows carry
  `direction:"increase"`). Benign today (history/stats just read it back), but worth
  remembering when the history/stats UI renders stored inputs: it will need to know which
  keys are meaningful for a given mode rather than dumping the whole hash.

---

## Page-serving infra — `GET show` + `create respond_to` (#33 → PR #34, merged)

**What the agent produced.** The FE/BE seam (infrastructure, *not* a calculator) that makes
calculators visitable and Turbo-submittable while preserving the persistence side effect.

- **`GET /calculators/:slug` → `CalculatorsController#show`** — one dynamic route mirroring
  the existing POST (no per-calculator routes; class looked up via `Calculators::Base.lookup`,
  `head :not_found` for an unknown slug).
- **`create` gains `respond_to`** — a `turbo_stream` branch (renders the FE result fragment)
  alongside the unchanged §4 JSON envelope branch.
- **Format-agnostic persistence (the right call).** `record.user = Current.user;
  record.save` happens in the valid branch **before** `respond_to`, so a Turbo submit records
  the `Calculation` exactly like a JSON submit (and stays swappable for
  `RecordCalculationJob`, §5). Invalid input → 422 in both formats.

**Notable.**
- **Deliberate 406 contract-narrowing.** With `respond_to` now gating formats, a bare POST
  with no `Accept` header (and no `turbo_stream`/`json` match) now returns **406** rather
  than defaulting to a format. This is an intentional, documented narrowing of the contract,
  not a regression — clients must ask for a format they're served.
- **Seam respected without crossing it.** The agent covered the `show` and `turbo_stream`
  render branches for the 100% gate via functional controller tests that prepend a test-only
  view path (`test/support/views/`) with minimal `TestDouble` stubs — so the action runs
  end-to-end and every `respond_to` branch is exercised without writing the real (frontend's)
  views. Clean boundary discipline.

---

## Frontend — the Percentage page (#31 → PR #35, merged)

**What the agent produced.** The real, polished multi-mode page to the BLEND design system,
coded against the page-serving seam: a tab-pill mode selector (5 modes), per-mode inputs
(`v1`/`v2`/`percent`), the increase/decrease segmented toggle for `change` mode, a Turbo
form (`POST /calculators/percentage`, `scope: :inputs`), a `create.turbo_stream.erb` +
`_result.html.erb` (shared empty/error states, per-slug result dispatch with a generic
envelope fallback), a `results/_percentage.html.erb` hero-result card, a Stimulus
`percentage_controller.js` for progressive mode-switching, display-only helpers, and
`@layer` component classes (`field-input`, `mode-pill`, `direction-pill`).

**What was RIGHT.**
- **On-system and complete.** Warm cream bg, rounded surface cards with the soft shadow,
  green-as-a-touch (eyebrows, active mode pill, RESULT label), coral leads (Calculate, hero
  left-rule, error tint), tabular hero numbers, two-column layout. All states correct
  (default / result / change / error).
- **Works with JS off.** Progressive enhancement — the server validates only the chosen
  mode's required inputs, so the page degrades gracefully.
- **Caught its own bug in self-review.** The FE agent's screenshot self-review found and
  fixed a Stimulus-target bug before merge — the review loop demonstrably works for *render
  correctness*.
- **Generic seam, kept honest.** `_result` dispatches per-slug with a generic envelope
  fallback, so the shared `create.turbo_stream.erb` works for any future calculator (and the
  test double) the moment its math + page exist — a frontend-side decision that doesn't
  require a backend change.

**The KEY MISS — cramped pills + a self-review that rubber-stamped them.**
- The **mode pills came out cramped** (bunched, especially when the row wraps).
- Crucially, **the FE agent's screenshot self-review declared them "roomy" when they were
  not** — a *miscalibrated spacing bar*. This is the more important failure: the review loop
  catches functional bugs (it caught the Stimulus one) but does **not** reliably catch
  *spacing/breathing* problems, because the agent had no concrete spacing standard to judge
  against and graded generously.
- The in-flight remedy (commits `2ef2315` → `346eda9`) bumped the pill group to `gap-2.5`
  via DESIGN.md, but **that tweak was too timid** — a "`gap-2.5` minimum" floor is a single
  magic number, not a spacing *system*. The real fix (a proper spacing scale) is being
  designed for iteration 0002.

**Also right — the error-label fix went through DESIGN.md, not the page.** Validation errors
originally rendered raw attribute keys ("v1 can't be blank"). The fix phrases them against
each field's visible label ("Value (V1) can't be blank") via a new
`CalculatorsHelper#calculator_error_messages` (maps error key → rendered label, shows `:base`
whole-record errors as full sentences, humanized fallback for unmapped calculators). Correctly
encoded in **DESIGN.md §4** (commit `2ef2315`) so it survives the regeneration sweep — exactly
the agent-first discipline the experiment wants.

---

## Misses → suggested durable changes (where each fix belongs)

| # | Miss / observation | Durable change | Where it belongs | Status |
|---|---|---|---|---|
| a | Mode pills cramped; the `gap-2.5` floor is a timid magic number, not a system. | A real **spacing scale** in DESIGN.md (named steps for inline-group gaps, not a "≥`gap-2.5`" minimum). | `docs/DESIGN.md` | **In design now for iteration 0002** — the headline investment of the next agent edit. |
| b | The FE screenshot self-review declared cramped pills "roomy" — a miscalibrated bar. | Give `frontend.md`'s self-review **teeth**: concrete spacing/breathing checks tied to the new scale, so it stops rubber-stamping bunched layouts. | `.claude/agents/frontend.md` | **Deferred** — pairs with (a); a scale to grade against must exist first. |
| c | The `send(:"compute_#{mode}")` multi-mode dispatch (chosen to dodge the unreachable-branch 100%-gate problem) is a reusable pattern living only in this one calculator's code. | Carry the **`send`-dispatch multi-mode pattern** in the backend agent so every multi-mode calculator gets it (and isn't re-derived each time). | `.claude/agents/backend.md` | **Deferred.** |
| d | The FE agent watched its own CI run during the build. | None — benign and accepted. | — | **No change** (accepted). |

**Not yet queued (open observations, not decisions):** the numericality-vs-`:decimal`
coercion limitation (would need a `Base`-level caster/attribute-type decision), and the
whole-attribute-set `inputs` persistence (matters for the future history/stats UI, harmless
now).

---

## Iteration takeaway

Percentage proved the loop end-to-end: a `spec:v1` issue body drove a correct, fully-tested
multi-mode calculator, a clean FE/BE seam, and an on-system page — with the backend nailing
the math/validation contract and the frontend nailing render correctness and BLEND fidelity.
The single sharp lesson is **spacing**: the cramped pills, and worse the self-review that
*missed* them, expose that the design system has no real spacing scale and the FE review has
no spacing bar to grade against. That is the explicit charge of **iteration 0002**: invest in
a DESIGN.md spacing system (and, following it, sharpen the FE self-review). The `send`-dispatch
backend pattern is the build's best reusable artifact and is queued to move up into
`backend.md`.
