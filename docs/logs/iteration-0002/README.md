# Iteration 0002

**Status:** closed
**Opened:** 2026-06-13
**Closed:** 2026-06-13
**Pinned agent SHA:** `1e18ce2` (`main` HEAD at open — carries the new DESIGN.md spacing scale)
**Tag:** `iteration-0002`
**Calculators:** Percentage (regeneration sweep — **frontend** only; spec #31)

**Headline outcome:** Spacing scale validated by regeneration — the Percentage page,
regenerated from spec + the new DESIGN.md alone (prior page unread, zero human pixels;
PR #41), came out with **visibly roomier mode pills** (Grouped-wrapping `gap-x-3 gap-y-4`),
while the durable 0001 fixes (label-based errors, hero result) held through the rebuild. This
is the **first confirmation of the agent-improvement loop** — a doc-only agent change alone
produced measurably better output via the sweep. The bisect points to **DESIGN.md, not the FE
self-review**, as the lever (the review was adequate once it had a standard to grade against).
Strong single-sample signal, not proof. See `percentage.md`.

---

## What this iteration is

This is a **regeneration sweep, not a new-calculators iteration** (`n = 0` new builds). Its
sole purpose is to **regenerate the Percentage page with the improved agent set** and measure
what the agent change produced — the controlled, agent-first test the experiment is built on:
the fix from iteration 0001 was pushed *up into DESIGN.md* (the spacing scale), and the sweep
checks whether that guidance alone makes the agent produce good spacing.

## Why this SHA

Pinned to **`1e18ce2`** — the current `main` HEAD at open. It is the merge commit of PR #38
(`docs/spacing-scale`), which lands `08b83ef` — the DESIGN.md spacing scale that **is** this
iteration's agent change. We pin the boundary at HEAD because that is the fully-ingested,
clean state the iteration opens against, and it carries the new DESIGN.md.

## What changed in the agents since iteration 0001 (the delta under test)

Iteration 0001 was pinned to `c7796eb`. The **only** change to the agent set since then is in
**`docs/DESIGN.md`** — and it is **FE-facing guidance only**:

- **DESIGN.md gained a real spacing scale** (`08b83ef` / PR #38) — a *relationship-based
  rhythm* (closer = more related), with named tiers keyed by **what the gap separates**:
  **affix** (`gap-2`), **grouped** (`gap-3`), **grouped-wrapping** (`gap-x-3 gap-y-4`),
  **stacked** (`space-y-5`), **section** (`mt-7`–`mt-8`), **layout** (`gap-8`, `p-6`–`p-8`).
  Framed as **targets, not minimums** ("when unsure, go one step *more* open").
- Two rules travel with the scale: **(1)** a wrapping control group gets a **larger row-gap
  than column-gap** (`gap-y` > `gap-x`) so wrapped rows read as a grid, not a clump; **(2)**
  tappable **chips/pills need air** to read as distinct, separately-hittable targets.
- **§4 Tab pills** now point at the **Grouped-wrapping** tier (**`gap-x-3 gap-y-4`**),
  replacing the old vague *"generous"* + the **timid `gap-2.5` minimum** floor.

This directly answers iteration 0001's key miss: the mode pills came out cramped **and** the
FE self-review declared them "roomy" — DESIGN.md gave no spacing scale to reason from, and a
*floor* (a single magic number) invited the least. A real scale gives the agent a rhythm to
produce good spacing from the guidance alone.

## Why Percentage **frontend** is the meaningful regeneration

The agent change is **FE-facing only** (DESIGN.md). The **backend math is unchanged** at this
SHA, so regenerating `Calculators::Percentage` from spec #30 would be a **no-op signal-wise**
— it would produce the same math against the same `spec:v1`, carrying no information about the
agent change. The iteration's evidence is therefore the **Percentage frontend page**
(spec #31): does the page regenerated under the new spacing scale come out with roomy,
breathing mode pills (Grouped-wrapping `gap-x-3 gap-y-4`) — without the in-flight `gap-2.5`
hand-tweak from iteration 0001 — purely from the improved DESIGN.md?

The deferred companion change — giving `frontend.md`'s self-review *teeth* against the new
scale (iteration 0001 miss (b)) — is **not** part of this SHA; this sweep first measures
whether the scale alone moves the output, before adding review teeth.

## What this iteration builds

- **n = 0 new calculators.** No new selections; no new issues created.
- **Regeneration sweep:** **Percentage — frontend** (spec #31), regenerated from spec under
  `1e18ce2`. The delta from the prior FE version (PR #35, the cramped pills + the
  `2ef2315`→`346eda9` `gap-2.5` tweak) is this iteration's core data.

## Per-calculator notes

| Calculator | Issue | File | Kind |
|---|---|---|---|
| Percentage | #31 (FE) | `percentage.md` | regeneration (frontend) |

Per-calculator notes accrue in `docs/logs/iteration-0002/percentage.md` as the regeneration
lands.
