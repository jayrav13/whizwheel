## Chapter 64 — The picker saga: a taste observation becomes a codified rule and sweeps three calculators (2026-06-14)

This is the session's headline. Trying the live app, the user questioned not a bug but an *element choice*:

> "My thoughts - our iterations in the past did the trick here. However, is this the right UI element under the 'I know…' section? The pills? Kick off a frontend agent to recommend a different UI element to be used for this picker. Based on the reply and our discussion here, we'll ask the FE agents to sweep all calculators with the update to the FE agent"

The assistant immediately recognized the agent-first shape: *"get a recommendation, decide, then encode it in the **frontend agent definition** and sweep every calculator — so the fix lives in the agent, not in N hand-edited pages."* It dispatched a frontend agent in **advisory mode** (recommend-only, read-only).

### The diagnosis: element choice is a separate axis from spacing

While the advisory ran, the user spotted a related symptom on the now-live BMI page — its US/Metric pills looked *"scrunched up together."* The assistant did not theorize; it captured the *live* page with headless Chrome to see exactly what the user saw, then delivered the load-bearing insight:

> "the diagnosis is the interesting part: **it's not a spacing regression.** I verified the markup uses the iteration-0002 scale (`flex flex-wrap gap-x-3 gap-y-4`) and `mode-pill` has correct padding — the building blocks are right. The problem is that **a 2-option selector rendered as wrap-pills is the wrong *element***."

This is the chapter's core: iteration 0002's spacing scale *was* applied — the cramp was not a regression of that work. The real gap was a dimension the design system had never pinned: *"the spacing scale handles *crowding*, but *element choice* is a separate axis the design system hadn't pinned down."* The user chose to fix it systemically rather than patch it (*"agent-first it is. BMI's scrunched pills stay as-is for now and get fixed *systemically* when the sweep turns the US/Metric selector into a segmented control — no throwaway patch the sweep would just overwrite"*).

### The mode-picker rule

The advisory memo came back sharp, and its key reframe was that the *control* was already right (a native radio `<fieldset>` — single-select, no-JS-safe) and only the *presentation* was wrong. It proposed a rule keyed on count and label length:

- The control is **always** a native radio `<fieldset>` posting `inputs[mode]`.
- **Segmented control** at **N ≤ 3 and short labels** (Percentage's Increase|Decrease).
- **Selectable option-list** at **N ≥ 4 or any multi-word/long label** (Ohms' 6 modes, Percentage's 5).
- Raw `<select>` is **never** the primary picker (hiding the modes hides the calculator's value).

### Prototype → live A/B → codify → sweep

The user chose the validate-then-propagate path. The assistant prototyped the option-list on **Ohms only** (PR #63), and when the user asked *"Do we need to restart the server in that worktree for me to try it?"*, the assistant set up a **second server on `:3001`** for a live A/B — old pills at `:3000`, the new option-list at `:3001`. The user's verdict was unequivocal:

> "Oh that's perfect"

The assistant then re-stated the conditions (the user asked it to remind them), the user said *"Do it,"* and the codify+sweep fan-out went out — **three agents on disjoint files**: a codify agent (`DESIGN.md §4` "Mode picker" + a `frontend.md` directive, PR #64), a Percentage sweep (5-mode picker → option-list, PR #66), and a BMI sweep (US/Metric → segmented control, PR #65).

### The deliberate "don't trust an unreloaded agent definition" engineering — probed by the user

The user asked exactly the right question about the parallelism:

> "Btw, might be a dumb question, but the sweeps were happening in parallel for codification. The sweeps didn't *rely* on codification, right?"

The assistant confirmed they did **not**, by design, and explained the mechanism plainly:

> "The rule reached the sweep agents **two ways, and I deliberately used the one that doesn't depend on #64:** 1. **As explicit instructions in their prompts** … So they were *told* the rule, not made to *read* it. … In fact, the timing proves it: I dispatched the codify agent and the two sweep agents **in the same message**, so when the sweep agents ran their launch protocol and read `DESIGN.md`, #64 wasn't merged yet … They never saw the codified rule."

It named the pattern: *"don't trust that an edited agent definition is reloaded mid-session — hand the agent the instruction explicitly."* The real dependency the sweeps *did* have was **#63** (merging the Ohms prototype first, to put the `.mode-option` CSS on `main` for reuse) — which is why #63 was merged *before* the sweeps were dispatched, while the codify PR #64 was safely parallel (disjoint files *and* rule-by-prompt).

### The proof shot

Both sweeps came back green. The reveal centered on a single Percentage screenshot:

> "**Percentage — the proof shot** (`12-percentage-change`): on this *same page*, the 5-mode picker is the **option-list** *and* the Increase | Decrease sub-toggle is still the **segmented control** — both presentations of the rule, side by side, each where it belongs. That's the rule *discriminating correctly* in a single screenshot."

The four PRs merged (`56d07db`), all three calculators now speak one picker language, and the assistant verified the BMI fix *live on `:3000`* — closing the loop on the original scrunch report rather than trusting CI: *"you spotted it by eye → diagnosed as wrong-element → memo → codified rule → swept → verified on the same server you were looking at."*

### The reflections worth quoting

The user's excitement was explicit and recurring — *"Is this not the coolest process of building?"*, then *"this is wildly exciting"* — and on closing the iteration, the operator articulated what was actually being built:

> "So we're truly building in preferences, almost 'taste'. And right now we're advising it to pick one vs the other, but eventually we can define the entire concept (i.e. the selector recipes based on number of selections) or something (not something to think about right now, just thinking out loud)"

The assistant named the same direction back — a declarative **selector-recipe** keyed on selection count/shape that the agent *resolves* rather than *interprets* — and parked it per the user's "thinking out loud." It also kept the celebration honest: *"'exciting' converts to 'real' only when those three PRs come back green and the screenshots actually show clean pickers"* — and noted the duct tape underneath (the `gh` hang, the watcher killing the server, the SimpleCov-in-parallel number that under-reports every time, the hand-reconciled three-file collision), framing the experiment as partly *"whether that duct tape keeps shrinking. Right now it is."* **Agent-driven? ✅** — `DESIGN.md §4` + `frontend.md` carry the rule; every page change was a from-spec agent sweep, not a hand-edit.

---
