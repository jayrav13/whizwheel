## Chapter 66 — Closing the loop on its own bookkeeping: a stale column, an immediate fix and a durable rule, and a sort filed-then-folded (2026-06-14)

The conclusion turned into a fourth process-gap-to-contract conversion. The user, mid-close, asked an almost offhand question:

> "Oh ha, and did we ever update inventory?"

They had not. The assistant owned it plainly and named the drift the build-coverage column (added in Chapter 60, PR #49) was *supposed* to prevent:

> "Ha — good catch, and **no, we didn't.** The inventory's whole `Built (PRs)` column … is now *stale*: it still shows only Percentage in the completed block, while BMI and Ohms — both shipped and merged — are sitting down in the pending list with blank cells. That's exactly the kind of drift the column was meant to surface, and we drifted it."

The fix came in **two forms in one breath**, the recurring meta-pattern of the whole session — *"a stale column you spotted → an immediate fix (inventory regen) **and** a durable fix (the close-always-regenerates rule) in the same breath. That's the third process-gap-to-contract conversion this session (after the CI-monitor firming and the visual-gate lanes)."*

- **Immediate:** the assistant could not message the already-running PM mid-flight (*"`SendMessage` isn't available to me"*), so it dispatched a **second PM in parallel** to regenerate `docs/inventory.md` (disjoint file → clean), floating BMI/Ohms into the completed block with their `BE/FE` PR cells (PR #68). The regen agent even disambiguated BMI's backend PR correctly — picking the real build **#58** over the mistitled iteration-open **#56**, both of which referenced issue #52.
- **Durable:** at the user's direction (*"Let's make that yet another PR right now to update the PM with this"*), a worktree agent edited the **PM definition's "Close an iteration" procedure** to mandate inventory regeneration as part of every close — *"An iteration's built calculators and the inventory's `Built (PRs)` build-coverage column are the same fact … A close must never leave the inventory stale"* (PR #69).

Iteration 0003 itself was closed (PR **#67**) by the PM in its lane, logged honestly as the first multi-calculator parallel build and as *not a clean A/B*. Then the user filed one more refinement — issue **#70**: *"inventory completed calculators should be ordered by BE PR # ASC, and then the rest of the incomplete calculators should be alpha."* Rather than a separate PR, the user chose to **fold #70 into the inventory PR** (*"dispatch agent to add a commit to this branch specifically"*); the fold agent found the work already present on the branch from a prior run (commit `2834d79`) and **verified rather than duplicated** it, yielding the completed-block order **Percentage #32 → Ohms Law #57 → BMI #58** (BE-PR ascending), with `Closes #70`.

A small orchestration note the assistant flagged and then confirmed: #68 and #69 both edited `project-manager-agent.md`, but in **different sections** (Inventory "Sort order" vs Iterations "Close an iteration"), so git 3-way-merged them cleanly — *"The bet held — **#68 is `MERGEABLE / CLEAN`**, no rebase needed."* All PRs merged (`main` at `4d107a6`), every branch (local and remote) pruned, every worktree cleaned — *"the tree is spotless."* The user fired the historian foreground (*"historian timeeeee"*) to bank the arc.

Two post-conclusion beats opened while the historian ran (off the record, parallel and read-only): the user asked the PM to pick the **next five** calculators and to *"Replace the previous top 1 BMI memory with this for next time"* (BMI having now shipped — the parked memory is spent), and floated a possible `CLAUDE.md` update — *"we should prefer backgrounding agents unless otherwise specified (such as end of session historian)"* — a candidate orchestration-default tightening left for the user's call. **Agent-driven? ✅ (PM definition + PM-regenerated `docs/inventory.md`).** The session's fourth instance of the same loop: a gap spotted in practice, fixed both immediately *and* as a durable contract change at the layer that governs it.

---
