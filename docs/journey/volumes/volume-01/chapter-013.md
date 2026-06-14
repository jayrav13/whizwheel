## Chapter 13 — "Time for the foundation" — the implementation plan (2026-06-13)

After the snapshot/durability stretch, the assistant laid out the state of the world plainly — three working agents, the knowledge layer, green CI — and then the gap, in its own words: *"**No app foundation** (auth, RBAC, `Calculation` model, `Discardable`, CLI tasks, the first migration). **Zero calculators. Zero user-facing features.**"* The honest read it offered on the experiment was unchanged from the running assessment: *"Every decision has landed in an agent or a doc … But the experiment hasn't started *measuring* yet … Everything so far is foundation and instrumentation."* It framed the next move as *"the line we keep (rightly) walking up to: **the app-foundation plan** → **the backend agent** → **the Percentage calculator**,"* and called the repo *"a remarkably complete *workshop*"* whose next job was *"to actually forge the first thing in it."*

The user said go:

> "Time for the foundation, yes. Where do we begin?"

The assistant made one design point about *where* to begin that is itself a data point on the method: **no new brainstorm was needed**, because the design already lived in a doc. In its words: *"We already did the design work; `ARCHITECTURE.md` *is* the foundation's spec (schemas, the layering, soft-delete, auth, RBAC, the coverage gate are all pinned there). So the foundation goes straight to an **implementation plan** → build."* It enumerated the foundation's scope — `Discardable`; auth (`User`/`Session`/`Current`, no email/reset/signup); RBAC (`RoleType` seeded `ADMIN`, `Role`, `User#admin?`); `Calculation` + the `calculation_logs` view + first migration; CLI rake tasks; the SimpleCov 100% gate — and drew a deliberate **scope boundary**: the *calculator scaffolding* (`Calculators::Base`, the dynamic controller, the route, the autoload initializer) is **not** in the foundation, because *"'how a calculator is built and wired' is exactly its [the backend agent's] specialty. The foundation gives the backend agent a platform … to build *on*."*

One genuine, experiment-design decision was put to the user — how to execute — and it was resolved as **subagent-driven, per the docs**: *"general subagents executing the plan while reading `ARCHITECTURE.md` + `CLAUDE.md`, so your style rides in through the conventions."*

**The plan.** The assistant used the **writing-plans** skill and, before writing, grounded it in *ground truth* rather than assumptions — confirming the Rails 8 `authentication` generator exists (but choosing to **hand-write auth for determinism**, *"generator output varies by version"*), that `bcrypt` was commented in the Gemfile, that `simplecov` wasn't yet a dependency. The result — **5 TDD tasks** (Authentication; Soft-delete + RBAC; `Calculation` + the `calculation_logs` view; CLI rake tasks; the 100% coverage gate) — was committed docs-only as `d012985` (`docs: app-foundation implementation plan`). Two notes the assistant flagged for the user's eye: auth is hand-written (*"Task 1 is the security-sensitive one"*), and **the coverage gate is the last task** because *"turning on `minimum_coverage 100` before code exists trips on the empty state."*

It also named what this run *was*, beyond a feature: *"This is also the first time we **dogfood the full intended workflow**"* — PM mints the issue, branch off `main`, subagent-driven build with two-stage review, PR closing the issue, `ci-monitor` watches, human merges.

**Agent-driven?** ✅ The foundation went straight from the conventions doc to a plan, with no redesign — the architecture doc earned its keep as the spec. The plan is a doc; no app code yet.

---
