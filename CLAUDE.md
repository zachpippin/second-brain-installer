# Claude Code

Follow `AGENTS.md`. It is the vault policy: search before asking, update the wiki page instead of duplicating it, log every session to `sessions/YYYY-MM-DD.md`, never store secrets, and cite sources.

Register the local gbrain server with:

```sh
claude mcp add gbrain -- "$(command -v gbrain)" serve --surface full
```

gbrain also documents a Claude Code plugin (`/plugin marketplace add garrytan/gbrain` and `/plugin install gbrain@gbrain`). Install one registration, not two servers with the same name. PGLite allows one owner process at a time.

Optional and off by default: the Local REST API plugin plus `scripts/mcp/mcp-obsidian.mcp.json`. This template does not ship community plugins. Prefer writing markdown in the vault and running `scripts/sync.sh`.

Do not start a personal-agent bootstrap, a private repository, or ambient writeback unless the user asks.
