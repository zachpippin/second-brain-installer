# Agent instructions

| File | Who reads it |
| --- | --- |
| `/AGENTS.md` | The agent installing this repository. Start here. |
| `/INSTALL.md` | Step-by-step install, verify, and failure handling |
| `/CLAUDE.md` | Claude Code, pointed at the installer instructions |
| `vault/AGENTS.md` | The rule file copied into the person's vault |
| `agents/hermes/SKILL.md` | Hermes, after you copy this folder into its skills directory |

Grok Bot and other MCP clients do not get a private instruction file here. Point them at the vault's `AGENTS.md` and `scripts/mcp/gbrain.mcp.json`. Remote publishing is a separate step in gbrain's own guide. This installer does not run it.

gbrain does not index `AGENTS.md` or `CLAUDE.md` at a source root.
