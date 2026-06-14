# Iteration 0003

**Status:** open
**Opened:** 2026-06-14
**Closed:** —
**Pinned agent SHA:** `0ca4a02` (`main` HEAD at open)
**Tag:** `iteration-0003`
**Calculators:** BMI Calculator (#52 BE / #53 FE), Ohms Law Calculator (#54 BE / #55 FE) — **2 new builds**; plus the regeneration sweep of every prior calculator.

**Headline outcome:** — _(filled at close)_

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
