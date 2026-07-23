---
description: Template skill. Replace this with a one-line summary of what the skill does and when Claude should use it.
---

# Example Skill

This is a template. Delete it once you have real skills.

The body is the instruction Claude follows when the skill is invoked. Use
`$ARGUMENTS` to capture text the user types after the skill name.

Greet the user named "$ARGUMENTS" and briefly explain that this is the
`jamba-plugin` example skill, then ask what they'd like to build.

## Notes

- Invoked as `/jamba-plugin:example-skill <args>` (plugin name is the namespace).
- Add `disable-model-invocation: true` to the frontmatter to make it
  user-invoked only (Claude won't trigger it automatically).
- For multi-file skills, add supporting files in this folder and reference them
  from here.
