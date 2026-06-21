## Chapter 130 — "Any low hanging fruit?": a steady-state quick-wins arc, and a fix that had already shipped (2026-06-17 → 2026-06-19)

With iteration-0007 closed (10/10 shipped, harvested, journaled, formally closed by the PM at `main` `0c66b84`'s predecessor), a new session opened **outside** the iteration pattern — ordinary backlog grooming, the machinery in steady state. This chapter records the session's opening arc: a branch prune, a low-effort triage routed to the specialist, the two "dispatch-now" picks, and a discovery that one of them had *already been fixed* by the previous iteration's harvest — with a genuine remaining edge case hiding underneath.

### Pruning the merge debris

The session opened on a one-word housekeeping instruction:

> **"prune branches"**

The orchestrator checked merged-state before deleting anything ("Let me check whether these stale branches are merged before deleting anything"), found two fully-merged stragglers, and pruned them:

- **`pr-228`** (local) — merged into `main`, no unmerged commits.
- **`origin/docs/iter0007-close`** (remote) — merged via PR #290.

Both were confirmed unreferenced by any worktree first; a `git fetch --prune` cleared the stale remote-tracking refs. The point worth noting is the discipline, not the deletion: the orchestrator verified merged-status before removing, so the prune could never orphan unmerged work.

### The low-effort triage, routed to the specialist

Next:

> **"Any low hanging fruit issues"**

Per the contract, backlog triage is `github-agent`'s job (the Now/Later + effort summary), so the orchestrator dispatched it rather than scanning by hand: "I'll dispatch the `github-agent` to summarize the backlog through the low-effort lens — that's its job." The agent returned a best-first table of quick wins and — usefully — a **drift report**: eight issues in the standing effort doc (`docs/experiments/issue_effort.md`) had closed since its 2026-06-14 snapshot, and five new ones (#177, #180, #215, #261, #286) were missing from it entirely. It flagged the doc as needing a PM reconcile (10 of 18 rows stale or absent).

The top of its list:
- **#261** — `bin/ci-watch` returns NO-RUN (rc 3) for live/green runs (the recurring flake every QA gate trips over) — **Low, best ROI**.
- **#286** — the fan-out merge-conflict cascade on the shared `test/fixtures/calculators.yml` — **Low–Med**.
- **#215** — Right Triangle SVG clips edge labels on extreme inputs — **Low** (but a `frontend` issue, so a full visual gate even for a one-liner).

A day-and-change later, the operator sharpened the ask to the genuinely-autonomous subset:

> **"Which of the Low Effort items can be sent to a subagent to complete *right now* with little planning"**

The orchestrator narrowed five low-effort items to **two** truly dispatch-now — clear spec, self-contained, right agent exists, no human-decision or doc-ownership blocker — and noted they happened to sit on different layers, so they parallelized cleanly:

- **#261** → `backend` (a `bin/` script bug).
- **#215** → `frontend` (a single-file ERB/SVG fix).

It set the other three aside with reasons: #112 (financial color) is blocked on an operator design decision; #127 (a database-agent verification step) is a `docs/`/CLAUDE.md edit that must route through the PM; #286 is "low-*med*, touches every existing fixture + frontend test … Needs real planning, not 'little.'"

The operator green-lit both:

> **"Yes, fire both agents (select based on relevant agents)"**

Both fired in the background — `backend` on #261, `frontend` on #215 — each creating its own worktree → branch → PR, with the QA gate pre-committed for the moment each PR appeared.

### A side-quest into iteration-0007's own goals

While the build agents ran, the operator stepped back to re-orient:

> **"With that said, what was our last iteration's goals?"**

and then:

> **"What harvesting work did we do based on that? Meaning, what were all of the GH issues or follow-up items we identified and worked on"**

The orchestrator reconstructed iteration-0007 from memory and the journal: a deliberate **process stress test**, not a results round — 10 new calculators (~20 build PRs) at 2× the 0006 fan-out, results held as the controlled variable, instrumented with five falsifiable predictions written up front (P1 no registry-count collision, P2 INVENTORY backfilled at Open, P3 derived count moves 14→24 only on completion, P4 no fixture↔page coupling surprise, P5 no cross-seam edits). Outcome: **10/10 shipped, 4 of 5 predictions held, P4 falsified** (the shared-fixture cascade — exactly #286). And it laid out the full harvest manifest: PRs #284 (money-2dp), #285 (pill alignment), #289 (table no-overflow + the §4 mode-picker decision), #288 (Right Triangle SVG clip propagation), #287 (the process bundle — concurrency cap + re-gate rule + ci-monitor deprecation + the `array_attribute` pattern), and #286 (filed, not fixed).

This recap mattered because it surfaced the next beat directly.

### The discovery: #215 was already fixed — and yet wasn't

Reciting the harvest, the orchestrator noticed an overlap between the running #215 frontend agent and the just-merged **#288** ("Right Triangle SVG clip propagation"). #288 had swept the Pythagorean #272 fix across the geometry calculators — and #215's documented symptom was the same family of defect. The instinct was to warn the running agent off redundant work:

> **"I'll send the running #215 frontend agent a note to check #288 first before building anything."**

But the harness offered no channel:

> **"SendMessage isn't available in this harness, so I can't inject a note into the running agent. Let me instead investigate the #215/#288 overlap myself right now — if #288 already fixed it, I'll stop the agent and close #215 rather than let it open a redundant PR."**

It read #215's exact ask against the file #288 had touched and confirmed the *documented* symptom was already solved:

> **"Confirmed — #215 is already fixed by #288."**

#288 had moved the leg-`a` label from `pad - 6` (outside the leg) to `pad + 6` (inside), flipped the text anchor from `end` to `start` so a high-magnitude value grows into the triangle interior, and added an `assert_svg_labels_within_bounds` system-test guard wired into the large-values case — verified against the `a=300,000` screenshot. #288 simply never referenced #215 by number, so the issue stayed open. The orchestrator stopped the running agent via TaskStop to avoid a redundant PR.

Then the nuance. Killing the agent revealed its last working line: it had begun exploring a **"tall-thin degenerate case (the real #215 worst case)."** The orchestrator pulled back from the clean "duplicate" call:

> **"my 'already fixed by #288' call was half right: the *documented* symptom (a=300,000 leg-a clip) is covered and CI-guarded, but the agent found a plausible *uncovered* worst case."**

Inspecting the killed agent's worktree, it found **92 lines of uncommitted changes across 3 files** — the agent had not treated #215 as a duplicate at all. Its reasoning: #288 verified the large-*value* case (`a=300,000`), but a **tall-thin near-degenerate triangle** is a different geometry where labels can still clip — and it was hardening for exactly that. Nothing was committed or lost; the orchestrator surfaced the find and put the decision to the operator.

> **"Yes try it"**

So the `frontend` agent was **re-dispatched to resume in its existing worktree**, picking up the ~92 in-progress lines and finishing the tall-thin hardening *additively on top of* #288 (not undoing it), to the 100% coverage gate before opening a PR. The result was **PR #293**: a widened viewBox with side gutters and clamped α/β angle-label anchors so that even a **~387:1 degenerate sliver** keeps every label inside the figure — with a new tall-thin system test and screenshot self-review.

This is a small but pointed evidence note for "does this work?": the harvest's regen-style propagation (#288) *did* solve the issue's headline symptom catalog-wide, yet a fresh build agent, dispatched at the issue rather than the symptom, surfaced a genuine remaining edge the harvest hadn't reached. The two together — propagation plus a from-the-issue rebuild — covered more than either alone, and the orchestrator's honesty about its "half right" call kept the find from being discarded as a duplicate.

### The re-gate, live

The #261 backend agent (PR **#292**) had a CI-tooling twist worth recording, because it reproduced — within the same session — the exact failure mode iteration-0007's harvest had just written a rule for.

The agent's first fix layered fallbacks onto `bin/ci-watch`'s run resolution (`gh pr checks` → `gh run list --commit/--branch` → retry). Its QA gate **PASSed** at head `21ff684` (CI genuinely green) but correctly flagged that the fix *still* false-NO-RUN'd on this PR's own **live** run — every CLI list-filter lags the GitHub index right after a push. So the agent pushed a **further hardening commit (`3fc1e2d`)**: it made the **REST Actions API keyed on `head_sha`** (`actions/runs?head_sha=<sha>`) the *primary* resolver — the canonical server-side index, populated the instant the run object exists, so it reaches a live run before any CLI filter catches up.

That second push is precisely the **#272 stale-gated-SHA scenario** the CLAUDE.md re-gate rule covers. The orchestrator named it and obeyed:

> **"the prior QA PASS was pinned to `21ff684`, and the head is now `3fc1e2d`. Per the CLAUDE.md re-gate rule, that green verdict no longer describes the PR head — I must re-gate before merge."**

A fresh QA dispatch re-gated the new head and returned **PASS**, verified two independent ways: the REST `actions/runs?head_sha=3fc1e2d` query reported success, *and* `bin/ci-watch --sha 3fc1e2d` itself now returned rc=0 — the fix verifying itself, resolving its own live run immediately on `head_sha`. A nice closed loop: the bug-fix's gate demonstrated the bug it fixes (QA #293 had hit the very NO-RUN flake while gating and fallen back to `gh run watch`), and the fix's own re-gate proved the flake gone.

PR #293 (#215 tall-thin) gated PASS at head `a428221`; its visual review confirmed the 387:1 sliver keeps every label inside the figure with no regression on common cases. Both fix PRs now sat green, gated, and parked for the operator's explicit merge call — never auto-merged.

The throughline so far: this was the machinery in ordinary steady-state — a prune, a specialist triage, a two-agent fan-out at the (then) cap — but it surfaced two live instances of harvested rules earning their keep: the **re-gate rule** caught a stale-SHA before merge, and a from-the-issue rebuild caught an edge the harvest's symptom-propagation had missed. The session's larger process lesson was still one beat away.
