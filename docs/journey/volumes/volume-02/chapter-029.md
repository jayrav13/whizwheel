## Chapter 29 — Fan-out triage, and a stale-base finding the parallelism surfaced (2026-06-13)

With the agent merged, the user asked for the thing the agent stack was built to enable: *"do a full fan out of all 3 PRs using the dependabot agent just as a test run to see the fan out process. Then, if we don't plan on merging this blindly, let's comment in the PR with next steps but stage it for future work for now, not create a new issue or try and resolve it now."*

The assistant dispatched **three concurrent `dependabot-agent` instances**, one per PR — the first real parallel triage in the project. The fan-out *"worked cleanly … consistent output format, each reading real CI state and changelogs,"* and it surfaced a finding the assistant *"didn't have before"*:

> "these Dependabot PRs branched from an **old `main` (pre-foundation)**, so #2/#3's red CI is `db/schema.rb doesn't exist` — a stale-base artifact, **not** the bumps. Their status is unreliable until rebased. That's a genuine 'don't trust these reds at face value' insight."

A second, quieter experiment data point: the def fix from Chapter 28 *measurably improved accuracy*. On the solo run, the #3 agent had *inferred* the red came from `image_processing` dropping `ruby-vips` (flagging uncertainty — *"regardless of the precise line"*); on the fan-out, with the improved def (read the *full* job log), the #3 agent read the actual failure and correctly identified the **stale `db/schema.rb`** as the cause, while noting `image_processing` 2.0.2 itself *installs* fine. The assistant recorded the honest caveat too: *"the agent's *root-cause inference* can vary run-to-run; the fix was to make it read the log rather than guess — and it did."* Per the user's instruction, staged next-step comments were posted on all three PRs — no issues created, nothing merged or resolved.

**Agent-driven?** ✅ — three agent instances did the triage; the main thread only dispatched, sanity-checked, and posted the staged comments the user asked for. The chapter's value is twofold: a working demonstration of the **fan-out** pattern the branching/worktree conventions were designed to enable, and concrete evidence that a one-line def fix (full job log over `--log-failed`) raised diagnostic precision on the very next run.

---
