## Chapter 126 — Twenty build issues filed, Income Tax re-pinned to 2025, and Wave 1 fans out: seven backends in parallel (2026-06-16)

With the iteration log and all 10 specs on `main` (Chapter 125, `0e99688`), the build line was finally unblocked. This chapter records the launch of iteration-0007's actual *work*: the 21 issues filed, a live operator change to the one deliberate new primitive, and the first wave of seven parallel backend builds — the 2× fan-out the round was conceived to stress-test (Chapter 117). It is also the chapter that **rolls the journey into Volume 06** (chapter 126 is the first chapter past volume-05's 25-chapter cap).

### Twenty-one issues, zero dedupe hits

The `github-agent` read the 10 spec:v1 bodies from the PM's branch and filed all 20 per-calculator build issues (a backend and a frontend issue per calculator, each carrying the full verbatim spec body) plus one engineering follow-up. Its dedupe scan came back clean:

> **"Zero hits across all 77 existing issues. None of the 10 calculator names appeared in any open or closed issue. No issues were skipped."**

The resulting issue map — the backbone the rest of the round is dispatched against:

| Calculator | backend | frontend |
|---|---|---|
| Auto Loan | #241 | #251 |
| Sales Tax | #242 | #252 |
| Pythagorean Theorem | #243 | #253 |
| Discount | #244 | #254 |
| VAT | #245 | #255 |
| Personal Loan | #246 | #256 |
| Average Return | #247 | #257 |
| ROI | #248 | #258 |
| House Affordability | #249 | #259 |
| Income Tax | #250 | #260 |

Backend issues labeled `backend`, frontend issues labeled `frontend` — the per-layer build-line taxonomy from CLAUDE.md, applied at 2× volume in one filing pass. The twenty-first issue, **#261** (`engineering`), captured the recurring tooling miss: *"`bin/ci-watch` returns NO-RUN (rc 3) for live/green runs (seen on PR #239)."* That this had to be filed at all — after the #224 SHA-resolution fix supposedly closed it — is a small piece of "does this work?" evidence in its own right: the QA gate's tooling has a resolution gap that survives a fix, the gate absorbs it by falling back to `gh`, and the system *captures* the recurrence as a tracked issue rather than letting it dissolve into noise.

### The Income Tax re-pin: 2025, not the PM's 2024

The PM's Open (Chapter 124, relayed in #240) had flagged a single judgment call for the operator's eye — the bracket schedule for Income Tax, the one deliberate new primitive of the round:

> **"Income Tax bracket schedule (the one new primitive) — I pinned the **2024 US federal single-filer ordinary-income brackets** (10/12/22/24/32/35/37% at 11,600 / 47,150 / 100,525 / 191,950 / 243,725 / 609,350) … If you'd prefer a different year/filing status, that's the one knob."**

The operator turned that knob. Where the PM had pinned 2024, the operator directed **2025**. This is the round's single conscious capability nudge (Chapter 117 — Income Tax was kept in scope precisely *because* it introduces bracket/piecewise math), and the operator chose to exercise the new primitive against the most current tax year. The orchestrator absorbed the change without disrupting the critical path, and was careful about *timing* it against the in-flight issue filing to avoid a torn read:

> **"the `github-agent` is mid-flight reading the spec files right now, so to avoid a torn read I'll do the 2025 revision the moment it finishes filing, then patch the two Income Tax issue bodies. Income Tax is a *parallel* build (not first in the order), so this adds **zero delay** to the critical path."**

The mechanism: the PM is re-dispatched (a separate docs branch off `main`) to **recompute the 2025 single-filer brackets and all the reference values** — the bracket sum, per-bracket breakdown, and the effective/marginal rates that the backend's tests will check against — then those values sync into issues #250 (backend) and #260 (frontend) before the Income Tax build runs. Because Income Tax sits *late* in the dependency order (it depends on no other calculator and is held until its re-pin lands), the recomputation overlaps the other nine builds and costs the round nothing. The discipline is notable: a live change to a reference-value table is routed through the *spec* (the issue body) and the *PM* (the spec author), not patched into calculator code after the fact — the spec stays the source of truth even mid-flight.

### Wave 1: seven backends in parallel

With #240 merged and the issues filed, the orchestrator launched **Wave 1** — the first parallel fan-out of backend builds, each in its own worktree, each building from its issue spec, each PR set to close its issue:

> **"Now fanning out **Wave 1: 7 backends in parallel** — Auto Loan (keystone, re-establishes the loan core) + the 6 fully-independent ones. Holding Personal Loan + House Affordability for Auto Loan's backend merge (loan-family inheritance, per plan); Income Tax waits on the 2025 re-pin."**

The seven, and what each recombines (the precondition the round depends on — that nine of the ten are genuine recombinations of existing primitives):

| Backend build | Issue | Reuses |
|---|---|---|
| Auto Loan (keystone) | #241 | loan core |
| Sales Tax | #242 | solve-for-X |
| VAT | #245 | solve-for-X (twin) |
| Pythagorean Theorem | #243 | right_triangle |
| Discount | #244 | percentage |
| ROI | #248 | percentage |
| Average Return | #247 | stat-list |

**Auto Loan is the keystone** — dispatched first to re-establish the loan core that **Personal Loan (#246)** and **House Affordability (#249)** inherit; those two are deliberately *held* until Auto Loan's backend merges, so the loan/mortgage-family inheritance flows through a landed core rather than racing it. **Sales Tax ↔ VAT** are the deliberate **twin convergence-probe** — two structurally-near calculators built in parallel to see whether the agents converge on the same shape from the same primitive (the `solve-for-X` core). The rest (Pythagorean, Discount, ROI, Average Return) are fully independent and fan out at once. The orchestration plan per calculator stays the established pipeline: **backend → QA-gate → merge → frontend → QA-gate → merge**, then stand the app up headless for the operator's review.

The orchestrator launched them in batches across a few dispatches — Auto Loan / Sales Tax / VAT first, then Pythagorean / Discount / ROI, then Average Return — plus the Income Tax 2025 re-pin (the PM on its own branch off `main`). At journal time:

> **"All of **Wave 1 is in flight** — 7 backend builds + the Income Tax 2025 re-pin running in the background."**

### The board at journal time

The orchestrator framed the state and how it would drive from here — largely autonomously, merging on the operator's extended green-QA authorization (Chapter 125), surfacing only failures and judgment calls:

> **"As each backend PR lands I'll QA-gate it, merge on green, then immediately dispatch its frontend build (and release the held loan-family builds once Auto Loan's backend is in). I'll merge on green per your extended authorization and **only stop to flag a PR that fails its gate** or a spec-level judgment call."**

**Merged:** #239 (journey), #240 (iteration log + INVENTORY + 10 specs) → `main` at `0e99688`. **In flight:** 7 backend builds + the Income Tax 2025 re-pin + the historian. **Queued:** Personal Loan (#246) + House Affordability (#249), released when Auto Loan's backend merges; Income Tax (#250), released after the 2025 re-pin syncs into its issue. The end state remains what the operator ordered at Open — *all 20 build PRs merged and the app standing for review of the 10 new calculators.*

### Agent/doc-driven? — the lifecycle at scale, plus one spec change

No agent definition or doc convention changed in this chapter. What ran was the **iteration build phase at 2× fan-out**: issue-filing through `github-agent`, a parallel backend wave dispatched with explicit dependency ordering, and the per-calculator QA-gate-then-merge pipeline. The one substantive *change* was the Income Tax re-pin from 2024 to 2025 — and it is itself a clean instance of the experiment's discipline: a live correction to a reference-value table was driven **through the spec** (the issue body, re-authored by the spec-owning PM), timed to avoid a torn read of the in-flight filing, and slotted off the critical path so the nudge to the one new primitive cost the round nothing. The "does this work?" signal here is the orchestration holding shape under load: seven concurrent worktrees fanned out without collision (the conflict-free-builds promise of rule #3 exercised at volume), the dependency graph (loan-keystone-before-family, twin-probe in parallel) honored, and the merge cadence running on a now-explicit blanket-conditional authorization — the machinery executing the round it was consciously designed to stress.

---
