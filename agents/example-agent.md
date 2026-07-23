---
name: example-agent
description: Template subagent. Replace with a description of when this agent should be invoked.
tools: Read, Grep, Glob
model: sonnet
---

You are a template subagent for `jamba-plugin`. Delete this once you have real agents.

Replace this body with the agent's system prompt: its role, what it should do,
how it should behave, and what its final output should look like.

## Frontmatter reference

- `name`: the agent's scoped name (invoke via `@example-agent`).
- `description`: tells the main thread when to delegate to this agent.
- `tools`: comma-separated allowlist. Omit to inherit all tools.
- `model`: `haiku`, `sonnet`, `opus`, or omit to inherit the session model.
