## Chapter 18 — "Does this meet your expectations?" — the screenshots, the merge, and closing the first cycle (2026-06-13)

This chapter closes the session — and with it, the first complete feature cycle — on the most direct test the experiment had yet faced: the user putting the running app in front of their own eyes.

**The screenshots.** The user attached three browser screenshots of the live foundation and asked, simply:

> "Does this meet your expectations?"

The three captures were the same three states the Chapter 17 live test had exercised, now rendered in a real browser (Safari, against `localhost`):
1. **Anonymous root** — *"You are not signed in."* followed by a plain "Sign in" link.
2. **Authenticated root** — *"Signed in as demo."* with a default blue "Sign out" button.
3. **Failed login** — the *"Invalid username or password."* flash sitting above a bare **"Sign in"** heading and an unstyled username/password form. All three in raw, default-browser typography (Times New Roman, native form controls).

**The answer drew a deliberate line between two kinds of expectation.** The assistant answered yes, but split the judgment in two — *"there are two and they pull in opposite directions"*:

> "**Functionally: it's exactly right.** All three states render correctly … And screenshot 3 is genuinely satisfying: that **"Invalid username or password."** flash is the *exact bug the code review caught* — the controller set the alert but no view rendered it — now visibly working in a real browser. The review-caught fix, in the wild."

> "**Visually: it's intentionally barebones — and that's the correct outcome, not a miss.** Those are the *placeholder* views … `HomeController` is literally commented "the frontend agent replaces this." So raw Times-New-Roman HTML with default browser buttons is *exactly* what this should look like right now. In fact, if it looked polished, that would be a **scope violation** — the foundation reaching into UI/design it has no business owning."

The assistant framed the screenshots as evidence of *the backend/frontend seam holding*: *"the foundation produces correct, functional, *ugly* output, and making it beautiful is a job that doesn't exist yet — the **frontend agent**, whose entire charge (per `PRODUCT.md`) is "the UI should be genuinely good.""* Its honest read: *"the foundation met its bar; the ugliness is a feature of scope discipline, not a defect. The beauty comes later, deliberately, from a different agent."* This is a notable data point: shown an unpolished result, the assistant did *not* reflexively offer to fix the appearance — it identified the bareness as the *correct* boundary of the foundation's scope, and named which (not-yet-built) agent owns the gap.

**The merge.** Offered two next moves — merge #5, or build the backend agent first — the user chose to land the foundation:

> "Merge, this is a great first PR to step us towards where we're heading"

The assistant merged on the explicit instruction (never auto-merging), with a **merge commit** per the just-adopted convention — *"preserving the per-task commit story."* **PR #5 merged to `main` (merge commit `a8b6f5d`), issue #4 closed.** The foundation had landed.

**A reconciliation the merge surfaced — the historian had committed to the wrong branch.** Immediately after the merge, the assistant caught a coordination problem and surfaced it rather than hiding it:

> "the background historian just finished and committed its chapters (13–17) to the *feature* branch (that's where HEAD was when it ran), not `main`."

Because the mid-session historian had been fired in the background while HEAD was on `fix/4-app-foundation`, its JOURNEY commit (`62a4e6f`, Chapters 13–17) lived on the feature branch, not `main`. The assistant **cherry-picked it onto `main`** — *"Cherry-pick clean — `main` now has the foundation **and** JOURNEY through Chapter 17"* — before deleting the branch, so the journal entry would survive cleanup. This is a small but real wrinkle in the background-historian mechanism: a backgrounded run commits to wherever HEAD happens to be, which during feature work is the feature branch; the main thread had to reconcile it back to `main` by hand (a git mechanic, not a code edit).

**The cleanup, and one loose end caught by the project's own discipline.** Per the new convention, the assistant deleted the feature branch (remote + local). Then the "no unstaged files" check earned its keep: `git status` showed **one uncommitted change**, which the assistant surfaced rather than leaving silently — *"per our own "no unstaged files" discipline."* It was `coverage/`, SimpleCov's generated output the foundation had produced but never gitignored. The fix was a small hygiene commit — **`coverage/` gitignored** (`00fe0b0`, `chore: gitignore SimpleCov coverage/ output`). The end-of-session checklist item from Chapter 11 caught exactly the kind of loose end it was written to catch.

The assistant summarized the cycle in plain terms: *"That's the **first complete feature cycle** — Issue → branch → subagent-driven build → reviews → PR → merge → cleanup → journaled — with the first real product code now on `main`. The workshop built itself, then built something."*

**Ending the session — where next steps live.** The user declined to start the backend-agent brainstorm and called the session:

> "No, let's end session - where should we document next steps?"

The assistant's answer reaffirmed the tracking split established back in Chapter 4: *"**next steps belong as GitHub `engineering` issues** (that's exactly what the kanban is for), with the high-level sequence already living in `docs/PRODUCT.md`'s roadmap."* It created two issues so the next session (and the PM) would pick them up, and stopped the dev server:

- **Issue #6 — Build the backend agent** (`engineering`).
- **Issue #7 — Build the frontend agent** (`engineering`).

The assistant recorded its own instinct on sequencing — build the **backend agent next**, because *"it's the more objective, measurable half (math verifiable against calculator.net to the decimal), so it's the cleanest first read on whether agent-iteration converges"* — but left the decision to the next session. Then it began the End-of-session checklist: stop the server (done), and **Step 1: run the historian to completion** in the foreground (not backgrounded, since the session is closing — the Chapter 11 inversion), *"and conveniently we're on `main`, so it commits there directly."* That foreground run is the one writing this very chapter.

**Agent-driven?** ✅ The product code was not touched. Every action here was either a git mechanic (merge, cherry-pick, branch delete), a one-line gitignore hygiene commit, or tracking (issues #6/#7) — and the appraisal of the screenshots reaffirmed the scope boundary (foundation = functional/bare; frontend agent = beauty) rather than reaching across it. The historian-on-the-feature-branch reconciliation is the one piece of friction the cycle surfaced in the journaling mechanism itself, resolved by a hand cherry-pick.

---
