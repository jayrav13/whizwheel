## Chapter 60 — Build-coverage tracking: a deliberate omission confirmed, a real gap surfaced, and an agent-first inventory column added (2026-06-14)

The user opened a separate thread with an observation: *"I guess we're no longer tracking anything around which calculators were migrated over in the repo/inventory itself. Check history, is that a decision we made?"* Rather than answer from memory, the assistant dug into the history — the inventory structure, its git log, the iteration logs, the PM def, and what is actually built — before concluding.

### The investigation — it was deliberate, and split across three layers on purpose

The assistant confirmed the omission was **a documented design decision, not a drift**:

> "no, this isn't something we dropped. It's a **deliberate, documented design decision**: build/migration status was never meant to live in the inventory."

It laid out the three-layer split per `CLAUDE.md`'s "How work is tracked": **`docs/inventory.md`** is the *catalog/backlog* (the 191-calculator universe with complexity + tags, kept idempotent so re-runs preserve manual corrections — *"a per-row 'built?' flag would fight that"*); **GitHub Issues** are the *task/build state* (each calculator gets a `backend` + `frontend` issue, **closed = built** — the PM def is explicit: *"To report status, read issue state … open vs closed"*); and the **iteration logs** are the *build record* per iteration. So "what's migrated" today is *exactly one calculator: Percentage* — verified consistent across all three layers.

But the assistant then surfaced the *legitimate* thing under the user's question — a gap the three-layer model genuinely had:

> "there's **no standing, committed rollup** in the repo that answers *'X of 191 built'* at a glance. It's **on-demand**, not an artifact … At 1-of-191 that's invisible; at 30-of-191 it'll feel like a gap."

It offered three options (a derived `inventory.md` column, a separate `docs/` coverage view, or leaving it on-demand), leaning toward the first — *"it puts the answer where you're already looking … and the PM already rewrites that file idempotently."*

### The decision — done agent-first: update the PM def, then regenerate from it

The user chose to close the gap, and was specific about the shape — including a readability improvement to the existing Source column:

> "yes let's add a column that show the PR's associated with the merge completion of that inventory item as a new column. Also, shorten source so that the display name is JUST the * in the expression `<url>/*.html` and, on click, we still go to the full URL … (to be clear, update the PM then regenerate)"

The user's parenthetical — *"update the PM then regenerate"* — explicitly named the agent-first sequence, and the assistant followed it exactly. It first encoded the two changes into the **PM definition** (the durable artifact): a new derived **`Built (PRs)`** column (sourced from live GitHub on each refresh), the **Source** column rendered as the `*` slug from `calculator.net/*.html` while still linking the full URL, and a **completed-first sort**. That PM-def change committed as `4e1867e`. *Then* it **dispatched the PM to regenerate `docs/inventory.md` from the new spec** (committed `4da06c4`) — not hand-editing the inventory, the same producer/consumer split the experiment uses everywhere.

The PM reported **DONE**: Percentage floated to row 1 with `BE #32 · FE #41` (correctly picking the *most-recent merged frontend PR* — the iteration-0002 regen #41, not the original #35), all **191 rows preserved**, Source slug-links intact, the 190 unbuilt rows below in the prior Category→Calculator order with blank `Built` cells. The assistant eyeballed it before opening PR **#49**, dispatched `ci-monitor` (per the just-firmed Chapter-59 rule), and the run came back green.

The assistant summarized what the column *is*: *"the column **is** the migration-coverage view you were missing"* — the standing, committed rollup that the on-demand model lacked, now derived (not hand-maintained, so idempotency holds) and living where the user already looks.

### Session close

The user closed the session: *"It's perfect, merge when complete and historian to end session as well."* The assistant ordered it correctly per the end-of-session rule — `ci-monitor` green → merge #49 + cleanup → historian (foreground, waited on, so it commits before the session ends) → final `git status` check. `ci-monitor` reported #49 green across all five jobs; #49 merged; `main` clean; and the historian was dispatched in the foreground as the close-out.

**Agent-driven? ✅** The build-coverage gap was closed agent-first, in the user's own prescribed order: the **PM definition** was updated first (the durable artifact — the new column, the Source slug rendering, the completed-first sort), *then* the PM was **dispatched to regenerate the inventory from it** — the inventory was never hand-edited. Two evidence points: (1) the assistant checked the *history* before answering whether the omission was deliberate (it was — a three-layer tracking split documented in `CLAUDE.md`), separating "documented decision" from "real gap"; and (2) the gap that *did* exist (no standing rollup) was closed by a *derived* column that respects the inventory's idempotency, rather than a hand-maintained flag that would fight it.

---
