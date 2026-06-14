# Mean·Median·Mode·Range Calculator — iteration 0004 (new build)

**Kind:** new build (backend + frontend).
**Spec:** issues #79 (`backend`) / #80 (`frontend`) — identical `spec:v1` body.
**Source:** https://www.calculator.net/mean-median-mode-range-calculator.html
**Pinned agent SHA:** `3f2ac29`.
**Complexity / tags:** 3 — statistical, text-output.

What this calculator stresses for the experiment:
- The project's **first variable-length list input** — a numbers string parsed (split on commas
  and/or whitespace) into a `BigDecimal` list, with non-numeric tokens rejected via a **label-based
  validation error**, not silently dropped. Tests how the agents model "one attribute, many
  values" within the ActiveModel `attribute` contract.
- A **non-scalar output key** — `mode` is an **array**: empty (all-unique → "no mode"), one element
  (unimodal), or many (multimodal). Tests both the BE result shape and the FE render of a key that
  isn't a single number.

**Build status:** ✅ built & merged — **BE [#90](https://github.com/jayrav13/whizwheel/pull/90)** (`Closes #79`) · **FE [#102](https://github.com/jayrav13/whizwheel/pull/102)** (`Closes #80`).

---

## Backend (#90) — **first variable-length list input: PASS**
Built from spec #79 under `3f2ac29`. The list input was modeled as a single `:string` attribute
parsed (split on commas/whitespace) into a `BigDecimal` list, with non-numeric tokens rejected via a
**label-based validation error** rather than silently dropped. The **non-scalar `mode` output**
(empty / one / many) was handled per the reference rows. The "one attribute, many values" shape fits
within the ActiveModel contract cleanly.

## Frontend (#102)
Built from spec #80. Renders the `mode` array in its three cases (no mode / single / multimodal).
**However it shipped WITHOUT a home catalog card** — caught only at merge time and patched in by a
follow-on commit during the serial FE pipeline (`d9ee471`, "add MMR home catalog card").

## Misses → agent-change candidates
- **#108 (`agents`) — frontend agent must guarantee per-calculator "registration" steps.** MMR
  shipping without a home card exposed that the FE agent treats the home-page card / dispatch / label
  map as ad-hoc rather than a required checklist item per calculator. Filed for an agent-definition
  fix so the per-calc registration set is guaranteed, not remembered.
