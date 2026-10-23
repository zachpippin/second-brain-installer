# Claude Code

The harness entry point is the repository-root `CLAUDE.md`. This copy points at the same policy.

Follow root `AGENTS.md` and root `CLAUDE.md`. Register gbrain with:

```sh
claude mcp add gbrain -- "$(command -v gbrain)" serve --surface full
```

Do not enable community plugins, ambient writeback, or a second gbrain server unless the user asks.
