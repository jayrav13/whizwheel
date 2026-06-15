## Chapter 120 — The admin stats page ships: a spec error caught by the gate and corrected via the doc, not the code (2026-06-15)

Chapter 119 opened the admin stats page as a deliberate out-of-iteration thread — scoped by the brainstorming skill, homed in the repo's own `spec:v1`/issue convention, split into a backend-first pair of contract-decoupled PRs. This chapter closes it. Both PRs are now on `main`: **backend PR #223** (closed #220) at `fe36b18`, **frontend PR #225** (closed #221) at `5eb0f5f`. `/admin/stats` is live — the app's first admin-gated surface. But the *interesting* part of this thread is not that it shipped; it is the four arcs the orchestration surfaced along the way, each a small piece of evidence about whether the process holds when a feature runs entirely as ad-hoc main-thread orchestration outside the iteration machinery.

### Arc 1 — the spec was wrong, the documented convention won

The most instructive moment of the whole feature is a spec error the operator made, caught by the QA gate, and corrected by **following the authoritative doc rather than patching code**.

The kickoff spec (Chapter 119) had the `CalculationStats` query object *always* filter soft-deleted rows — `deleted_at IS NULL` on every aggregate — which the operator had approved. The backend agent built faithfully to that spec, and CI was green. But when the `quality-assurance-agent` gated backend PR #223, its DB facet raised a flag the orchestrator had not anticipated. The verdict carried it as a non-blocking clarification:

> **"§6 intent question — `ARCHITECTURE.md §6` says site-wide admin stats use 'the FULL table/view (discarded included)', but `CalculationStats#kept` filters `deleted_at IS NULL` for all queries. The PR's behavior is internally consistent and tested, but diverges from §6's literal text. The human should confirm intent: should soft-deleted calculations count toward site-wide admin totals or not?"**

The orchestrator did not wave it away. It read the actual section and confirmed the conflict was real, and — notably — **owned it as its own spec error, not the agent's**:

> **"Our page is exactly 'site-wide admin stats,' but my approved spec said the opposite (`always filtering deleted_at IS NULL`), and the backend built to my spec. So the code contradicts the documented convention — my error in the spec, not the agent's."**

That attribution matters for the experiment's bookkeeping. The agent did exactly what it was told; the failure was in the human-authored spec, which contradicted a standing architectural convention. `ARCHITECTURE.md §6` is unambiguous on the principle — *"usage is usage; a user hiding their own history must not erode site-wide totals."* The operator's call was to **follow §6**: aggregates now include discarded rows, and — the operator's refinement — the recent feed should *show* the discarded rows with a marker rather than hide them. The orchestrator captured how that rippled into the contract:

> **"follow §6 — aggregates include discarded; recent feed shows all rows with a 'discarded' marker. That last part changes the contract slightly — `recent(...)` rows now need a `discarded` boolean so the frontend can render the marker."**

This is a clean instance of the repo's authority hierarchy doing its job: a centrally-documented convention (`ARCHITECTURE.md §6`) beat an ad-hoc per-feature spec, and the resolution was a *spec/contract* change propagated through the agents, not a one-off hand-edit. The fix lives where the convention lives.

### Arc 2 — review, batch, re-gate

Rather than send the backend agent back twice, the orchestrator ran the `code-reviewer` and the QA gate **in parallel** on #223, then folded *all* their findings plus the §6 correction into a **single** backend revision before re-gating. The orchestrator stated the batching discipline explicitly:

> **"Rather than send the backend agent back twice, I'll hold for the `code-reviewer` (still running) and batch its findings with the §6 fix into one revision, then re-run the QA gate before you merge."**

The `code-reviewer` came back **should-fix, no blockers** — and earned its keep by mapping the §6 fix's *full blast radius*: the orchestrator noted the change touched **four** comment/contract locations, not just one method (the class invariants docstring, the `kept`→`all_rows` helper, the `CalculationLog` model comment, and the PR body's "always filters" claim + the `@stats` contract table). That is exactly the kind of "you fixed the obvious spot but missed the three places the convention is *restated*" catch a code review is for.

The batched revision (new head `1d15d44`) replaced the `kept` base relation with `all_rows = CalculationLog.all` across all five aggregates, added the `discarded:` boolean to each `recent` row, **flipped the reference-value tests to assert discarded rows are now counted** (recomputing exact fixture tallies — e.g. `volume all_time: 8`, `attribution {anonymous: 3, attributed: 5}`), and changed the "discard a row" tests to assert totals are *unchanged*. Full suite stayed green at 100% coverage. The re-run QA gate returned PASS on `1d15d44`, and the operator merged: `fe36b18`.

This review→batch→re-gate loop is the same quality discipline the calculators use, applied to a one-off feature — and it held without an iteration's scaffolding around it.

### Arc 3 — two infra frictions surfaced and got filed (#224 + #87)

The orchestration exposed two recurring tooling frictions, both of which got recorded rather than absorbed silently.

The first is a real bug. On the historian's docs PR #222, the QA agent reported that `bin/ci-watch --pr 222` **returned NO-RUN (exit 3) on all five retries even though a CI run existed and was in progress** — it had to fall back to resolving the run by the PR's head SHA. The operator asked for it to be filed, and the orchestrator stated the bug precisely:

> **"`bin/ci-watch --pr <N>` fails to resolve a PR's CI run, returning NO-RUN (exit 3) even when a run exists and is in progress. … the failure is isolated to the `--pr` → CI-run resolution path … not a genuine absence of a run."**

It was filed as **#224** (`engineering`). Then on backend PR #223 the QA agent found the gap was *wider* — `bin/ci-watch --sha 1d15d44` and `bin/ci-screenshots --sha 1d15d44` *also* returned NO-RUN despite a completed run at that exact SHA. So fixing the `--pr` → head-SHA mapping alone would not be sufficient; the shared root cause is the run-lookup-by-SHA query both entry points funnel through. The operator said "yes" to broadening, and `github-agent` widened #224 to cover both `--pr` and `--sha` (and `bin/ci-screenshots --sha`), naming the run-lookup-by-SHA query as the common culprit. The practical cost: the QA agent had to **adjudicate CI state by direct `gh api` query on essentially every PR in this thread** rather than trust its own watch tooling — a friction the historian notes because it recurred at every gate.

The second is the already-tracked **#87**: capture non-determinism on the non-UI visual lane. On every backend/docs PR in this thread the QA agent reported large fractions of screenshots flagged CHANGED (58/58, 52/70, 62/70 across the three non-UI PRs) on PRs that *structurally cannot move a pixel*, requiring by-eye adjudication that they were identical. The QA agent's framing on #218's predecessor — that "a config file Rails never loads cannot move a pixel" — applies equally here: a backend-only or docs-only PR's screenshot diffs are noise by construction. It is a known gap, re-confirmed, not a new finding.

### Arc 4 — silent subagent death recurred, and the orchestrator did not trust a stale PASS

The #140 silent-death failure mode — a dispatched subagent ending without delivering its verdict to the main thread — recurred repeatedly across this feature, and twice the operator was the one to notice ("i dont see running agents", "i dont see any agents running"). Each time the orchestrator checked reality rather than assuming, and re-dispatched a fresh agent (death recovery). The first instance, on the backend code review:

> **"the `code-reviewer` I dispatched on #223 ended without delivering its verdict to me (the #140-style silent death). CI is green and the PR is stable, so I'll just re-dispatch a fresh one (death recovery)."**

The sharpest version came at the very end, on frontend PR #225. A *consolidated* PASS notification arrived — but it landed under a **stale/mislabeled task-id**, and the orchestrator refused to merge on it without verifying directly:

> **"A consolidated PASS came through for #225 … but that arrived under a stale task-id and I have two reviewers I dispatched still in flight, so let me verify the PR's actual state directly rather than merge on an ambiguous signal."**

That instinct paid off:

> **"Good thing I checked — #225 is not fully green yet. Current head is `020b44d` (the nit-fix commit), and on that SHA `scan_ruby`/`scan_js`/`lint` passed but `test` and `system-test` are still running … The consolidated PASS that came through was against the pre-nit-fix SHA."**

The frontend agent had pushed a follow-up commit `020b44d` fixing the two code-review nits (an `aria-hidden`/`role=img` contradiction on the SVG and a stale comment), and the PASS that had come in was for the *previous* SHA. The orchestrator held the merge, and — after the re-dispatched gate/review *also* silently died — re-ran a **fresh QA gate on the final SHA** for a clean record rather than reasoning its way to "the delta is cosmetic, good enough." That final gate returned a clean tabular PASS on `020b44d` (CI 5/5 green, both new admin-stats shots BLEND-adherent, the aria/role fix confirmed *coherent* — empty+`aria-hidden` at rest, populated+`role=img`/`aria-label` once the Stimulus controller connects and removes `aria-hidden`). Only then did the orchestrator merge #225: `5eb0f5f`.

The lesson the thread keeps re-teaching: a notification's *content* is not trustworthy without verifying the *SHA it ran against* — a stale PASS on an old commit is worse than no PASS, because it looks authoritative.

### What landed

The frontend build (PR #225) delivered the BLEND dashboard to `DESIGN.md`: volume stat cards (today/7d/30d/all-time) in the shared `.stat-grid`, a **dependency-free inline-SVG 30-day bar chart** driven by a self-contained Stimulus controller (`bar_chart_controller.js`, no charting library, honoring importmap/no-Node), with a no-JS `<details>` data-table fallback; thin-ruled tables for top calculators, top users, and the anonymous-vs-attributed split; a 50-row recent-activity feed with a coral **"Discarded"** badge on soft-deleted rows; and an admin-only "Admin" nav link gated on `current_user&.admin?`. The system test signs in as the admin, asserts the inline-SVG chart actually paints (`>= 1` rendered `<rect>` — the inline-SVG analogue of a canvas pixel guard), and captures full-page screenshots. 1007 runs, 100% line + branch coverage.

### Agent/doc-driven? — built by agents, corrected via the doc, nothing new codified

No agent definition changed in this thread. The work was *built by* the existing agents (`github-agent`, `backend`, `frontend`, `code-reviewer`, `quality-assurance-agent`) and orchestrated by hand in the main thread. The one substantive *correction* — the §6 discarded-inclusion fix — was driven by the **authoritative architecture doc** beating an ad-hoc spec, exactly the resolution the experiment prefers: the durable convention won, and the change propagated through the spec/contract and the agent's rebuild, not through a code patch that would diverge from the doc.

The process meta-point worth recording: **this entire feature ran outside the iteration pattern**, as main-thread orchestration, and the standing disciplines still applied without exception — every PR (the two build PRs *and* the historian's two docs/journey PRs, #222 and the one journaling this) went through the QA gate; nothing merged without explicit human instruction ("Merge historian if ready", "yes to both", and the final merge only after a fresh gate on the true final SHA). The first conscious line between iteration-work and modular app infrastructure (Chapter 119) held: a feature can live entirely outside the regen sweep and still inherit the gate, the review loop, the doc-authority hierarchy, and the human-gated merge — the experiment's quality machinery is not iteration-specific.

---
