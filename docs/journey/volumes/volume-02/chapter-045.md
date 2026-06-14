## Chapter 45 — Two structural corrections folded in mid-flight: per-layer issues, and PR-first for *all* of `main` (2026-06-13)

The user surfaced a structural gap as a "side note," in the form of an opinion-seeking question:

> "Side note - this issue will only cover backend. We might want to make one issue per calculator and tag them `backend` and `frontend`? This would be a PM consideration, opinion?"

The assistant gave a **strong opinion: yes, split it — one issue per layer per calculator (`backend` + `frontend`), not one issue wearing both labels.** Three reasons, the second the one it found most compelling: (1) `Closes #N` only works cleanly per layer — a calculator is two PRs by two agents, and one issue spanning both means the backend PR can't honestly close it; (2) it makes *each agent a true spec→code regenerator*, because `spec:v1` as defined is fundamentally a **backend** artifact (intent, I/O, reference values — *math*), and the frontend needs *its own* spec (which modes/boxes to surface, the toggle, layout intent) to regenerate from each sweep — so per-layer issues keep the regeneration sweep honest for both layers; (3) it maps cleanly anyway (inventory stays one row per calculator; issues are *tasks*). Its first instinct on *timing* was to defer the restructuring until after the backend build, to keep it a focused pass.

The user overrode the timing and folded it in now:

> "Let's fold the issue thing sooner - at minimum, let's add both tags, tag the current one as backend, and update project manager to create 2 issues with the full spec because both will need it. Let's address that gap now and then proceed with the backend build"

And in the same stretch, the policy question from Chapter 44 got resolved — the user gave two directives the assistant read back: (1) **codify PR-first** for PM/iteration/docs work (no direct-to-`main`) going forward; (2) **this case is the authorized exception** — push these codification changes directly to `main`, then proceed. The assistant honored the small irony exactly: *"the commit that *establishes* PR-first will itself go straight to main (the bootstrap exception)."*

What landed (commit `c15d250`, direct to `main` as the authorized bootstrap exception):
- **Per-layer issues:** the `backend`/`frontend` labels were created; #30 relabeled `backend`; the Percentage **frontend** issue **#31** created carrying the *identical full spec body*; `engineering` redefined as non-calculator infra/agent/tooling work.
- **PR-first for all of `main`:** codified in `CLAUDE.md`, the PM def (git discipline + "two issues per calculator, dedup by name+layer"), `ARCHITECTURE.md §0/§3.2` (both layer issues carry the spec), and **`historian.md`** (the no-direct-push-to-main note — the journal must ride a branch/PR too).

A consequence the assistant flagged immediately and acted on: under the new rule, *mid-session `JOURNEY.md` journaling can no longer just commit to `main`* — so it began **holding the historian** until a PR-able moment (bundled with an iteration-log PR or at session end), flagging the saga-log gap as *"a deliberate choice, not an oversight."* This is the experiment's own discipline turning on its own bookkeeping.

**Agent-driven? ✅ (with an authorized hand-exception).** The label scheme, the two-issue convention, the frontend-needs-its-own-spec realization, and the PR-first rule all landed in the inherited contract + the agent definitions. The single direct-to-`main` push was a deliberate, surfaced, human-authorized bootstrap exception — the kind of honest carve-out the journal records as such. The deepest point: the user's "side note" exposed that `spec:v1` was implicitly *backend-shaped*, and the fix was to make the spec→regenerate symmetry explicit for both layers — a structural sharpening of the experiment's core artifact, caught before the asymmetry could calcify.

---
