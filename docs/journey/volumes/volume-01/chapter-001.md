## Chapter 1 — The premise (2026-06-12)

The user opened with a thought experiment, not a feature request:

> "I'd like to create an agent for the two major portions of the app, the frontend and the backend. Then, I want you to use those agents in order to actually build the app."

The motivating question, in their words:

> "does it make sense to iterate on and focus on the agents (from my perspective) which can encapsulate my engineering style and approach and can mimic each and then ask you to use them to build?"

And the reason it mattered beyond this one app:

> "while on small scale, this might be overkill, i want to start understanding how I can use this methodology for larger and larger apps … my goal becomes to fine tune my expectations for how each section is built, and then expect better and better results over time as I essentially converge on perfection."

**What the app is.** A reimagining of [calculator.net](https://www.calculator.net): *"All calculators with some potential differences."* A beautiful client UI; **all math on the backend.** The user framed quality precisely:

> "the highest quality will come from the best inputs, so the result will invariably match that. Our goal is to make those inputs as fantastic as possible."

The repo was a fresh Rails 8.1 app (Postgres, Hotwire, Minitest), zero commits. A blank canvas.

**The framing that stuck:** the durable, improvable artifact is the *agent definition*, not any calculator. Code from a session is disposable; an agent file compounds. The core discipline that falls out: **when output disappoints, fix the agent definition, not the code.**

---
