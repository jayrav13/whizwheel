## Chapter 9 — CI/CD green + the ci-monitor agent (2026-06-13)

CI was failing on every push. Root causes, diagnosed from the logs: (1) no `db/schema.rb` (a fresh app with zero migrations) — fixed by switching to **SQL schema format** and committing `db/structure.sql` (the *correct* long-term choice, since the upcoming `calculation_logs` **view** can't be represented in Ruby schema); (2) `test:system` `LoadError` — fixed by adding a tracked `test/system/` dir. All five jobs went green.

Then: *"Let's codify a CI/CD monitor similar to in ../tenor for all pushed commits and PR's — they should be pushed to generic subagents (or hell, we create one?)."* We created one: **`bin/ci-watch`** (deterministic status: `0`=pass/`1`=fail/`2`=pending/`3`=none) plus a **report-only `ci-monitor` agent** (Sonnet) that watches a run and, on failure, diagnoses the root cause from the logs — never edits, never merges. CLAUDE.md now requires watching CI after every push/PR and forbids auto-merge. The agent was dogfooded immediately: dispatched via read-and-adopt, it watched its own commit and reported a correct green verdict.

**Agent-driven?** ✅ A third agent (`ci-monitor`) + a script + a convention. The CI fixes themselves were infra (config + a `.keep`), honestly noted as hand-edits — but small and outside the calculator-build path the agents own.

---
