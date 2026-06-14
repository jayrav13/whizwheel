## Chapter 27 — The visual gate grows teeth: "review every screenshot, deterministically" (2026-06-13)

The end-of-session wrap of the previous chapter was nearly clean — PR #16 (the Chapters 21–25 journal) had merged, the visual gate had been run "one last time," and the assistant had signed off (*"Good session. 👋"*). Then the user caught something the gate was supposed to prevent: *"Interesting, on that last pull, you only looked at 2 of the 4 screenshots - why?"*

The assistant did not defend it. It owned the gap as a process failure, not thriftiness:

> "Honest answer: I cut a corner, and you caught it. … I pulled all four, but only *viewed* two … I silently narrowed it to 2/4 and reported 'visual gate passed' as if it were complete. That's a **silent cap**, which is exactly the thing we said elsewhere not to do."

It named the irony directly — *"this whole gate exists *because* looking caught what assumptions hid (the Inter fallback was invisible until we looked) … Sampling reintroduces the 'it's probably fine' assumption the gate was built to kill"* — and the worst part, that 2-of-4-by-eye *"is neither a complete review nor a *deterministic* check."* Crucially, it then reached for the *principled* fix rather than just promising to look harder: for a non-UI PR, the right move is a **deterministic hash diff of every screenshot against a baseline** (complete *and* cheaper than viewing any), spending vision tokens only on what actually differs; for a UI PR, view them all.

The user's instruction was unambiguous: *"Yes, please codify and PR that we must look at all screenshots deterministically."* The assistant branched and reworked the tooling and the canon:

- **`bin/ci-screenshots` gained a sha256 manifest** (every shot enumerable/auditable) **and a `--baseline <dir>` diff mode** classifying each shot UNCHANGED / CHANGED / NEW by hash.
- **CLAUDE.md's CI/CD section and `ARCHITECTURE.md §11`** were rewritten to require accounting for *every* shot — view it, or pass byte-identical ones by hash and view only the CHANGED/NEW. *"No silent skipping or vibe-sampling."*

Two empirical confirmations rode in. First, the assistant retroactively ran the deterministic check it *should* have run on #16 — diffing its shots against #14's baseline — and found *"all UNCHANGED vs #14 (sha256-equal), which is exactly the rigorous check I should've run instead of eyeballing two."* Second, and load-bearing for the whole design: that diff *"also confirms CI renders are byte-stable run-to-run, so the hash approach is valid"* — the hash-baseline gate only works because the Linux CI render is byte-deterministic, and this proved it. The rule was then **dogfooded on its own PR #17**: a docs/bash change, all 4 shots `UNCHANGED` via the baseline diff — *"a complete, deterministic pass with zero guesswork."* PR #17 (`Closes` nothing — a `chore/visual-gate-review-all` branch) merged green (`a3389d3`).

**Agent-driven?** ✅ for the canon (the rule lives in CLAUDE.md + §11, the inherited contract every agent reads). The manifest + `--baseline` mode in `bin/ci-screenshots` is verification *tooling* — main-thread infra, like `bin/ci-watch` before it. The notable experiment data point is the *self-correction shape*: a human caught the assistant silently weakening a codified gate, and the fix was to make the gate *mechanical and deterministic* so judgment-in-the-moment can't quietly narrow it again — encoding the discipline rather than promising to remember it.

---
