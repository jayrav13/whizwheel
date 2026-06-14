## Chapter 5 — "How does the agent know our vision?" → ARCHITECTURE.md (2026-06-12 → 06-13)

The pivotal scaling question, in the user's words:

> "does the agent get all the information about what the structure looks like so then when we ask it to create, it knows our vision? How is that managed?"

The answer reframed the whole experiment: **don't put the vision in the agent.** Split it three ways — the **agent definition** holds durable role/style/discipline; a versioned **`docs/ARCHITECTURE.md`** holds the *current structural vision* (the conventions every agent ingests); and **reference implementations** become living templates. The agent gets one instruction — read the architecture doc first — exactly mirroring the PM's launch protocol. *"Onboard it like a human engineer."* This is why agents stay lean as the app grows.

So the next artifact designed was not the backend agent but the **conventions doc it would read.**

**Agent-driven?** ✅ The realization is the load-bearing insight for scaling the method.

---
