## Chapter 111 — Iteration-0006 opens: six calculators, an empty regen set, twelve issues (2026-06-15)

With `#182` merged and the post-harvest agent set pinned at `7f15521`, the operator's instruction from Chapter 110 — *"let's begin the iteration now please"* — came due. This chapter records the open: the grounding, the deliberately-empty regen set, the PM authoring six spec bodies, and the twelve issues filed.

**Grounding the iteration number and the regen scope.** The orchestrator confirmed tags run through `iteration-0005`, so this is `iteration-0006`, with 8 calculators live (age, amortization, bmi, mmr, ohms_law, percentage, simple_interest, tip). The key scoping call was the regen set, and it landed **empty** on a clean rationale: *"the harvest already propagated to the existing calculators (the #143 PR migrated all 7 stat-grid views; #109/#110 is shared `Base` so it auto-applies to all). So the regen set can be empty — this is a clean new-build iteration."* This is the lifecycle working as documented: the harvest-first sequencing of Chapter 107 meant the harvested fixes had *already* swept the priors during the harvest itself, so iteration-0006 carries no regen — purely six new builds. It takes the catalog from **8 → 14 live calculators**.

**The open, in four steps.** The orchestrator laid out the sequence: (1) the PM opens iteration-0006, defines scope, opens the log, and authors the 6 `spec:v1` bodies → PR; (2) the github-agent files the 12 issues (backend + frontend per calc) from the PM's specs; (3) build fan-out, backend-before-frontend per calc, Loan → Mortgage → rest, each PR gated by QA; (4) the `iteration-0006` tag applied at the post-harvest SHA. The tag went on at `7f15521` (pin-at-open), capturing *"the post-harvest agent set."*

**The PM authored the six specs deterministically.** Dispatched to open the iteration, the PM returned `PR #183` (branch `docs/iteration-0006-open`) — the iteration log plus six `spec:v1` bodies under `docs/logs/iteration-0006/specs/`. The six, with their shapes, as the PM summarized them:
- **Loan** (Financial, Cx4, multi-mode) — amortized loan, mode picker solves-for payment / amount / term; full schedule; recurrence `M = P·r(1+r)ⁿ/((1+r)ⁿ−1)`.
- **Mortgage** (Financial, Cx5, charts) — single-mode home mortgage = loan core + tax/insurance/HOA add-ons; P&I + total_monthly + schedule + donut/balance chart.
- **Compound Interest** (Financial, Cx4, multi-mode) — `A=P(1+r/m)^(mt)`, compounding-frequency picker, growth_series chart.
- **Standard Deviation** (Math, Cx3, multi-mode) — list input + population/sample segmented picker; mean/variance/SD/count/sum, 6dp.
- **Right Triangle** (Math, Cx3, multi-mode) — solve-from legs (a,b) / leg+hyp (a,c); third side, both angles, area, perimeter, altitude, 6dp.
- **Date** (Other, Cx3, multi-mode) — difference / add-subtract; total_days + Y/M/D + weeks, or result_date with leap-aware end-of-month clamping.

The PM noted all reference values were *"PM-computed deterministically (verified via Python `decimal`/calendar arithmetic)"* and that the loan-family totals use *"the schedule-reconciled recurrence matching the Amortization spec already on `main`."* (One of those references later proved to sit on a numerical razor's edge — Chapter 112 — but the deterministic-computation discipline is what let the build agent *catch* it.)

**Twelve issues, filed clean.** With the specs authored, the github-agent filed all 12 build issues — backend + frontend for each calculator — *"cleanly (no dedupe hits)."* The PM picked up the live issue numbers and recorded them in the iteration log's per-calculator table, pushing a second commit to `#183`:

| Calculator | backend | frontend |
|---|---|---|
| Loan | #184 | #185 |
| Mortgage | #186 | #187 |
| Compound Interest | #188 | #189 |
| Standard Deviation | #190 | #191 |
| Right Triangle | #192 | #193 |
| Date | #194 | #195 |

**A near-miss the orchestrator caught.** The PM's log-update return came back referencing `#184`–`#195` *as already filed* — but the orchestrator had *also* dispatched its own github-agent to file the same 12 in parallel, risking duplicates. It stopped to verify: *"the PM's log update references issues #184–#195 as already filed, but I also dispatched my own github-agent to file the same 12 — which risks duplicates. Let me check the real GitHub state immediately."* The check came back clean — *"exactly 12 issues (#184–#195), no duplicates (the dedupe scan held; the PM picked up the numbers and recorded them in #183's log)."* The dedupe scan in the github-agent's filing path absorbed the double-dispatch without producing dupes.

**Agent/doc-driven? ✅ — a textbook lifecycle open.** The PM ran the open (log + scope + the six spec bodies with deterministic references), the github-agent filed and labeled the twelve issues with a working dedupe scan, and the empty regen set followed directly from the harvest-first design of the prior chapters. The one human-judgment beat was the orchestrator's duplicate-check reflex — a parallel double-dispatch that the agent-layer dedupe handled, but which the orchestrator verified rather than assumed. The iteration is open and pinned; the build fan-out is next.

---
