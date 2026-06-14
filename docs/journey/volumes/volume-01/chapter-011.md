## Chapter 11 — The End-of-session checklist (2026-06-13)

With the journaling system live and verified end-to-end, the assistant offered the obvious next move — *"the **backend agent → the Percentage calculator** … that's where corrections either keep landing in agent definitions and shrink over time, or they don't"* — and asked whether to start measuring or keep sharpening tooling. The user kept sharpening, and added a new piece of process hygiene:

> "Mehehe not yet - let's also document a set of 'End of session' action items. I'll do my best to remind you to run end session steps before closing the session. For now, add 'dispatch historian agent' and 'verify no unstaged files' as the two items to check on for end of session"

The assistant accepted and folded in one refinement of its own, born from the mechanics of how the historian runs: at session *end*, the historian dispatch should **run to completion**, not fire-and-forget. In its words: *"a backgrounded run could get cut off before it commits when the session closes."* This is a deliberate inversion of the mid-session rule (Chapter 10), where the historian is explicitly fired *in the background* so the user never feels it. The two contexts call for opposite handling, and the checklist now says so.

**What got built.** A new **"End of session"** section in `CLAUDE.md` (commit `51c0b41`), with two items: (1) *"Dispatch the historian — and let it finish"* — journal everything since the coverage anchor, waiting for completion rather than backgrounding, *"since the session's closing"*; (2) *"Verify no unstaged files"* (`git status`; surface anything left so leaving it is a deliberate choice). The assistant wrote it as an explicitly **growing list** — the section text reads *"This list will grow"* — so future end-of-session hygiene just gets appended. It is framed as a main-thread responsibility triggered by the user's *"end session"* nudge.

A small meta-note closes the chapter, and it is itself a data point on the journaling discipline: the assistant **deliberately did not fire the historian** for this change. Its reasoning: *"a checklist addition is a minor process tweak, below the 'decision/pivot' bar, so it'll get swept up at the next real checkpoint or at end-of-session. Keeping the journaling signal-to-noise high."* (And so it was — this chapter was written in exactly that sweep.)

**Agent-driven?** ✅ A process convention added to the inherited contract (`CLAUDE.md`). No app code touched.

---
