## Chapter 49 — Checking the DB live, and filing the database-agent (2026-06-13)

The user reported testing the calculator live and pointed at a brewing need:

> "Here's a brewing thought - I think at some point, we'll want to be able to talk to the DB directly to be able to determine the state of a local test run of calculators. I do think we should have a database-agent - an agent that has full understanding of the schema. The schema today is simple, so this may seem like overkill, but I think this is an area of potential growth and so I want to invest right now in a database-agent."

Then, in a small self-correction the assistant honored exactly: *"Actually I take that back, let's create a database-agent as an issue. For now, in main thread, just check the DB for my tests."*

So the assistant did both. It queried the DB and reported the live test data: **13 calculations recorded, all 5 modes exercised, math all correct, both anonymous (6) and attributed-to-alice (7)** — `percent_of` (20% of 50 → 10.0), `change` (50 ±20% → 60.0/40.0), `difference`, `percent_of_what`, `what_percent`, every value checked. *"The full stack is verified end-to-end."* It also surfaced one **data-cleanliness observation** worth the evaluation (not a bug): the persisted `inputs` carries the *whole* attribute set, not just the active mode's fields (e.g. a `percent_of` row stores `v2: nil, direction: "increase"` from the form defaults, via `to_calculation` using `attributes`) — *"a candidate agent-def/spec refinement."*

And it filed the database-agent: **issue #36** (`engineering`, **deferred**) — a read-only agent owning schema fluency that answers *"what's the state of my local test run?"* (the exact query the assistant had just hand-written), with a boundary baked in (inspects/reports only; never mutates data or touches migrations — that stays the backend agent's). The assistant noted the meta-point: *"that issue *is* agent-first investment — instead of repeatedly hand-rolling runner scripts, we'll have a durable agent for it."*

**Agent-driven? ✅** The user's instinct to invest in a durable agent *now* (while the schema is still simple) — rather than keep hand-rolling DB queries — is the experiment's thesis applied prospectively: the recurring need becomes an agent definition, deferred but captured. The live DB check itself was a one-off main-thread hand-action, explicitly authorized as the interim until #36 is built.

---
