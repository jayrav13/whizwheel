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

**Build status:** _pending._

---

## Backend (#79)
_— pending build. **Watch:** how the agent exposes the list input (single `:string` attr + parse
in compute/validation) and whether multimodal/no-mode are handled per the reference rows._

## Frontend (#80)
_— pending build. **Watch:** how it renders the `mode` array (e.g. "23 and 38" / single / "No mode")._

## Misses → agent-change candidates
_— pending._
