# Ohms Law Calculator — iteration 0003 (new build)

**Kind:** new build (backend + frontend).
**Spec:** issues #54 (`backend`) / #55 (`frontend`) — identical `spec:v1` body.
**Source:** https://www.calculator.net/ohms-law-calculator.html
**Pinned agent SHA:** `0ca4a02`.
**Complexity / tags:** 2 — multi-input, multi-mode, physics.

What this calculator stresses for the experiment:
- A **six-mode "any two of four"** solver (V/I/R/P) — a broader multi-mode surface than
  Percentage's, with **conditional input presence** (only the two named by `mode` are
  required) and **all four quantities always returned**.
- **Division-by-zero guards** (e.g. `vi` with `current=0`) and one **square-root mode**
  (`rp`). Tests whether the agents handle guarded math and the 100% coverage gate across six
  branches.

**Build status:** **shipped.** Backend #54 → **PR #57** (merged); frontend #55 → **PR #60**
(merged). Both issues closed. Ohms FE merged **before** BMI FE, so it landed the shared-file
(`_result.html.erb` / `home/index.html.erb` / `calculators_helper.rb`) changes that BMI FE then
rebased onto — additively.

---

## Backend (#54) — PR #57

The backend agent regenerated `Calculators::OhmsLaw` from the `spec:v1` body of #54. What it
produced:

- **Six-mode "any two of four" solver, dispatched cleanly.** `mode` ∈ {vi, vr, vp, ir, ip, rp}
  selects which two of V/I/R/P the user supplies; the calculator solves the other two and
  **always returns all four** under `result` (the §4 shape the FE highlights). Dispatch via
  `send(:"compute_#{mode}")` — the multi-mode pattern Percentage established (`ARCHITECTURE.md
  §3.2`), now exercised at a wider fan-out (6 branches).
- **Conditional input presence** handled — only the two inputs the mode names are required; the
  other two are ignored on input and recomputed as outputs.
- **Guarded math, no exceptions.** Division-by-zero → **422 validation error, never a 500**
  (e.g. `vi` with `current = 0` ⇒ `R = V/0`). The **valid-zero** case is distinguished correctly
  (`ir` with `resistance = 0` ⇒ `V = 0, P = 0`, no division — a *success*, not an error). The
  **`rp` square-root** mode (`I = √(P/R)`) guards the `P/R ≥ 0` domain and computes at full
  `BigDecimal` precision (irrational-root precision case tested).
- **Reference-value table reproduced verbatim** — all 9 rows, every mode, asserting all four
  solved quantities each; plus the cross-mode `12V/2A/6Ω/24W` consistency check via vi/ip/vp.
  Controller integration test covers the 200s, the valid-zero success, and the 422 div-by-zero
  path (records nothing).
- `bin/rails test` → **100% line (252/252) + branch (88/88)**, rubocop + brakeman clean.
  Backend-only, no UI files.

**Backend verdict:** an excellent stress of the multi-mode pattern — six branches, guarded
division, a square-root domain, and the valid-zero / invalid-zero distinction, all reproduced
exactly with the coverage gate satisfied. No miss worth an agent change. This widens the
evidence that the `send`-dispatch multi-mode pattern + §10 precision discipline scale beyond
Percentage's surface.

## Frontend (#55) — PR #60

The FE agent built the Ohms page to BLEND from spec #55:

- **Multi-mode page** — the picker selects the input **pair**; only that pair's two of V/I/R/P
  show, and the page solves the other two. Inputs carry SI-unit affixes (V/A/Ω/W) on the Affix
  tier. Stimulus controller is pure progressive enhancement (reveals the chosen pair, disables
  the hidden fields so they aren't submitted); works without JS over Turbo.
- **Result render** — a coral-ruled hero holding the full **V/I/R/P** set in fixed order; the
  two **solved** quantities highlighted accent-green with a "Solved" badge, the two **given** echo
  back muted with a "Given" badge. The given/solved distinction is carried by a **visible text
  tag, never colour alone** (a11y, DESIGN §6). A strong answer to "show all four while
  highlighting the solved pair."
- Tests: integration (six modes, the `rp` square-root branch, given/solved tagging, label-led
  422s, div-by-zero as a validation error not a 500), helper units, system + full-page
  screenshots reviewed against DESIGN.md. 100% line + branch.

**Shared-file seam.** Ohms FE merged first of the two FE PRs, so it introduced this iteration's
additions to the three shared files (`_result.html.erb` dispatch arm, `home/index.html.erb`
catalog tile, `calculators_helper.rb` helpers). BMI FE rebased onto these — the contention
resolved **additively** (each calculator appends its own arm/tile/methods). This is the managed
seam the no-central-registration rule predicts.

## The picker feedback (Ohms was the prototype that codified the rule)

When the user's BMI observation surfaced the **element-choice** axis, **Ohms Law was the
calculator chosen to prototype the fix** — its mode picker has **6 multi-word options**
(Voltage & Current, …), the clearest case for the option-list end of the rule:

- **PR #63 (prototype)** replaced *only* the Ohms mode picker's presentation with a new
  **`.mode-option` selectable option list** — one bordered, row-divided container; each row a
  leading radio glyph (non-colour active cue) + bold mode label + a one-line helper naming what it
  solves. The native radio `<fieldset>` / `peer sr-only` / no-JS painting / Stimulus hooks were
  **untouched** — only the markup shape changed. Reviewed live before codifying.
- That prototype validated the pattern, which was then **codified** into `DESIGN.md §4` +
  `frontend.md` (**PR #64**) as the general **mode-picker rule** (N≥4/multi-word → option list;
  N≤3/short → segmented control), and **swept** to Percentage (#66) and BMI (#65).

So Ohms played a special role: not a miss it *suffered*, but the **prototype surface** on which
the rule was proven before being lifted into the agent layer. Full rule + sweep table in
`README.md`.

## Misses → agent-change candidates

- **No backend miss.** The six-mode guarded solver was reproduced exactly at 100% coverage —
  evidence the multi-mode + §10 precision patterns scale.
- **[RESOLVED — picker rule]** Ohms' 6-option mode picker was the **prototype** (PR #63) that
  validated the `.mode-option` option list, codified into DESIGN.md §4 + frontend.md (PR #64).
  Not a defect Ohms shipped with for long — it was the deliberate proving ground for the rule.
- **[OPEN — deferred, shared with BMI]** Clean A/B of the picker rule (does an agent reach for
  the right picker unprompted on a fresh calculator?) belongs to a future regeneration sweep where
  the rule is in the *pinned* agent set — this iteration encoded it *reactively*, so it is not a
  controlled measurement.
