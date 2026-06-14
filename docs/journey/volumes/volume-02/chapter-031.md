## Chapter 31 — Re-triage, the merges we could make, and two findings filed (2026-06-13)

The rebases cleared the stale base. The user set the closing plan: *"merge 20 when CI/CD is done; run all 3 dependabot-agents in a fan out one more time; merge what we can, pause on what we cannot."*

The rebases had already landed asynchronously — all three now **behind by 0**, with #1/#2 flipping to green once rebased onto a `main` that has `structure.sql` (the stale `db/schema.rb` red gone), and #3's unit tests passing while system-test ran. The assistant flagged the predicted trap immediately: *"#3 already shows the exact trap I flagged: its unit tests pass because *nothing exercises image variants*, so the dropped `ruby-vips` stays invisible."* #20 merged, then a **second fan-out re-triage** against the fresh PRs surfaced a genuine **rule ambiguity**:

> "for the *same class* (CI-action, major, green, usage unaffected), the **#1 agent said GREEN-LANE** while the **#2 agent said NEEDS-HUMAN** (strictly applying 'any major → NEEDS-HUMAN', after explicitly catching itself rationalizing). #3 correctly stayed **NEEDS-HUMAN** with the full landmine analysis (and smartly *didn't* re-post a rebase, reasoning the verdict can't change)."

Two agents, same inputs, opposite verdicts — the def is genuinely ambiguous on whether a *major CI-action* bump is GREEN-LANE. The assistant filed it as issue **#21** (`agents` label, the deferred def-fix queue) rather than resolving it mid-session.

Per *"merge what we can,"* the assistant exercised the human override: **#1 and #2 are CI-action-only, green, changelogs confirm the majors are just runner-runtime bumps** that don't touch the project's usage — so they were merged as the human call the user's instruction authorized; **#3 paused** (green CI would be a false all-clear over the runtime landmine). Executing that merge surfaced the session's second finding — a real environmental constraint:

> "GitHub blocks the `gh` OAuth token from merging PRs that touch `.github/workflows/` without `workflow` scope. (#1 slipped through — inconsistent on GitHub's side — but #2 won't.)"

#1 merged (`5a5e5ed`); #2 was *blocked* — safe and green, but un-mergeable from the orchestrator's token. The assistant verified the true state rather than trusting ambiguous output (*"main still has `cache@v4`"*), retried once to rule out a transient, then presented the user three options (merge in the web UI / grant the scope / defer). The user granted the scope (`gh auth refresh -s workflow`), and #2 merged (`8bca569`). `main` CI was watched green after each merge per the project's own rule. Only #3 remains open, paused with clear next steps (add `ruby-vips` + a variant test).

**Agent-driven?** ✅ for triage (three agents re-triaged), with the merges and the scope-grant being human-gated by design. The chapter records *two* honest wrinkles worth the journal: (1) the GREEN-LANE rule for major CI-actions is **ambiguous enough that two agent instances disagreed** — captured as #21, a real "the def needs sharpening" data point rather than a quiet smoothing-over; and (2) a process constraint discovered in production — **the orchestrator cannot merge workflow-file PRs without `workflow` scope**, so the dependabot flow has a class of PRs that always require a human or a scoped token. Both were named plainly as constraints, not failures.

---
