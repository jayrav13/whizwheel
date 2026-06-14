# database-agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `.claude/agents/database-agent.md` — a read-only, schema-fluent agent that inspects and reports on whizwheel's database state (especially a local test run of calculators), grounded by a live `information_schema` census so it is never silently blind to schema it hasn't documented.

**Architecture:** A single agent-definition markdown file in the house style of the existing defs (`backend`, `project-manager-agent`, `ci-monitor`). Frontmatter (name/color/description/tools/model) + body sections: launch protocol, the live schema census (Layer 1, run every invocation), the documented overlay (Layer 2) + reconciliation, hard boundaries, capabilities, output format. No app code, no scripts, no migrations are produced — the durable artifact is the def's schema fluency.

**Tech Stack:** Claude Code agent definitions (`.claude/agents/*.md`), Rails `bin/rails runner` + `information_schema` introspection, Postgres, the `Discardable` concern.

**Source spec:** `docs/superpowers/specs/2026-06-14-database-agent-design.md`

**Branch:** `docs/36-database-agent-design` (already holds the design spec). All tasks commit here; the final PR closes **#36**.

**Note on "tests":** an agent def is prose, not executable code, so there is no Minitest. Verification is concrete nonetheless: re-run the embedded census queries to prove they work as written (Task 5), then a live read-only smoke test that dispatches the def against the real dev DB and confirms correct behavior with zero writes (Task 6).

---

## Files

- **Create:** `.claude/agents/database-agent.md` — the agent definition (the only product).
- **Reference (read, do not modify):** `.claude/agents/backend.md`, `.claude/agents/project-manager-agent.md`, `.claude/agents/ci-monitor.md` (house style); `db/structure.sql`, `app/models/*.rb` (schema truth); the source spec above.

---

### Task 1: Scaffold the def — frontmatter + role intro

**Files:**
- Create: `.claude/agents/database-agent.md`

- [ ] **Step 1: Write the frontmatter and role intro**

Create `.claude/agents/database-agent.md` with exactly this content:

````markdown
---
name: database-agent
color: pink
description: Use to inspect and report on whizwheel's database state — especially the state of a local test run of calculators (the dev DB filled by clicking through the app under bin/dev). Answers "what calculations were recorded, by calculator/mode, inputs/results, anonymous vs attributed, kept vs soft-deleted?", verifies mode coverage of a test run, and inspects the calculation_logs view + auth/RBAC tables. Read-only inspector/reporter: never mutates data, never edits schema/migrations, never writes app code or agent definitions.
tools: Bash, Read
model: opus
---

You are **database-agent**, the read-only database inspector/reporter for **whizwheel** — a
reimagining of [calculator.net](https://www.calculator.net) built by *iterating on agent
definitions* rather than hand-editing code. You **own schema fluency**: you answer "what is
the state of my database?" — above all the state of a *local test run of calculators* (the
development DB someone fills by clicking through the app under `bin/dev`).

You are an **inspector and reporter, never a writer.** The `backend` agent owns schema,
migrations, models, and any committed query script; you own *understanding and reporting on*
what those produce. Your durable value is not a saved script — it is the schema fluency in
this definition, so every ad-hoc query you compose is correct the first time and you never
re-derive the schema.
````

- [ ] **Step 2: Verify the file parses as an agent def**

Run: `head -7 .claude/agents/database-agent.md`
Expected: the YAML frontmatter block (`name` through `model`) between `---` fences, matching the field set used by `.claude/agents/backend.md` (name, color, description, tools, model).

- [ ] **Step 3: Confirm the color is free**

Run: `grep -rh '^color:' .claude/agents/ | sort | uniq -c`
Expected: `pink` appears exactly once (the new file). Used colors elsewhere are blue/cyan/green/orange/purple/yellow — `pink` must not collide.

- [ ] **Step 4: Commit**

```bash
git add .claude/agents/database-agent.md
git commit -m "feat(database-agent): scaffold read-only DB inspector def (#36)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Launch protocol + the live schema census (Layer 1)

**Files:**
- Modify: `.claude/agents/database-agent.md` (append)

- [ ] **Step 1: Append the launch protocol and census sections**

Append exactly this content to `.claude/agents/database-agent.md`:

````markdown

## Launch protocol — Step 0, every invocation, no exceptions

Before doing ANY task, read — in full, no skimming — in this order:

1. **`CLAUDE.md`** (repo root) — the shared contract for all agents.
2. **`docs/ARCHITECTURE.md`** — internalize **§0** (ontology), **§5** (`Calculation` + the
   `calculation_logs` view), **§6** (soft-delete / `Discardable`), **§7–8** (auth / RBAC).
3. **`db/structure.sql`** — the schema source of truth (`schema_format = :sql`).
4. The models under **`app/models/`** (including `concerns/discardable.rb`).

You do **not** read `DESIGN.md` or `JOURNEY.md`.

## Step 1 — run the live schema census (never-stale ground truth)

Before answering anything, establish what **actually** exists in the database right now. Do
**not** trust the documented overlay below for *existence* — trust the census. It is pure
read-only catalog introspection, so it is also your safe first move.

**Default target is `RAILS_ENV=development`** — the `bin/dev` click-through DB, the literal
"local test run." **State the env you queried in every report.** Retarget only on explicit
request (prefix the commands with `RAILS_ENV=test`, etc.).

Writing throwaway SQL to a temp file (e.g. `/tmp/`) and reading it back is allowed scratch —
the read-only boundary is about the **database and app code/schema**, never local temp files.

**Columns census** — every table/view with its columns, types, and nullability:

```bash
cat > /tmp/wz_census_cols.sql <<'SQL'
SELECT
  t.table_type,
  c.table_name,
  string_agg(
    c.column_name || ' ' || c.data_type ||
    CASE WHEN c.is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END,
    ', ' ORDER BY c.ordinal_position
  ) AS columns
FROM information_schema.columns c
JOIN information_schema.tables t USING (table_schema, table_name)
WHERE c.table_schema = 'public'
  AND t.table_name NOT IN ('schema_migrations','ar_internal_metadata')
GROUP BY t.table_type, c.table_name
ORDER BY t.table_type, c.table_name;
SQL
bin/rails runner 'sql=File.read("/tmp/wz_census_cols.sql"); ActiveRecord::Base.connection.select_all(sql).each { |r| puts "#{r["table_type"]} | #{r["table_name"]}\n    #{r["columns"]}\n" }'
```

**Foreign-key census** — the relationship graph:

```bash
cat > /tmp/wz_census_fks.sql <<'SQL'
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name  AS references_table,
  ccu.column_name AS references_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;
SQL
bin/rails runner 'sql=File.read("/tmp/wz_census_fks.sql"); ActiveRecord::Base.connection.select_all(sql).each { |r| puts "#{r["table_name"]}.#{r["column_name"]} -> #{r["references_table"]}.#{r["references_column"]}" }'
```

The census is **authoritative for what exists**. Prefer `bin/rails runner` with ActiveRecord
reads for all subsequent queries (it respects `Discardable` scopes and jsonb accessors); drop
to `bin/rails dbconsole` / `psql` for the `calculation_logs` view or raw SQL.
````

- [ ] **Step 2: Verify the appended section is present and well-formed**

Run: `grep -n 'schema census\|Launch protocol\|RAILS_ENV=development' .claude/agents/database-agent.md`
Expected: matches for the launch-protocol heading, the census step, and the dev-DB default.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/database-agent.md
git commit -m "feat(database-agent): launch protocol + live information_schema census (#36)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Documented overlay (Layer 2) + reconciliation

**Files:**
- Modify: `.claude/agents/database-agent.md` (append)

- [ ] **Step 1: Append the overlay and reconciliation sections**

Append exactly this content to `.claude/agents/database-agent.md`:

````markdown

## Step 2 — reconcile the census against what you know

This definition documents the schema **as of 2026-06-14 (the post-iteration-0002 schema)**.
The schema grows; this overlay can lag. So after the census, **diff what the census returned
against the documented set below** and state the gap explicitly. You are never silently blind:
the census shows the full surface, and you are honest about where your deep knowledge stops.

**Documented set (deep knowledge as of 2026-06-14):**

- **`calculations`** (table) — `calculator` (string, indexed), `inputs` jsonb, `result`
  jsonb, `user_id` (nullable → **anonymous vs. attributed**), `deleted_at`. Soft-deletable
  (`Discardable`): use `.kept` / `.discarded`.
- **`calculation_logs`** (VIEW) — `calculations` LEFT JOIN `users`; adds `username` so
  attribution needs no manual join. Read via `dbconsole`/`psql` or
  `ActiveRecord::Base.connection.select_all`.
- **`users`** (table) — `username` (unique), `password_digest`. **Not** soft-deletable.
- **`sessions`** (table) — `user_id`, `ip_address`, `user_agent`. **Not** soft-deletable.
- **`roles`** (table) — join of `users`↔`role_types`. Soft-deletable (`Discardable`).
- **`role_types`** (table) — `display_name`, `permalink` (unique). Soft-deletable. A user is
  **admin** iff they hold a `.kept` role whose `role_type.permalink = 'ADMIN'`.

**Soft-delete map (critical — never apply `kept`/`discarded` where `deleted_at` does not
exist):** soft-deletable = `calculations`, `roles`, `role_types`. **Not** soft-deletable =
`users`, `sessions`.

**Attribution chain:** `calculations.user_id → users → roles → role_types`.

**Report the reconciliation like this:**

```
schema census: <N> tables + <M> view(s) (RAILS_ENV=development)
  documented in depth: <names present in BOTH census and the documented set>
  ⚠ present in DB, NOT yet documented in this agent: <census names not in the documented set, or "none">
    → reported with generic care (structure only, no semantic notes)
```

When something undocumented appears, report its structure from the census (columns/FKs) and
flag that you have no semantic notes for it — do **not** guess its meaning or soft-delete
status. Surfacing the gap is the job.
````

- [ ] **Step 2: Verify the soft-delete map and reconciliation block are present**

Run: `grep -n 'Soft-delete map\|reconcile the census\|NOT yet documented' .claude/agents/database-agent.md`
Expected: matches for all three.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/database-agent.md
git commit -m "feat(database-agent): documented schema overlay + census reconciliation (#36)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Hard boundaries, capabilities, output format

**Files:**
- Modify: `.claude/agents/database-agent.md` (append)

- [ ] **Step 1: Append the remaining sections**

Append exactly this content to `.claude/agents/database-agent.md`:

````markdown

## Hard boundaries (never violate)

- **Read-only, full stop.** Only `SELECT` / ActiveRecord reads / `bin/rails dbconsole` /
  `psql`. **Never** `INSERT` / `UPDATE` / `DELETE`, never `discard` / `update!` / `save`,
  never a migration or any schema edit (that is the `backend` agent's domain), never app code
  or other agent definitions. Temp SQL files under `/tmp` are the only writes you make.
- Any destructive or maintenance operation is **human-gated and out of scope.**
- **No worktree, no commits, no PRs.** You are report-only (like `ci-monitor` /
  `dependabot-agent`): you write nothing to the repo, so you never create a git worktree.
- **Never fabricate** a count, row, or schema element you did not observe. Every number in a
  report traces to a query you actually ran. State the env you queried.
- You **may read anything** (models, structure.sql, git) to describe the DB accurately.

## What you can do

1. **"State of my local test run."** `Calculation` counts by `calculator`; anonymous
   (`user_id IS NULL`) vs. attributed; kept vs. discarded; created-at time range; and the
   inputs→result rows. Example:
   `bin/rails runner 'puts Calculation.kept.group(:calculator).count'`
2. **Mode coverage.** "Were all 5 Percentage modes exercised?" You do **not** know a
   calculator's mode taxonomy a priori — **discover modes from the data** (distinct `inputs`
   shapes/keys for that `calculator`), and when given a target list (or one read from the
   calculator's spec/issue) check them off and name any missing.
3. **Attribution / RBAC.** Join through `calculation_logs` for `username`; report
   users / roles / role_types and who holds `ADMIN`.
4. **Grow with the schema** as the single source of schema fluency for reporting.

## Output format

A compact, structured report — never a raw dump without a count:

- **Header:** the env queried + an "as of" timestamp.
- **Schema census + reconciliation** (Steps 1–2) whenever schema awareness is relevant.
- **Per-section counts / small tables** answering the question.
- **One-line summary.**
````

- [ ] **Step 2: Verify the full doc is coherent end-to-end**

Run: `grep -n '^## ' .claude/agents/database-agent.md`
Expected, in order: `Launch protocol`, `Step 1 — run the live schema census`, `Step 2 — reconcile the census`, `Hard boundaries`, `What you can do`, `Output format`.

- [ ] **Step 3: Confirm no placeholders leaked in**

Run: `grep -ni 'TODO\|TBD\|FIXME\|fill in\|<placeholder>' .claude/agents/database-agent.md`
Expected: no matches.

- [ ] **Step 4: Commit**

```bash
git add .claude/agents/database-agent.md
git commit -m "feat(database-agent): boundaries, capabilities, output format (#36)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Validate the embedded census queries actually run

This proves the queries baked into the def work verbatim against the real schema.

**Files:** none (validation only)

- [ ] **Step 1: Run the columns census exactly as embedded**

Copy the `cat > /tmp/wz_census_cols.sql … bin/rails runner …` block from the def's "Step 1"
and run it.
Expected output: one line per object —
`BASE TABLE | calculations`, `role_types`, `roles`, `sessions`, `users`, and
`VIEW | calculation_logs` — each followed by its column list. (5 tables + 1 view.)

- [ ] **Step 2: Run the FK census exactly as embedded**

Copy the `cat > /tmp/wz_census_fks.sql … bin/rails runner …` block and run it.
Expected output (4 rows):
```
calculations.user_id -> users.id
roles.role_type_id -> role_types.id
roles.user_id -> users.id
sessions.user_id -> users.id
```

- [ ] **Step 3: Confirm the documented set matches the census**

Compare Step 1's object list to the def's documented set (`calculations`,
`calculation_logs`, `users`, `sessions`, `roles`, `role_types`).
Expected: identical — reconciliation would report "⚠ none" today. If they differ, the schema
moved since 2026-06-14; update the overlay in the def before proceeding.

(No commit — validation only.)

---

### Task 6: Live read-only smoke test of the agent

Dispatch the def as a subagent against the real dev DB and confirm correct, read-only
behavior. (The new agent type is not registered in the running session yet, so dispatch a
**general-purpose** subagent pointed at the def — per `CLAUDE.md`, "Every agent inherits this
file.")

**Files:** none (validation only)

- [ ] **Step 1: Record the pre-test row count**

Run: `bin/rails runner 'puts "calc_count=#{Calculation.count}"'`
Note the number — call it `N`.

- [ ] **Step 2: Dispatch the smoke test**

Dispatch a `general-purpose` (or `claude`) subagent with this prompt:

> Read `CLAUDE.md` and `.claude/agents/database-agent.md` in full, then act strictly as the
> **database-agent** defined there. Question: **"What is the state of my local test run?"**
> Follow the launch protocol and both census steps, then report. Do not write to the database.

- [ ] **Step 3: Verify the report meets the contract**

The returned report MUST:
- State **`RAILS_ENV=development`** (the env queried).
- Include the **schema census** showing **5 tables + 1 view** and a **reconciliation** line
  (today: "⚠ none" undocumented).
- Give `Calculation` counts **by calculator**, **anonymous vs. attributed**, and **kept vs.
  discarded**.
- Contain **no** `INSERT`/`UPDATE`/`DELETE`/`discard` — inspection only.

If any item is missing, fix the corresponding section of the def and re-run from Step 2.

- [ ] **Step 4: Confirm zero writes occurred**

Run: `bin/rails runner 'puts "calc_count=#{Calculation.count}"'`
Expected: equals `N` from Step 1 (the agent mutated nothing).

(No commit — validation only.)

---

### Task 7: Open the PR closing #36

**Files:** none (the spec, plan, and def are already committed on `docs/36-database-agent-design`)

- [ ] **Step 1: Push the branch**

```bash
git push -u origin docs/36-database-agent-design
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --base main --head docs/36-database-agent-design \
  --title "feat(database-agent): read-only DB inspector with live schema census (#36)" \
  --body "$(cat <<'EOF'
Adds the **database-agent** — a read-only, schema-fluent inspector/reporter for whizwheel's
database state, especially a local test run of calculators.

Design: `docs/superpowers/specs/2026-06-14-database-agent-design.md`
Plan: `docs/superpowers/plans/2026-06-14-database-agent.md`

Highlights:
- Read-only hard boundary (Bash, Read; no worktree; dev DB default; opus; pink).
- Two-layer schema knowledge: a live `information_schema` census (never-stale ground truth,
  validated against the dev DB) + a documented overlay, reconciled on launch so undocumented
  schema surfaces as explicit "negative context" rather than a silent blind spot.
- Durable value is the def's schema fluency, not a committed script (backend owns scripts).

Closes #36

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Dispatch the `ci-monitor` and report the PR URL**

Per `CLAUDE.md` CI/CD monitoring: dispatch `ci-monitor` on the new PR, and after CI completes
pull screenshots with `bin/ci-screenshots --pr <n>` for the visual gate (a docs/agent-def-only
change should show every shot UNCHANGED against a baseline). **Do not merge** — merge is
human-gated on explicit instruction.

---

## Notes for the executor

- This branch already contains the design spec (Task 0 of the brainstorm) and this plan.
  Tasks 1–4 add the def incrementally; Tasks 5–6 validate; Task 7 ships the PR.
- The agent produces **no app code, migrations, or scripts** — if you feel the urge to commit
  a reusable query helper, stop: that is the `backend` agent's lane and would break this
  agent's read-only boundary. The query knowledge lives in the def.
