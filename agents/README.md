# Agent instructions

| File | Who reads it |
| --- | --- |
| `/AGENTS.md` | Codex and any agent that loads a root `AGENTS.md` |
| `/CLAUDE.md` | Claude Code |
| `agents/hermes/SKILL.md` | Hermes, after you copy this folder into its skills directory |
| `agents/AGENTS.md`, `agents/CLAUDE.md` | The same policy, for people browsing this directory |

Grok Bot and other MCP clients do not get a private instruction file here. Point them at root `AGENTS.md` and `scripts/mcp/gbrain.mcp.json`. Remote publishing is a separate step in gbrain's own Grok Bot guide. This kit does not run it.

`scripts/setup.sh` copies root `AGENTS.md` and `CLAUDE.md` into the vault directory when those files are not already there, so an agent opened on the copied vault still sees the policy. gbrain does not index `AGENTS.md` or `CLAUDE.md` at a source root.
