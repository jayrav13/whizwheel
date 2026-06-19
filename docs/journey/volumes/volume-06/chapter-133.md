## Chapter 133 — A second silent death, but this time death-on-completion; the ci-watch flake recurs on the journal PR's own gate; session closed (2026-06-19)

This is a coda. After the five-PR merge train and the historian PR (#298) landed gated-PASS (Chapters 130–132), the session produced a small but genuine tail before the operator closed it: a *second* silent agent death with a new and instructive shape, a recurrence of the `bin/ci-watch` NO-RUN flake on the journal PR's own gate, and the operator's call to run the end-of-session steps with the 5-calculator round still held. Nothing here is a calculator result; the value is one operational lesson and two watch-items.

### A second silent agent death — but this time the work had already landed

With the iteration held, only two threads were left running under the 2-cap: the `github-agent` updating issue #295 (the hex / color-enum research ask, Chapter 132) and the QA gate on PR #298. QA came back PASS. The `github-agent` went quiet. The operator caught it, in the now-familiar phrasing:

> **"GH agent isn't running no more"**

The orchestrator did *not* read the transcript to check — it used the same side-effect-and-metadata reflex established earlier this session for the PM death (Chapter 131): output-file mtime idle (~27 minutes, no completion notification) plus a direct `gh` state check on the issue. The verdict it reported:

> **"Confirmed — the github-agent **died** (idle ~27 min, no completion notification), the same silent mid-run death. **But it finished the actual work before dying**: issue #295 *was* edited (updated 04:01 UTC, research section present). It just never returned its report."**

It then read the issue body to confirm the deliverable was fully there — all three research questions captured (whether `color:` frontmatter accepts **hex** representation; the **authoritative enumeration** of named colors available; and **recording that enumeration in the operator's global `~/.claude/CLAUDE.md`** so it's known up front and reusable across projects), with the forcing-function framing the operator had asked for (9 agents but only ~7–8 named colors in use, so full per-agent uniqueness likely *requires* hex — "the research isn't cosmetic, it's whether unique-per-agent is even achievable").

### The lesson: completion notifications are unreliable; verify the side-effect

The orchestrator named the pattern, and the distinction that makes it worth recording:

> **"that's **two silent agent deaths this session** (the PM earlier, now the github-agent) — but in *both* cases the agent **completed its work and died only at the final return step** (the PR/issue edit landed; only the report never came back). That's actually a *different* failure mode than iteration-0007's mid-run rate-limit kill — it's death-on-completion, and it means **completion notifications alone aren't reliable; verifying the side-effect (PR exists, issue edited) is the real signal.**"**

This is a genuinely new data point against the prior catalogue of agent deaths. iteration-0007's deaths (Chapter 128) were **mid-run** — the rate-limit killed agents *before* their work was done, requiring recovery of uncommitted worktrees. The #140 deaths were silent failures with no verdict. This session's two deaths (the PM in Chapter 131, the `github-agent` here) are a third shape: **death at the return step**, where the side-effect (issue edited, work landed) is complete and only the completion message is lost. Both deaths this session were detected the same way — output-file mtime gone idle plus a `gh`/git state check — and in neither case did the orchestrator have to re-run the work, because the work was already done. The operational rule the orchestrator drew is the durable takeaway: **when an agent goes quiet, verify the side-effect (the PR exists, the issue was edited, the commit was pushed) via `git`/`gh` rather than trusting — or waiting on — the completion notification.** It flagged this as a candidate harvest item / its own issue "if it recurs" — captured, not acted on, the round being held.

### The ci-watch NO-RUN flake recurred on #298's own gate

The QA gate on PR #298 passed (CI 5/5 green at head `282ff01`, non-UI visual lane all #87 capture noise, DB facet N/A — docs-only), but its report carried a flag that the orchestrator escalated to a watch-item: `bin/ci-watch --pr 298` again threw a false `rc=3` NO-RUN on all retries — the exact #261 flake. What makes this notable is the timing: PR #292 (the #261 fix) had *already merged to `main`*, and #298's branch was cut from post-#292 `main`, so in principle the flake should be gone. The orchestrator was explicit that this is unresolved:

> **"the `bin/ci-watch` NO-RUN flake hit *again* on #298's gate — and #298's branch was cut from `main` **after** #292 (the fix) merged, so in principle it shouldn't have. Either the QA agent ran an older copy of the script, or **#292 didn't fully fix the `--pr` resolution path**."**

It declined to act, recommending instead a confirmation on the *next fresh gate* before considering #261 truly closed: if the flake fires once more on a clean post-#292 branch, that's the signal to reopen #261 with the `--pr`-path case specifically. So #261 is **provisionally closed but watch-flagged** — the fix demonstrably hardened the `--sha` path (Chapter 130 showed `ci-watch --sha` agreeing with reality), but the `--pr` resolution path may still flake, or the QA agent may have run a stale copy of the script. A clean discrimination either way is one gate away.

### Session closed; the round still held

With the queue empty and every thread resolved, the operator called it:

> **"I'd like to end now, let's do end of session steps"**

The orchestrator ran the close-out deliberately. Its first move was the one that produced *this* chapter: rather than spin a fresh historian off `main`, it recognized the session's journal already lived in an open PR and routed the final pass to **continue the existing #298 branch**:

> **"I'll have the final historian **continue the #298 branch** (append the tail as a new chapter) so the whole session stays in one journal PR — no merge needed first."**

And — applying the lesson it had just drawn — it pre-committed to verifying the side-effect if this very historian run went silent:

> **"Given this session's two death-on-completion cases, if it goes silent I'll verify the side-effect directly (commit pushed to #298) rather than trust the notification."**

Per the end-of-session rule, the orchestrator **waited** for the historian (foreground, not backgrounded) rather than risk a backgrounded run being cut off before it commits.

At session close the state was: five PRs merged to `main` this session (#292, #293, #294, #296, #297; `main` at `0c66b84`); **PR #298** gated PASS and awaiting the human's explicit merge — and because this tail chapter pushes #298's head past the SHA QA gated (`282ff01`), the green verdict is now stale and #298 will want a quick re-gate (or at least a fresh CI confirmation on the new head) before merge, per the post-gate-push re-gate rule; issue #295 updated with the color research ask; and the **5-calculator iteration still held**, fully teed up (PM's pick + #286-first, both already decided), awaiting the operator's go to open.

### What this coda is evidence of

One durable lesson and two open watch-items. The lesson — **verify the side-effect, don't trust the completion notification** — is a refinement of the orchestration discipline this whole session honed: the same reflex that caught the PM death (Chapter 131) caught the `github-agent` death, and in both cases the work was already safe on the server. The two watch-items are deliberately left open rather than papered over: the `ci-watch --pr` flake on a post-#292 branch (a clean falsification of "#261 is fixed" awaits the next gate), and the death-on-completion pattern itself (a candidate harvest item if it recurs). The experiment's habit of capturing rather than patching held to the last message of the session.
