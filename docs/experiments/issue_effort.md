# Issue effort & priority triage

A manually-maintained snapshot of the open-issue backlog with a Now/Later + effort read, used to plan which issues to knock out. **Snapshot date: 2026-06-14.** Not auto-updated — re-run `gh issue list --state open` and edit this by hand. ⭐ = now + low (quick warm-ups).

| Issue | Now/Later | Effort | Note |
|---|---|---|---|
| ⭐ #128 rename `inventory.md`→`INVENTORY.md` | Now | Low | pure rename + ref updates |
| ⭐ #144 FE agent: chart "did-it-paint" pixel-test + importmap packaging rule | Now | Low | agent-def codification of a proven lesson |
| #87 screenshot capture non-determinism | Now | Med | recurring gate tax; normalize scroll/focus/spinners |
| #111 SimpleCov parallel coverage undercount | Now | Med | every build agent works around it; needs verify |
| #109 integer coercion defeats `only_integer` | Now | Med | pairs with #110 (Base validation) |
| #110 non-numeric `:decimal` coercion not enforced | Now | Med | pairs with #109; do together |
| #147 historian efficiency (JOURNEY.md massive) | Now | Med | read-the-tail + split into volumes; worsening every session |
| #61 baseline source for non-UI gate | Later | Low | bundle with #87 |
| #112 financial semantic color | Later | Low | eyebrow half shipped (#120); needs a design call |
| #140 agent death (platform) | Later | Low | mitigation shipped (#142) — candidate to close |
| #15 `@apply` component extraction + theme radii | Later | Med | coordinate with #143/#107 |
| #93 visual-qa-agent | Later | Med | hand-rolled reviews work for now |
| #127 database-agent DB-persistence step | Later | Med | verification gap, not urgent |
| #143 promote stat-grid to one BLEND component | Later | Med | converges on next regen |
| #72 meta-agent for agent defs | Later | High | strategic |
| #107 frontend central registration | Later | High | **keystone — unblocks #122, #124, #143, #15** |
| #122 scalable catalog UI | Later | High | depends on #107 |
| #124 per-calculator info modal | Later | High | cross-cutting; depends on #107 |

## Clusters / sequencing
- Warm up with the two ⭐ (#128, #144).
- Then the Now/Med items pair up: **#109 + #110** (input validation in Base), **#87 + #61** (visual gate), plus **#111** (coverage) and **#147** (historian).
- The big lever is **#107** (High effort, but unblocks #122 / #124 / #143 / #15) — schedule deliberately.
