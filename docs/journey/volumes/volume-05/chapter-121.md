## Chapter 121 — The harvest and the regen: design feedback becomes an agent change, and the prompt-vs-doc miss it exposed (2026-06-15)

Chapter 120 closed the admin stats page's *build* — both PRs merged, `/admin/stats` live. This chapter records its **closing arc**: the operator looked at the shipped page, gave two pieces of design feedback framed explicitly as agent changes, and the experiment's core loop ran tightly inside a single main-thread side quest — feedback → fix the agent/doc, not the code → a regen propagates the fix. It is the cleanest small-scale demonstration so far of the whole "agent-first" thesis operating end-to-end in one sitting, and it surfaced a precise, instructive failure mode along the way: *the orchestrator's own dispatch prompt had contradicted the design doc.*

### The "blank page" that was the gate working

Before the feedback, a short debugging interlude worth recording because it re-validated a Chapter 119 design choice under live use. After the merge the operator asked to *"start server let's see it"*; the orchestrator brought the app up headless (`bin/serve-headless`, not `bin/dev`, per the agent-shell rule), reset the existing admin user `demo`'s password, and handed over a login. The operator reported a **"Blank page"** — twice. The orchestrator resisted assuming a bug and read the server log, which was the smoking gun: every one of the browser's `/admin/stats` hits was *"Filter chain halted as :require_admin!"* → 404, while the only `200` in the log was the orchestrator's own `curl` test through its own cookie jar. The diagnosis:

> **"your browser has never completed a login. Every `/admin/stats` hit from your browser halts at `require_admin!` → 404 (blank), because `current_user` is `nil`. … nothing's broken — you're just hitting the gate unauthenticated."**

So the "blank page" was the **404 gate behaving exactly as specced** — the deliberate "don't reveal the route exists" posture from Chapter 119, hit by an unauthenticated browser. The orchestrator noted the one genuine UX wrinkle this exposed (a 0-byte 404 in dev *looks* broken; production would serve the styled `public/404.html`) and offered to file an anonymous-404 → login-redirect tweak, leaving the call to the operator. Once logged in, the page rendered — and that is when the feedback came.

### Two pieces of feedback, framed as agent changes

The operator viewed the page and gave two design notes, then named — unprompted — exactly where the fix belonged:

> **"I see it now, is the bar chart a tradingview chart or did it default to something simpler? We should emphasize tradingview more**
>
> **In recent activity, any type of block of quantitative text should appear in some kind of code tags**
>
> **Those are the changes we should make to the agents for this side quest. Then re-run frontend"**

That third line is the chapter's spine. The operator did not ask for the *page* to be changed; he asked for the **agents** to be changed and the page **re-run** from them — the regeneration discipline (rule #1) applied by reflex to a one-off feature. The orchestrator's first response named the move for what it was: *"this is exactly a 'fix the agent, not the code' moment: the durable fix is to change DESIGN.md + the frontend agent, then regen."*

### The root cause: the prompt contradicted the doc

The more interesting finding was *why* the chart had defaulted to a hand-rolled inline-SVG bar chart in the first place. The orchestrator read the existing charting guidance before editing — and discovered the convention was **already there**:

> **"DESIGN.md §4 and the frontend agent already mandate TradingView lightweight-charts for time-series charts (via importmap, with a pixel-level 'did it paint' test). The admin stats page got a hand-rolled inline-SVG bar chart anyway — because my dispatch prompt explicitly overrode that convention ('dependency-free inline-SVG bar chart, NO charting library'). That was my error as orchestrator, not the agent drifting."**

This is a clean, named instance of a distinct failure class: **the prompt contradicted the doc.** The frontend agent had a standing convention (DESIGN.md §4 → TradingView lightweight-charts for charts), and the orchestrator's own ad-hoc dispatch prompt for the side quest had explicitly told it to do the opposite — to honor the importmap/no-Node constraint with a dependency-free SVG. The agent obeyed the more specific instruction. The orchestrator owned it as its own error, not the agent's — the same attribution discipline Chapter 120 recorded for the §6 spec error.

There was also a genuine *gap* in the doc that let the prompt slip through unnoticed: DESIGN.md §4 framed charts as calculator "result charts" and **never covered the bar/histogram or dashboard-chart cases** — so a dashboard volume chart sat in a blind spot the convention didn't visibly claim. The fix therefore had to do two things at once: close the doc's coverage gap *and* harden the convention so an offhand "keep it simple" in a future prompt can't override it.

### "Should we just turn this into an iteration?" — kept a side quest

Before encoding the harvest, the orchestrator surfaced a process question the operator had implicitly raised: was a 2-convention harvest worth spinning up iteration ceremony? The orchestrator recommended **no**, and the operator agreed:

> **"keep it the side quest we framed. … The harvest is real but small (2 conventions), and its only immediate beneficiary is the admin stats page we're already about to regen. … the harvest lands on `main`, and the *next* iteration's frontend regen sweep pins the post-harvest agents and carries these conventions catalog-wide. That next iteration is your already-planned iteration-0007."**

The reasoning is a precise statement of how the experiment's propagation mechanism is *supposed* to amortize harvests: land the harvest on `main` now, let the page that prompted it be regenerated immediately, and let the already-planned **iteration-0007 frontend regen sweep** (pinned at post-harvest agents) carry the new conventions across the whole catalog — rather than duplicating that sweep with bespoke iteration bookkeeping (tag → PM log → sweep → journal → close) for a harvest whose only *immediate* beneficiary is the admin stats page itself. The discipline without the overhead. (The orchestrator named the *yes* condition too: if the operator wanted to sweep these conventions catalog-wide *now* with full bookkeeping rather than wait for iter-0007. He did not.)

### Harvest PR #227 — the two conventions encoded

The harvest landed as a docs/agent-only PR (in a worktree, gated like everything else), **merged at `main` `df392c2`**:

- **DESIGN.md §2 (Typography)** — a *new* convention: raw/echoed quantitative or structured data renders in monospace `<code>`. The orchestrator scoped it deliberately narrowly — to *raw echoed values* (the recent-activity input→result summaries, raw data), explicitly **not** presentation figures (the stat-card numbers, table totals), so the rule sharpens the "this is echoed data" signal without monospacing the whole dashboard.
- **DESIGN.md §4 (Charts)** — *broadened*: **every** chart, including dashboard charts, uses the house JS charting library; **TradingView lightweight-charts** is named the default; hand-rolled SVG/canvas charts are **forbidden** as the primary chart; and the bar/histogram case the doc had never covered is added explicitly (volume/histogram → lightweight-charts `Histogram` series). This is the gap-closing edit — the dashboard/histogram blind spot that let the prompt slip through is now spelled out.
- **`.claude/agents/frontend.md`** — both conventions mirrored as build-to-DESIGN rules, for salience during regen.

Its QA gate (non-UI lane) returned **PASS** — CI 5/5 green on `1fa05b0`, all 59 flagged screenshots adjudicated #87 capture-noise (REAL=0; "no pixel can move" on a docs/agent-only change), DB N/A. The operator merged on *"y"*.

### A real `bin/merge-cleanup` footgun

The #227 merge surfaced a genuine tooling footgun worth recording. `bin/merge-cleanup 227` **errored with an "Unable to read current working directory"** failure because the main thread's shell cwd was *inside the worktree the script was removing* — once the worktree directory vanished out from under the shell, the script's later git steps couldn't run, and **the branch-delete step silently skipped** (its "already gone" was a false read). The orchestrator caught it:

> **"Merge is on `main` (`df392c2`) and the worktree's pruned, but the branch delete got skipped (the script couldn't run git from the dead cwd — its 'already gone' was a false read; both local and remote still exist). Finishing that, and double-checking the harvest content actually landed."**

It `cd`'d back to the repo root and finished the cleanup by hand. The lesson — a cleanup script that removes a worktree must not be invoked from a shell whose cwd is inside that worktree, or its post-removal steps silently no-op — is a real friction the historian flags; the same load-bearing-order concern CLAUDE.md already documents for the worktree-before-branch-delete sequence, hit from a different angle.

### Regen PR #228 — the page rebuilt from the harvested agents

With the harvest on `main`, the orchestrator dispatched the **frontend regen of the admin stats page as a direct follow-up PR — no issue** (the operator's call: *"No new issue"*). Critically, it branched **off the post-harvest `main`** so the agent read the *consistent, updated* conventions — a deliberate avoidance of the exact prompt-vs-doc mistake that caused this whole arc: *"That regen branches off `main` after #227 lands, so it reads consistent conventions (avoiding the exact override mistake that caused this)."*

The regen, **merged at `main` `24ca31e`**, delivered:
- **Deleted the hand-rolled `bar_chart_controller.js`** and added **`volume_trend_chart_controller.js`** driving a lightweight-charts **`Histogram`** series (the vendored bundle was already present from the amortization work, so **no importmap change** was needed).
- **Wrapped the recent-activity input→result summaries in `<code class="font-mono">`** per the new §2 convention.
- **Replaced the SVG `<rect>`-count system-test assertion with a real canvas pixel-paint assertion** — a blank chart now hard-fails CI. This is a strict upgrade in test rigor: the old inline-SVG analogue (`>= 1` rendered `<rect>`) became a genuine "did the canvas actually paint pixels" guard, exactly the protection DESIGN.md §4 prescribes for library charts.

A `code-reviewer` pass (**APPROVE**) earned its keep by surfacing a **pre-existing double-escape display bug**: the view helper double-escaped HTML-special characters, a defect that was invisible before but became obvious once the value sat inside a `<code>` tag rendering it verbatim. It was fixed with `truncate(escape: false)` plus a guard test (the head advanced to `ebb30da` for the fix; suite at 1009 runs / 100% coverage). So the regen not only carried the two new conventions but *flushed out* a latent bug that the new convention made visible — a small bonus of the "render echoed data faithfully in `<code>`" rule.

The QA gate's final PASS (on the true final SHA `ebb30da`, after a fresh re-dispatch — see below) confirmed the result by eye: the volume trend is now a real **lightweight-charts Histogram canvas** (peak bar accent-green, the rest coral, axis labels — not the old hand-rolled SVG), the recent-activity values render in distinct monospace `<code>` with special chars escaped exactly once, and the discarded badges from Chapter 120 are intact. The operator merged on *"merge"*.

### Process notes that recurred

Three frictions from Chapter 120 re-appeared and are worth recording for continuity:

- **Silent subagent death (#140) recurred again.** On #228 the operator twice noticed dispatched gate/review agents had ended without delivering verdicts — *"I don't see a QA agent dispatched"* / (earlier in the thread) *"I don't see a QA agent running"* — and each time the orchestrator re-dispatched a fresh QA gate and **gated the true final SHA** (`ebb30da`, after the double-escape fix advanced the head past the originally-dispatched gate's SHA). The same discipline as #225 in Chapter 120: never merge on a verdict whose SHA you can't confirm is current.
- **The `bin/merge-cleanup` cwd footgun** (above) — new this chapter.
- **A pre-existing post-login `assert_link "Admin"` system-test race** surfaced under full-parallel `test:system` (the frontend agent flagged it as not introduced by the regen — passes in isolation). It did **not** fire on the final CI run, but the orchestrator flagged it as a real pre-existing flake worth filing separately so it doesn't keep haunting the system tests.

### Agent/doc-driven? — yes, end-to-end

This is the chapter to point at when asking "does the agent-first loop actually work?" The full cycle ran inside one main-thread side quest, by the book: a design observation on a shipped page → the operator framing it as an *agent* change, not a page edit (*"changes we should make to the agents"*) → two surgical edits to **DESIGN.md (§2 + §4) and `frontend.md`** (the durable layer) → a **regen** that rebuilt the page from the harvested agents → the conventions queued to **propagate catalog-wide via iteration-0007's frontend sweep**. The one *code* change in the regen (the double-escape fix) was a latent bug the new convention exposed, fixed with a guard test — not a workaround for an agent shortcoming. And the whole arc kept the standing disciplines: every PR (harvest #227 and regen #228) went through the **QA gate**, and **nothing merged without explicit human instruction** (*"y"*, *"merge"*). The miss that started it — a chart that "defaulted to something simpler" — turned out not to be the agent drifting but the *prompt overriding the doc*, and the harvest hardened the convention precisely so that override can't recur silently.

---
