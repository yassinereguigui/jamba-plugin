# jamba-plugin

My library of Claude Code capabilities: skills, agents, hooks, monitors, and MCP servers,
packaged as a single Claude Code plugin.

## Layout

```
jamba-plugin/
├── .claude-plugin/plugin.json   # manifest (name, version, author)
├── skills/api-design/           # API design patterns (multi-file, references/)
├── skills/continuous-delivery/  # CD & delivery patterns (multi-file, references/)
├── skills/<name>/SKILL.md       # skills — model- or user-invoked, namespaced /jamba-plugin:<name>
├── agents/<name>.md             # subagents — invoked via @<name>
├── hooks/hooks.json             # event handlers (PreToolUse, PostToolUse, etc.)
├── monitors/monitors.json       # background watchers that notify Claude
├── .mcp.json                    # MCP server configs
├── settings.json                # default settings applied when enabled
└── bin/                         # executables added to PATH while enabled
```

Only `plugin.json` goes inside `.claude-plugin/`. Every other directory lives at the
plugin root.

## Develop and test locally

Load the plugin without installing it:

```bash
claude --plugin-dir ./jamba-plugin
```

After editing components, reload without restarting:

```
/reload-plugins
```

## Adding a component

- **Skill**: create `skills/<name>/SKILL.md` with a `description` in the frontmatter.
  Invoke as `/jamba-plugin:<name>`. Add `disable-model-invocation: true` to make it
  user-only. See `skills/example-skill/`.
- **Agent**: create `agents/<name>.md` with `name` and `description` frontmatter.
  Invoke via `@<name>`. See `agents/example-agent.md`.
- **Hook**: add an entry to `hooks/hooks.json` under the relevant event. The command
  receives hook input as JSON on stdin.
- **Monitor**: add an object to the `monitors/monitors.json` array with `name`,
  `command`, and `description`.
- **MCP server**: add an entry under `mcpServers` in `.mcp.json`.

The `example-skill` and `example-agent` are living templates — delete them once you
have real components.

## References

- Create plugins: https://code.claude.com/docs/en/plugins
- Plugins reference: https://code.claude.com/docs/en/plugins-reference
- Skills: https://code.claude.com/docs/en/skills
- Subagents: https://code.claude.com/docs/en/sub-agents
- Hooks: https://code.claude.com/docs/en/hooks
