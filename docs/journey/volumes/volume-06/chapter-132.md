## Chapter 132 — GH-routing closes its last loophole, the fixture cascade gets fixed, a color collision is filed, and the next round is teed up but held (2026-06-19)

The session's tail did three things in parallel under the freshly-tightened 2-cap: it fixed the iteration-0007 P4 falsification (#286), it surfaced a second governance loophole and closed it (GH-routing), and it teed up the next iteration — which the operator then deliberately *held*. It ended with a clean five-PR merge train. This chapter records all three, plus the color-collision find.

### #286: the fixture cascade, fixed

Recall iteration-0007's one falsified prediction (P4): every frontend build appended a row to the shared `test/fixtures/calculators.yml`, so the conflict-free fan-out (rule #3) **serialized at merge** on that one file — a clean union every time, but a manual-merge tax on every frontend PR. The PM had flagged it as the *gating* concern for the next 5-calculator round (five new calculators = up to four guaranteed rebases on that file), recommending it land *before* the round rather than eating the tax again.

So the `backend` agent was dispatched (top of the standing queue, the operator having greenlit "land #286 first") and shipped **PR #296**: the shared `calculators.yml` split into **per-calculator files** at `test/fixtures/calculators/<slug>.yaml`, assembled by a thin ERB aggregator. The orchestrator flagged the load-bearing detail that QA then confirmed at the gate: the `.yaml`-vs-`.yml` glob mechanism is what makes the split work — 24 rows migrated, all loading through the aggregator, coverage held at 100%. This unblocks the next round's frontend fan-out: each new calculator now adds its *own* fixture file, so parallel frontend builds no longer collide at merge. P4's falsification is now repaired at the mechanism level, not worked around.

### The color collision (#295)

Mid-session the operator noticed two agents share a display color:

> **"Oh hmm, backend and QA share a color? File a GH issue to address changing one of the two colors"**

Checking the agent-definition frontmatter, the orchestrator found it was worse than one collision — **9 agents, only 7 distinct colors**, two pairs colliding:

- 🟠 **orange** — `backend` **and** `quality-assurance-agent` (the one the operator spotted).
- 🟣 **purple** — `github-agent` **and** `historian` (a second).

It filed **issue #295** (`engineering`) capturing both collisions, the full current palette, and a minimal fix direction. But *how* it filed the issue became the next loophole.

### GH-routing: closing the "quick one-off" carve-out

The orchestrator filed #295 **inline** (directly via `gh`), reasoning at the time that the documented "quick one-off, no dup risk" carve-out permitted it and that "main-thread filing isn't a subagent, so it doesn't touch the cap." The operator corrected this — not the filing, but the principle:

> **"Ah, I think I'd prefer that we queue up the GH agent to be sent out in the future. Can you further tighten up CLAUDE.md to strengthen this? Queue this as a task to do and then dispatch the correct agent to update**
>
> **Also, can you add to the issue for us to research whether or not hex representation of colors can be used so we have more to work with? Or at minimum, identify the enumeration of colors available and document those in ~/.claude/CLAUDE.md so that 1) system wide we're aware up front of colors and 2) it's available as knowledge in all projects?"**

The orchestrator accepted the inconsistency:

> **"if the rule is 'route GitHub mechanics through `github-agent`,' then me filing #295 inline (even under the carve-out) undercuts it."**

It did *not* dispatch anything new immediately — it was at the 2-cap (QA-#294 + backend-#286 in flight) — so it formalized the work as a queued task rather than reaching for `gh`: "this is exactly the 'queue, don't violate' discipline in action." When a slot freed, it dispatched the PM to tighten `CLAUDE.md` — landing as **PR #297**, which **removed the "quick one-off … may still be filed directly" carve-out entirely** and extended the rule to cover issue *edits*, not just creation: all GitHub issue mechanics — create AND edit — now route through `github-agent`, enqueued under the 2-cap, never inline. The cross-reference was worded to resolve to the new "Concurrency cap" section regardless of whether #294 or #297 merged first.

The hex/color-enum research ask was queued as the `github-agent` task to update #295 — investigate whether `color:` frontmatter accepts hex (so all 9 agents could be unique; with only ~7–8 named colors in the enum, the orchestrator noted "9 unique agents simply can't all differ without hex — so the research isn't cosmetic, it's whether unique-per-agent is even achievable"), and to document the available color enumeration in the operator's *global* `~/.claude/CLAUDE.md` for cross-project reuse.

### The next iteration: teed up, then held

The PM's pick list (the recommendation that survived the death-and-resolo of Chapter 131) leaned into category breadth — the catalog being 20/24 Financial with Fitness & Health nearly empty:

| # | Calculator | Category | Primitive | Why now |
|---|-----------|----------|-----------|---------|
| 1 | **Body Fat** | Fitness & Health | Reuses BMI's multi-mode + US/metric — no new math | Opens the near-empty Fitness category |
| 2 | **Calorie** | Fitness & Health | Reuses multi-mode; new BMR formula family | Flagship health page |
| 3 | **Future Value** | Financial | Strict subset of `compound_interest.rb` | Lowest-risk anchor |
| 4 | **GPA** | Other | Reuses the `array_attribute` list primitive (#287) | Stress-tests list input on a fresh domain |
| 5 | **Hours** (Time Duration) | Other | **Introduces** clock/duration time-math | The one deliberate new-primitive probe |

Four reuse a proven primitive, one introduces a new one — and the PM put **#286 first** as the gating caveat. The operator accepted both ("PM's pick as-is" + "Land #286 first" — the orchestrator captured these as the operator's choices), and then, at the very end, drew the line:

> **"Hold on starting the iteration. Otherwise, merge all that are ready in suggested order"**

So the round is fully teed up — set chosen, sequencing decided, the #286 blocker now merged — but **not opened**. The orchestrator confirmed it had *not* opened the round even though #296's merge cleared the blocker.

### The merge train

The operator's "merge all that are ready in suggested order" released the five gated-PASS PRs. The orchestrator merged them one at a time via `bin/merge-cleanup` (which runs merge → worktree-removal → branch-delete in the load-bearing order), checking for "behind main" rebase needs between each, in the suggested order:

1. **#292** (#261 `bin/ci-watch` NO-RUN fix) — first, so every future QA gate stops hitting the flake.
2. **#296** (#286 fixture split) — unblocks the next round.
3. **#293** (#215 tall-thin SVG).
4. **#294** (the 2-cap + standing-queue rule) — the orchestration contract now live on `main`.
5. **#297** (GH-routing tightening) — fast-forwarded without a rebase; the two `CLAUDE.md` edits were genuinely non-conflicting sections.

Final state: `main` at **`0c66b84`**, all worktrees pruned, only the `main` branch left, working tree clean. The orchestrator then fired the historian in the background ("📝 journaling this session's work in the background (the two process-harvest changes especially — the 2-cap and the GH-routing rule)") — this chapter and its siblings.

### What this session is evidence of

Almost nothing here is a calculator result. The durable artifacts the session produced are **orchestration discipline**: a hard 2-agent cap with a standing queue and follow-on priority (#294), an all-issue-mechanics-route-through-`github-agent` rule with no inline carve-out (#297), a re-gate that caught a stale gated-SHA before merge (Chapter 130), and a mechanism-level fix to the one falsified prediction from the prior round (#286/#296). Two of those (#294, #297) govern how the orchestrator itself behaves, and both were prompted by the orchestrator's *own* missteps that session — a death at 3 agents, an inline issue filing — caught and corrected into the contract rather than into a one-off resolution. The experiment's "fix the agent, not the code" loop, applied to the orchestrator, is what this session demonstrates; the next round (the five calculators) waits on the operator's go.
