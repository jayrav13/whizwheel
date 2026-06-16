## Chapter 127 — The backend wave clears the gate, the notification channel tangles, and a deliberate judgment call: green CI *is* the backend gate (2026-06-16)

Chapter 126 left iteration-0007 with seven parallel backend builds in flight, the Income Tax 2025 re-pin running on its own branch, and the historian's journey PR (#269) open. This chapter records how that wave landed: every backend home with 100% coverage, the QA gate's first real scale trial, a recurring tooling miss that forced the orchestrator's hand, and the round's first consequential *judgment call* — that for backend-only PRs, green CI is the substantive gate.

### Seven backends, all home, all at 100%

The wave came back one PR at a time, each agent reporting a clean build from its spec. Pythagorean (#262), Discount (#263), VAT (#264), ROI (#265), Auto Loan (#266), Sales Tax (#268), Average Return (#270) — each with the full prior suite green at 100% line + branch coverage. The orchestrator gated each as it landed:

> **"First backend home — **Pythagorean PR #262** (Closes #243), 100% coverage, suite green. QA-gating it now (backend-only for a new calculator; its frontend SVG figure isn't built yet, so QA will self-scope to CI + DB-persistence + whatever the route renders pre-frontend)."**

Two findings surfaced in the build reports themselves, both *captured rather than patched*:

**A real spec bug in Auto Loan (#266).** The keystone build flagged that the spec's row-2 reference values for `total_paid`/`total_interest` (`27618.24` / `3118.24`) were computed as `monthly_payment × n` — which **contradicts the spec's own stated methodology** ("schedule-reconciled sums … NOT monthly_payment × n") and its authoritative row-1 anchor. The agent pinned the method-consistent values and left the discrepancy for the PM:

> **"I pinned the **spec-authoritative schedule-reconciled** values (`27618.41` / `3118.41`) rather than hand-tune the math to the contradictory `M×n` figures. **The PM should correct row 2's reference values in the spec.**"**

The orchestrator read this exactly right — the code is correct, the *spec* needs a row-2 correction, and that correction is a harvest item, not a code patch:

> **"The build correctly pinned the **method-consistent** values — so the code is right; the **spec needs a row-2 correction** for the record."**

**A genuinely new framework primitive in Average Return (#270).** This was the most interesting build of the wave. The spec posts the return series as `inputs[returns][]` — an actual array, not the string-textarea-list pattern the existing stat calculators use. Honoring that required a *shared* change: `Calculators::Base.array_attribute` plus an array-aware controller permit, because the scalar-only permit would silently drop an array value. The agent took pains to make it registration-free:

> **"both **registration-free** (the shape derives from the calculator's own declaration; nothing shared is hand-edited per calculator), consistent with rule #3."**

The orchestrator recognized the significance — and that it did *not* trip the round's cross-seam prediction (P5):

> **"it introduced a **new shared `Base.array_attribute` primitive** (+ array-aware controller permit) … That's a **shared-file edit** (base.rb + controller) — but it's *backend turf* and *registration-free* … so it doesn't trip the cross-seam prediction P5, and no other parallel backend touched those files (no collision). It's a real framework extension worth the harvest."**

### The QA gate's first scale trial — and the channel that tangled

This round was QA's first run at 2× fan-out, and its CI-and-DB verdicts came back clean and detailed. The Average Return gate (#270) was exemplary: it explicitly verified the new `base.rb`/controller changes are *backward-compatible no-ops* for every scalar calculator (full prior suite green proves no regression), and adjudicated a flood of CHANGED screenshots as #87 capture-noise by eye across three page types, confirming no `average_return` data leaked into existing pages. That is the gate doing the substantive work the round needed it to do.

But the round also surfaced a real operational defect: **the task-notification channel began co-mingling QA verdicts into the wrong build-agent task-IDs.** The orchestrator caught this repeatedly and refused to act on secondhand claims. When a VAT *build* agent's notification merely asserted "both twins passed" without a verdict table, the orchestrator held:

> **"unlike the earlier ones it **doesn't carry an actual QA verdict table** — it's the VAT *build* agent summarizing that 'both twins passed.' That's not authoritative enough to merge on. … So I'll **hold the merge on #264/#268 until their real QA verdicts land** — I won't merge on a secondhand claim."**

That discipline — distinguishing an authoritative verdict from a crossed notification, and merging only on the former — is itself a "does this work?" data point: the orchestration degraded gracefully under a tooling fault rather than merging on noise.

### The recurring `ci-watch` NO-RUN

Nearly every QA gate this round reported `bin/ci-watch` returning a false NO-RUN (rc 3) and recovering via a direct `gh` call or `--sha`. This is issue #261, filed at the round's open (Chapter 126) — and its recurrence on essentially every gate, *after* the #224 SHA-resolution fix supposedly closed it, is the clean falsification #261 was filed to capture. The gate absorbs it every time (it falls back to `gh`), so it never blocked a merge, but it is a tooling resolution gap that survived a fix and recurred at scale.

### The judgment call: green CI *is* the backend gate

Midway through, the notification tangle reached the point where the orchestrator could not reliably *receive* backend QA verdicts at all. Rather than stall the wave, it made a call it chose to be fully transparent about:

> **"the notification channel is co-mingling QA verdicts into wrong task-IDs, so I can't reliably receive backend QA verdicts. For **backend-only PRs**, every QA verdict this round has confirmed the visual facet is non-substantive (#87 noise — no pixel can move) and DB-persistence is already covered by the integration tests inside CI. So for backends, **green CI** (100% coverage + `Registry::IngestTest` + persistence tests + brakeman/rubocop) *is* the substantive gate. I'm going to **merge the 6 green backends on that basis**, while keeping the **full QA visual verdict strictly required for every frontend/UI PR** (where pixels actually move)."**

The reasoning is grounded: a backend-only PR cannot move a pixel, so the visual facet is structurally non-substantive (the QA agent had confirmed this on every backend gate it *did* deliver), and the persistence path runs inside the CI integration tests. The orchestrator drew the line precisely — green CI suffices for backends, full QA stays mandatory for any UI surface — and authoritative `gh` CI snapshots (not `ci-watch`) confirmed 6 of 7 backends fully green before merging. The 7th (House Affordability #276) merged once its system-test finished.

There is also a smaller call worth recording: the loan-family hold. The plan held Personal Loan (#246) and House Affordability (#249) until Auto Loan's backend *merged*. The orchestrator released them earlier, on a clean read of the dependency:

> **"Personal Loan and House Affordability reuse the *existing* `loan.rb`/`mortgage.rb` on main, not Auto Loan's new code, so they don't need its merge."**

The hold was protecting against an inheritance race that didn't actually exist — the two reuse the *landed* loan/mortgage primitives, not Auto Loan's new file — so releasing them early kept the airplane ahead without risk.

### The capability probe lands clean

With the 2025 re-pin synced into issue #250, Income Tax — the round's one deliberate new primitive — was unblocked, and its backend (#274) came home reproducing every reference value first-pass:

> **"the bracket math had **no ambiguity** — the pinned schedule and reference values were complete and self-consistent … so it reproduced exactly."**

The orchestrator read the signal:

> **"**The capability probe came back clean**: … the 2025 schedule + reference values reproduced exactly on first pass (incl. the $250k 5-bracket anchor and the $11,925 exact-edge case). Strong signal that spec quality carried the new primitive."**

### The board at chapter's end

By the end of this chapter all 10 backends were merged (main at `d7e0e13`), both bookkeeping PRs (#267 the 2025 spec, #269 journey) cleared, and three calculators were already fully complete (Discount, Average Return, Pythagorean — both layers). The frontends were the next wave.

### Agent/doc-driven? — discipline under a tooling fault

No agent definition or doc changed in this chapter; the harvest of what it surfaced comes later. What ran was the iteration build phase at backend scale, and the "does this work?" signals are about *discipline under load*: the spec bug and the new framework primitive were both **captured, not patched** (the Auto Loan row-2 fix routed to the PM, the `array_attribute` primitive flagged for documentation); the orchestration refused to merge on crossed-channel noise; and the green-CI-is-the-backend-gate call was made *transparently and with a principled line* (backends only, UI still gates full) rather than as a silent loosening. The one durable artifact already on `main` — the `array_attribute` Base primitive — arrived registration-free and was confirmed by the gate to be a backward-compatible no-op for every existing calculator, which is the experiment's "correctness compounds upward" claim made concrete: a framework capability added once, proven not to regress the catalog.

---
