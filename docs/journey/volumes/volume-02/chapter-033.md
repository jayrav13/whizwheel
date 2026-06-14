## Chapter 33 — A unique color per agent: a small legibility convention, parked behind the merge (2026-06-13)

A side quest ran alongside the #3 work: give each agent a distinct `color`. Claude Code supports a `color:` field in agent frontmatter, and none of the five definitions carried one. The assistant checked the valid values (*"`red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan`"*) and assigned each agent a **mnemonic** color tied to its role:

| Agent | Color | Rationale |
|-------|-------|-----------|
| `ci-monitor` | `green` | CI green / pass |
| `dependabot-agent` | `yellow` | dependency caution lane |
| `frontend` | `cyan` | the UI agent |
| `historian` | `purple` | the lore-keeper |
| `pm` | `blue` | planning / tracking |

The colors aren't arbitrary — each maps to the agent's job (green for the pass-watcher, yellow for the caution-lane triager, and so on), so the convention carries a little meaning rather than just decoration. The assistant `Read` each definition first, then inserted the `color:` line right after the unique `name:` line in each.

The notable thing is **how** it was sequenced, not the edit itself. The assistant **parked the color edits on their own branch** so `main`'s tree stayed clean for the in-flight #3 merge — *"Plan: hold #3 for green CI then merge + cleanup; meanwhile park the colors edits on their own branch so main's tree is clean, and open that as the follow-up PR after #3 lands."* After #3 merged, the branch was rebased on the freshly-updated `main`, pushed, and opened as **PR #23** (`7095189`, `chore(agents): give each agent a unique color`).

The full per-PR ritual ran on it despite being definitions-only markdown: `ci-monitor` watched CI green, then the **visual gate** — this time the *deterministic* path was available, because the just-merged #3 shots now stood in for `main`. The result: *"Visual gate: PASS deterministically — all 4 shots are sha256-identical to the post-merge `main` baseline (4 unchanged, 0 changed, 0 new). No eyeballing needed since nothing rendered differently, as expected for a definitions-only change."* This is the Chapter-27 baseline machinery doing exactly its job — a definitions-only change provably touches no pixels, so the gate passes by hash with zero image review, the cost-savings the determinism was built for.

**PR #23 was left open** at session pause. The assistant held it deliberately — the user had said *"follow-up PR,"* not *"merge it,"* and the never-auto-merge rule stands: *"PR #23 is ready to merge but I've left it open … the never-auto-merge rule stands. Want me to merge #23 now, or leave it for your review?"* So the chapter closes with the colors committed and CI-green on a branch, awaiting the explicit human nod — the merge-gate honored even for a trivial, self-evidently-safe change.

**Agent-driven?** This is agent-*definition* work (editing the `.claude/agents/*.md` files), so it sits squarely in the experiment's preferred lane — though the change is cosmetic frontmatter, not behavior. A hand-edit to the definitions, but to the definitions, which is where the experiment wants edits to live. It journaled itself in the background mid-session (*"journaling the dependency merge + the new agent-color convention in the background"*).

---
