## Chapter 125 — The bookkeeping-merge boundary: an auto-mode guard parks a green docs PR, and the operator extends the authorization (2026-06-16)

Iteration-0007 was open (Chapter 124) with the PM in the background authoring the log and the 10 specs, and the historian's journey PR (#239) already filed. This chapter records a small but instructive episode in the *seam between iteration work and iteration bookkeeping* — the kind of friction the experiment is designed to surface, where a guardrail does exactly what it was told and the operator has to decide whether the rule's scope was drawn correctly.

### The journey PR clears its gate

The historian's PR #239 (journey chapters 123–124) ran through the same quality gate every PR gets — there is no docs-only exemption. The `quality-assurance-agent` self-scoped it to the non-UI lane (CI + baseline-diff, DB facet N/A since no calculator changed) and returned a clean PASS:

> **"CI is fully green (5/5 jobs on run `27613273360`, the PR head SHA), the visual non-UI lane is clean (all 59 sha256-CHANGED shots adjudicated as #87 capture noise — a docs-only PR cannot move a pixel … ), and DB persistence is N/A."**

The gate also re-surfaced the now-familiar tooling miss: `bin/ci-watch` returned NO-RUN (rc 3) for both `--pr 239` and `--sha 3a911c1` despite the run being live and green, so QA fell back to `gh run watch`/`gh run view` to reach a terminal verdict. The orchestrator flagged it for filing — *"This looks like a `ci-watch` resolution gap worth a follow-up issue — adjacent to the recently-merged #224 SHA-resolution fix."* That this recurred even after #224's SHA-resolution fix landed is the seed of the engineering issue filed in the next chapter (#261).

### The guard parks the merge

The orchestrator moved to merge #239, reading it as in-scope under the operator's launch-order authorization:

> **"Merging it now — it's part of this iteration's bookkeeping and you've authorized the merges."**

But the auto-mode merge guard blocked it. The orchestrator respected the block and explained the boundary it had drawn:

> **"Noted — the auto-mode guard read your 'all PRs merged' as scoped to the **10 calculator build PRs**, not self-spawned bookkeeping PRs, and blocked the docs merge. That's the right call to respect, so I'll **leave #239 (and the upcoming iteration-log PR) parked, green, for you to merge** — they block nothing."**

This is the load-bearing distinction: the operator's Chapter 124 authorization ("all PRs merged") was read *narrowly* — as pre-authorizing the build line (the 20 calculator PRs), not the iteration's *own* bookkeeping PRs (the historian's journey log, the PM's iteration-log open, the eventual close-out). The guard chose the conservative reading rather than assume the broader one, and the orchestrator parked #239 green rather than work around the boundary. Parking was costless here — the bookkeeping PRs block nothing on the build line — so the conservative reading carried no critical-path penalty, which is exactly when respecting a guardrail is cheapest.

### The operator checks, and the answer holds

The operator, watching GitHub, asked the natural question:

> **"What happened to the QA agent? All checks seem to pass for 239 via UI"**

The orchestrator clarified that QA had finished cleanly and the UI-green and QA-PASS agreed — the UI checks the operator saw *are* QA's CI facet (5/5 jobs); QA layered the visual and DB facets on top. The unmerged state was **not** QA but the merge guard:

> **"The reason #239 is **sitting unmerged isn't QA — it's the merge guard.** When I tried `bin/merge-cleanup 239`, the auto-mode classifier blocked it, reading your *'all PRs merged'* as scoped to the **10 calculator build PRs**, not this self-spawned docs/journey PR. So I parked it green rather than work around the boundary."**

The orchestrator then laid out the two clean ways forward rather than presuming: (1) merge #239 now and keep parking the *other* bookkeeping PRs for an explicit nod each, or (2) extend the authorization to treat **all** iteration bookkeeping PRs (journey, iteration log, close-out) as auto-mergeable on green QA, the same as the build PRs.

### The operator extends the authorization

The operator chose to extend. The orchestrator confirmed the new scope in plain terms:

> **"Got it — **authorization extended: auto-merge all iteration-0007 PRs on green QA, including bookkeeping (#239, #240, close-out).** That clears the parking."**

Under the extended authorization the two bookkeeping PRs flowed through immediately. **#239** (journey) merged — `main` advanced `e85c47c` → `adaba1c`, and the journey worktree/branch were cleaned up. Then **#240** (the PM's iteration-0007 Open: the log with the five falsifiable predictions, the INVENTORY backfill, and all 10 spec:v1 bodies) cleared its own QA gate PASS and merged — `main` advanced `adaba1c` → `0e99688`. The orchestrator sequenced #240 to merge *alone* first, deliberately, so the build wave would branch off a `main` that already carried the iteration log + INVENTORY + specs:

> **"#240 merged — `main` at `0e99688`, iteration log + INVENTORY + all 10 specs now on `main`."**

Both QA runs again hit the `ci-watch` NO-RUN / #224-class miss and fell back to `gh` — the recurrence that justifies the engineering issue.

### Agent/doc-driven? — a scope decision, recorded but not encoded

No agent definition or doc changed in this chapter. What moved was an **authorization scope**, decided live by the operator: the human-gated-merge rule (CLAUDE.md: "never auto-merge … merge only on explicit human instruction") was honored on *both* sides of this episode — first by the guard parking a PR whose authorization was ambiguous, then by the operator explicitly extending the authorization to cover bookkeeping. The "does this work?" signal is that the guardrail and the human stayed in a tight loop: the machinery did not silently broaden a narrow instruction, it surfaced the boundary and asked, and the cost of being conservative was zero because the parked PRs gated nothing. The episode is a clean illustration of the experiment's posture toward authority — *blanket-but-conditional* authorization is honored facet by facet, and when its scope is genuinely unclear the system stops and asks rather than guesses.

---
