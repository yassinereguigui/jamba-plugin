# CI / CD design — jamba-plugin

Status: draft for approval. Source of truth for how this repo builds, validates, reviews, and
ships. Grounded in the repo's own `continuous-delivery` skill (greenfield guide).

## Philosophy: the pipeline is feature zero

From the greenfield CD guide: *"The validations you put in the pipeline on day one define the
quality standard... They are the mold that shapes every line of code that follows."* This repo is
greenfield, so we build the pipeline before the real skills flow through it.

### Translating CD nouns to a plugin repo

| CD concept | This repo |
|---|---|
| The artifact | The plugin directory tree |
| Build / test / package | `claude plugin validate --strict` + JSON / frontmatter / markdown checks |
| "Deploy hello world to prod" | Make the plugin installable via a marketplace, with `example-skill` as the walking skeleton |
| Production | A user running `/plugin install jamba-plugin@…` and it loads |
| Immutable artifact | Explicit semver `version` in `plugin.json`; releases pinned to commit SHA |
| Single path to prod | merge to `main` → deterministic gate green → installable. No side doors |

**Core rule (CD): only deterministic checks gate the merge.** AI review and prose checks are
advisory and never block.

## Layer 1 — deterministic gate (blocking)

Runs on every push / PR to `main`. Fast, offline, no secrets required for the core gate.

1. **`claude plugin validate . --strict`** — authoritative structural check. `--strict` fails on
   unrecognized fields and missing metadata. Runs with no API key (offline). The community
   marketplace review pipeline runs the same check, so this is day-one parity with the real
   distribution gate. Also validates `marketplace.json` once it exists.
2. **JSON validity** — `plugin.json`, `hooks.json`, `monitors.json`, `.mcp.json`, `settings.json`,
   `marketplace.json`. (`validate` covers the manifest; this covers the rest.)
3. **Skill / agent frontmatter** — every `SKILL.md` has valid YAML frontmatter with a
   `description`; every agent has `name` + `description`. Small script; `validate` is
   manifest-focused.
4. **Markdown lint** — `markdownlint-cli2` across all markdown (330+ files today).
5. **Internal link check** — `lychee` on relative links (the skills cross-link heavily via
   `_index.md` / `INDEX.md`).
6. **Secret scanning** — `gitleaks`. Non-negotiable: `.mcp.json` will hold server configs/tokens.
7. **File hygiene** — `.editorconfig` + a check for stray files (`.DS_Store`, etc.).

Single entry point: `make validate` runs the identical checks locally and in CI.

## Layer 2 — AI review (advisory, never blocks)

Job: compare changed skills/agents against **good exemplars + a skill-authoring rubric**, not
generic prose. Exemplars: a vendored, pinned snapshot from `anthropics/skills` under
`ci/exemplars/`, plus a rubric in `ci/rubric.md` distilled from the official Skill Authoring
Guide (progressive disclosure, description quality, token efficiency, on-demand file loading).

Mechanism: for each changed `SKILL.md` / agent file, send the model one prompt = changed file +
exemplars + rubric → structured critique (gaps vs exemplars, frontmatter/description problems,
structure/token issues). Output posted as a PR comment (CI) or printed (local).

| Layer | Backend | Where | Cost | Notes |
|---|---|---|---|---|
| Fast loop | Local Ollama qwen3 (~30B) | Mac — `make review` + pre-push hook | $0 | Private, offline |
| PR backstop | Gemini free tier | GitHub Actions | $0 | 1M ctx fits the whole corpus; 1,500 req/day |

### Rejected: subscription Claude in CI

`claude-code-action` with `CLAUDE_CODE_OAUTH_TOKEN` does draw from the Claude subscription (not
metered credits). **But** Anthropic's Feb 2026 Consumer ToS restricts subscription OAuth tokens to
Claude Code and Claude.ai only; using them in CI/third-party automation is a violation with
account-ban risk. Anthropic's CI guidance is to use `ANTHROPIC_API_KEY` (paid credits) instead.
So the CI options are "pay" or "risk a ban" — both rejected. Running the real `claude` binary
locally is within bounds, but we use the local Ollama model instead to avoid the gray area
entirely.

### Also rejected: GitHub Models

Would be the obvious free-in-CI pick, but it is **fully retired on 2026-07-30**. Out.

## Layer 3 — prose (advisory; human-facing only)

Split by audience:

- **Human-facing** (`README.md`, `docs/`) → written like a person; run the `humanizer` skill.
  Optional `Vale`/`cspell` as advisory CI.
- **Model-facing** (`SKILL.md`, `agents/*.md`) → optimized for a model to consume: structured,
  explicit, token-efficient. These get the Layer 2 skill-authoring review, **never** human-prose
  rules.

## Deploy to production (CD best practices)

- **Marketplace = the deploy.** The repo doubles as its own marketplace: `.claude-plugin/marketplace.json`
  lists this plugin with a `./` source. Installable via `/plugin marketplace add <owner>/jamba-plugin`.
- **Walking skeleton first.** Ship with only `example-skill`, prove the full path
  (`marketplace add` → `install` → loads) before the real skills flow through it.
- **Immutable / controlled releases.** Bump semver `version` in `plugin.json` per release; tag in
  git; marketplace pins to commit SHA.
- **Single path.** merge to `main` → gate green → installable. Branch protection requires the gate.
- **Trunk-based.** Short-lived branches, integrate daily, `main` always deployable.

## Local developer loop

- `Makefile` / `justfile`: `make validate`, `make review`, `make fix`.
- **pre-commit** hooks mirror the fast checks (format, JSON, gitleaks) — "if it must hold every
  time, it belongs in a hook."
- **pre-push** hook runs `make review` (local Ollama) so feedback lands before code leaves the Mac.

## Delivery plan (thin vertical slices, each leaves things working)

- **Slice 0 — walking skeleton to prod:** `marketplace.json` + minimal CI gate (`validate --strict`)
  + branch-protection notes. Plugin installable end to end.
- **Slice 1 — full deterministic gate:** JSON + frontmatter + markdownlint + lychee + gitleaks +
  `.editorconfig` + `Makefile` + pre-commit.
- **Slice 2 — local AI review:** vendor exemplars + rubric + Ollama review script + `make review`
  + pre-push hook.
- **Slice 3 — CI AI review:** Gemini advisory PR comment on changed skills/agents.
- **Slice 4 — prose + release:** README/docs prose tooling (advisory) + versioning/release workflow.

## Open items

- Exact Ollama model tag (confirm with `ollama list`).
- Confirm GitHub as the CI host and that the repo will have a GitHub remote.
