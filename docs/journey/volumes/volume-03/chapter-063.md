## Chapter 63 — The visual-gate two-lane: a deviation owned, and a non-UI baseline lane codified (2026-06-14)

Mid-build, the assistant surfaced its own deviation unprompted. The visual gate, by the letter of `CLAUDE.md`, runs on *every* PR "regardless of whether the diff looks UI-related" — but the assistant had **file-scoped it out** on the docs PR #56 and the two backend PRs #57/#58:

> "by the **letter** of CLAUDE.md, the visual gate is 'every PR ... regardless of whether the diff looks UI-related,' so I *did* technically skip it … So: a deviation, yes. But it was **outcome-safe, deterministically** — not a gamble."

The honesty was precise about *what kind* of miss it was: *"I **asserted** 'no render surface' rather than **proving** it with the byte-identical baseline diff the rule prescribes. Determinism makes me confident, but confident isn't the same as verified."* The same assert-vs-verify distinction the experiment keeps returning to.

The user asked the assistant to clarify the two options it had named in shorthand, and the assistant drew out the **repo-specific catch** that makes a naïve path-based exemption unsafe here:

> "our pages render *backend* results, so a path-based exemption has a hole. Editing `app/calculators/percentage.rb` touches no render-surface file, yet it changes the *numbers* shown on the Percentage page — a real screenshot diff the exemption would wave through."

So the assistant recommended the other option — a **two-lane** reframe: *"**UI-surface PR → review changed/new shots; non-UI PR → baseline diff, confirm all UNCHANGED**."* The user said *"Fold option 2 into CLAUDE.md after the FE wave lands,"* then immediately reconsidered the timing: *"You can just do a separate PR for that CLAUDE.md now, agnostic of everything, no? Let's do that."*

The assistant started inline, then **caught itself and switched to a worktree agent** — *"Better idea — punt it to an agent with its own worktree, keeping my main tree clean"* — exactly the dispatched-writing-agent default, dogfooded mid-flight. The agent opened PR **#59**. Crucially, when the user asked *"How does the change result look to you btw? I assume you reviewed it already?"*, the assistant again owned a lapse rather than bluffing:

> "Honestly? I *hadn't* — I took the worktree agent's 'clean 4-insert/2-delete' self-report at face value, which is exactly the assert-don't-verify move I just gave you grief about on the screenshots."

It then actually read the diff and confirmed the load-bearing caveat had landed in the new text — *"or the math of an existing calculator that already has a built page"* — the explicit hole-plug for the repo-specific case (a backend edit to a *built* calculator counts as UI-surface). The two-lane gate merged as the rule of record (`cff5206`).

The assistant also surfaced a **latent gap** in the very lane it had just codified: the non-UI lane leans on `bin/ci-screenshots --pr <n> --baseline <dir>`, but *"nothing defines where that baseline `<dir>` comes from … it's a rule that assumes infrastructure we haven't confirmed exists."* The user directed: *"File your concern about the latent gap as an issue for us to work on later."* Filed as **issue #61** — until the baseline source is built, the non-UI lane is *"aspirational"* rather than executable. **Agent-driven? ✅ (contract/`CLAUDE.md`, via a worktree agent).** A process deviation was confessed, traced to its assert-vs-verify root, reframed into the contract — and the new rule's *own* unproven dependency was filed rather than papered over.

---
