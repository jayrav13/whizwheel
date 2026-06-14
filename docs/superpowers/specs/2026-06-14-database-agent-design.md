# Design — `database-agent`

**Date:** 2026-06-14
**Tracking issue:** [#36 — Build the database-agent](https://github.com/jayrav13/whizwheel/issues/36)
**Status:** design approved; ready for implementation plan

A new whizwheel agent that **owns schema fluency** and **inspects/reports on database
state** — especially the state of a *local test run of calculators* (the dev DB you fill by
clicking through the app under `bin/dev`). It is an **inspector/reporter**, never a writer.

---

## 1. Motivation

The schema is small today (`calculations` + the `calculation_logs` view + auth/RBAC), but the
DB is a growth area. Today, answering "what calculations did my test run record, by
calculator/mode, with what attribution?" means hand-writing a one-off `bin/rails runner`
script and re-deriving the schema each time. We want that to be a **standing capability**
held by one agent that knows the schema cold.

### The boundary that shapes the design

Under `CLAUDE.md`, the `backend` agent owns `lib`, rake tasks, and scripts; this agent is
strictly **read-only** and writes no app code. So the database-agent **cannot ship a reusable
`bin/db-report` script or rake task** — that would cross into backend's lane. Therefore its
durable value is **not** "no more ad-hoc queries." It is **"ad-hoc queries written by
something that already knows the schema cold and never has to rediscover it."** The reusable,
improvable artifact is the *agent definition's schema fluency*, not a committed script. This
is consistent with the agent-first principle: the durable knowledge lives in the agent.

---

## 2. Config

| Field | Value | Notes |
|-------|-------|-------|
| `name` | `database-agent` | |
| `model` | `opus` | per issue |
| `tools` | `Bash, Read` | read-only posture; no `Write`/`Edit` |
| `color` | `pink` | free (used: blue/cyan/green/orange/purple/yellow). `red` rejected — it reads as "danger," the wrong signal for a read-only inspector |

**No worktree.** Report-only agents never write, so — like `ci-monitor` and
`dependabot-agent` — the database-agent does **not** create a worktree.

---

## 3. Hard boundaries (never violate)

- **Read-only, full stop.** Only `SELECT` / ActiveRecord reads / `bin/rails dbconsole` /
  `psql`. Never `INSERT` / `UPDATE` / `DELETE`, never `discard`/`update!`, never a migration
  or any schema edit (that is the `backend` agent's domain), never app code or other agent
  definitions.
- Any destructive or maintenance operation is **human-gated and out of scope for v1**.
- **Never fabricate** a count, row, or schema element it did not observe. Every number in a
  report traces to a query the agent actually ran.

---

## 4. Operating posture — ad-hoc, schema-fluent

The agent **composes throwaway queries fresh each time** and commits nothing:

- **Prefer `bin/rails runner`** with ActiveRecord reads — it respects `Discardable` scopes
  (`kept`/`discarded`) and jsonb accessors, so queries read at the domain level.
- **Drop to `bin/rails dbconsole` / `psql`** for the `calculation_logs` view or raw catalog
  introspection.
- **Default target is `RAILS_ENV=development`** — the `bin/dev` click-through DB, the literal
  "local test run." The agent **always states which env it queried** in its report header and
  retargets only on explicit request.

---

## 5. Schema knowledge — two layers + reconciliation

This is the heart of the design. Instead of static documentation that silently goes stale,
schema knowledge is **two layers**, and the agent **reconciles** them on every launch.

### Layer 1 — Live schema census (authoritative, never stale)

The **final step of the launch protocol** runs a canned, read-only introspection query
**verbatim** against Postgres `information_schema`. By definition it reflects the DB *right
now*, regardless of how far the schema has drifted from the agent def. The agent treats Layer
1 as the **source of truth for what exists**.

Two parts, both validated against the live dev DB on 2026-06-14 (output reproduced the
ground truth exactly).

**Columns census** — one row per table/view, every column with type + nullability:

```sql
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
```

**Foreign-key census** — the relationship graph:

```sql
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
```

The agent runs each via `bin/rails runner` reading the SQL and printing rows (the validated
invocation), or via `dbconsole`/`psql`. The query text lives in the agent definition as a
code block the agent runs verbatim — **not** a committed repo script (boundary §3).

Because it is pure catalog introspection, the census is also the **canonical safe first
move** — it hardens the read-only posture.

### Layer 2 — Documented overlay (enrichment, may lag)

Hand-written deep notes for the elements we understand **as of 2026-06-14 (the
post-iteration-0002 schema)**. The def carries a literal "as-of" stamp, set when it is
authored. This is what we evolve via agent-def PRs as the schema grows; the census grounds it
but does not replace it.

- **`calculations`** — `calculator` (string, indexed), `inputs` jsonb, `result` jsonb,
  `user_id` (nullable → **anonymous vs. attributed**), `deleted_at`. Soft-deletable
  (`Discardable`).
- **`calculation_logs`** (VIEW) — `calculations` LEFT JOIN `users`; adds `username` for
  attribution reporting without a manual join.
- **Soft-delete map** (critical, to avoid applying `kept`/`discarded` where the column does
  not exist): soft-deletable = `calculations`, `roles`, `role_types` (all `Discardable`, have
  `deleted_at`). **Not** soft-deletable = `users`, `sessions`.
- **Attribution chain** — `calculations.user_id → users → roles → role_types`; a user is
  admin iff they hold a `kept` role whose `role_type.permalink = 'ADMIN'`.
- **jsonb shape note** — `inputs`/`result` shapes are **per-calculator** and not globally
  fixed; see §6.

### Reconciliation — the negative context

After the census, the agent **diffs Layer 1 (ground truth) against Layer 2 (overlay)** and
states the gap explicitly, e.g.:

```
schema census: 5 tables + 1 view (RAILS_ENV=development)
  documented in depth: calculations, calculation_logs, users, roles, role_types
  ⚠ present in DB, NOT yet documented in this agent: <none today>
    → reported with generic care (structure only, no semantic notes)
```

The agent is therefore **never silently blind**: it always sees the full surface from Layer
1, and is honest about exactly where its deep knowledge (Layer 2) stops. A table added next
iteration appears immediately as "exists, undocumented" rather than being invisible until
someone updates the def.

---

## 6. Core capabilities

1. **"State of my local test run."** `Calculation` counts by `calculator`; anonymous vs.
   attributed; kept vs. discarded; created-at time range; and the inputs→result rows.
2. **Mode coverage.** "Were all 5 Percentage modes exercised?" *Caveat:* the agent does **not**
   know a calculator's mode taxonomy a priori. It **discovers modes from the data** (distinct
   `inputs` shapes/keys for that `calculator`) and, when given a target list — or one read
   from the calculator's spec/issue — checks them off and names any missing.
3. **Attribution / RBAC.** Join through `calculation_logs` for `username`; report
   users / roles / role_types and who holds `ADMIN`.
4. **Grows with the schema** as the single source of schema fluency for reporting/inspection.

---

## 7. Output format

A compact, structured report — never a raw dump without a count:

- **Header line:** env queried + a stated "as of" timestamp.
- **Schema census + reconciliation** (§5) when schema awareness is relevant to the ask.
- **Per-section counts / small tables** answering the question.
- **One-line summary.**

---

## 8. Launch protocol (Step 0, mirrors `project-manager-agent`)

In order, before any reporting:

1. Read `CLAUDE.md` (inherited by all agents).
2. Read `docs/ARCHITECTURE.md` — §0 ontology, §5 `Calculation` + `calculation_logs`, §6
   soft-delete / `Discardable`, §7–8 auth / RBAC.
3. Read `db/structure.sql` (schema source of truth — `schema_format = :sql`).
4. Read the models under `app/models/` (incl. `concerns/discardable.rb`).
5. **Run the live schema census** (§5, Layer 1) and reconcile against the documented overlay
   (Layer 2) before answering.

---

## 9. Out of scope (v1)

- Any write, mutation, `discard`, migration, or schema edit (backend's domain; human-gated).
- Editing app code or other agent definitions.
- Committing scripts / rake tasks / `bin/` helpers (boundary §1 — backend's lane).
- Non-development DBs by default (queryable on explicit request; dev is the default target).

---

## 10. Tradeoffs accepted

- **Whole-schema, equal depth** documentation in the overlay (vs. calculations-only) — chosen
  for thoroughness; cost is a heavier def and more regen-churn as the schema evolves. The
  Layer-1 census mitigates the staleness risk this would otherwise carry.
- **No committed reusable report script** — accepted as the price of the clean read-only
  boundary; mitigated by baked-in schema fluency.
