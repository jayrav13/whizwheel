## Chapter 17 — The first time the app ran: a live end-to-end login test (2026-06-13)

The assistant executed the user's ordered plan exactly.

**Rename / push / PR.** `foundation` was renamed → **`fix/4-app-foundation`** and pushed; **PR #5** opened with `Closes #4`. Per convention, `ci-monitor` was fired in the background to watch it — and reported **green** (all 5 jobs). The assistant *"await[ed] your explicit say-so to merge"* — never auto-merging, per the project's own rule.

**The startup review** the user asked for resolved a small assumption: *"no Procfile, no foreman — this is an importmap + propshaft app (no JS/CSS build step), so `bin/dev` is just `exec bin/rails server`. So the start command is simply **`bin/dev`**, and `bin/rails db:prepare` is the idempotent 'migrate-if-needed' (creates DB, applies pending migrations, seeds). No foreman needed here."* The user's instinct (*"maybe here it's foreman run start? Let's review"*) was reviewed and corrected with evidence, and the migrate-if-needed concern was answered by `db:prepare`.

**CLAUDE.md gained two sections** — committed to **`main`** (not the feature PR, because *"conventions belong on `main`, not in the feature PR"*) as `0eb429d` (`docs: add branching/PR workflow and app-startup conventions to CLAUDE.md`): the **Branching & PR workflow** (the adopted tenor-style flow — `fix/N-desc`, worktrees-going-forward, `Closes #N` in the PR, merge-commit-not-squash, never auto-merge, cleanup) and **Starting the app** (`bin/rails db:prepare && bin/dev`; no foreman).

**Then — the first time the app actually ran.** Back on the feature branch, the assistant prepared a real Postgres DB and exercised the CLI: *"`db:prepare` seeded the ADMIN role, created user #1 (`demo`), granted admin — verified `users=1, admins=1, roletypes=1`."* It started the server (HTTP 200) and ran a **full live end-to-end login test** through the running server with a CSRF token and cookie jar. The result, in its words:

| Test | Result |
|---|---|
| Anonymous root | `not signed in` ✅ |
| Login form | `<h1>Sign in</h1>`, CSRF token present ✅ |
| Login as `demo` → root | **`Signed in as demo`** ✅ |
| Wrong password | **`Invalid username or password`** flash shown ✅ |

As the assistant put it: *"That exercises the *whole* stack live — CSRF, the signed session cookie, `authenticate_by`, the flash fix from review — plus the CLI."* The app was *"**running at http://localhost:3000** (login `demo` / `password123`, an admin)."* Note the last row: the *"Invalid username or password"* flash is precisely the bug the code-quality reviewer caught in Chapter 14 — its fix, verified live against a real server.

The assistant closed with the experiment data point in plain terms: *"This was **the first real product code**, and it was built **entirely subagent-driven** — five TDD tasks, each reading `ARCHITECTURE.md` + `CLAUDE.md`, with reviews that caught a genuine bug (the silent failed-login), all fixes applied through subagents. The agent-first discipline held: every correction went through the process, not a manual patch. So far, on this evidence, the loop produces working, tested, reviewed code."* PR #5 was left green and unmerged, awaiting the user's explicit instruction — pointing next at *"the **backend agent → the Percentage calculator** — where the convergence experiment finally starts *measuring*."*

**Agent-driven?** ✅ The first product was built and corrected entirely by subagents reading the conventions docs; the only hand-typed steps were git mechanics (rename/push/PR), the CLAUDE.md convention edits, and the manual run that *verified* the agents' output. The conventions docs proved sufficient to carry the user's style into code written by agents that never saw the conversation.

---
