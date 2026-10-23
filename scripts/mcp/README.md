# MCP examples

These files are examples. Setup does not register them for you.

## gbrain

`gbrain.mcp.json` is the local stdio server from gbrain's install guide:

```text
gbrain serve --surface full
```

`GBRAIN_SOURCE` pins the vault source. The multi-source guide says an agent connection started with that variable is bound to the named source. Set `GBRAIN_HOME` in the same `env` block when your brain does not live under the default home.

Claude Code and Codex can register the same process with:

```sh
claude mcp add gbrain -- "$(command -v gbrain)" serve --surface full
codex mcp add gbrain -- "$(command -v gbrain)" serve --surface full
```

A client that cannot hold the full tool list can use `--surface starter` or `--surface verbs` instead of `--surface full`. PGLite allows one process to own the database at a time. Do not start two servers against the same local brain.

Grok Bot, Muse, and other hosted MCP clients are covered by gbrain's own guides. This kit does not run `gbrain mcp expose`.

## mcp-obsidian (optional)

`mcp-obsidian.mcp.json` follows the published config for [MarkusPfundstein/mcp-obsidian](https://github.com/MarkusPfundstein/mcp-obsidian) (MIT). It talks to the Local REST API community plugin, so Obsidian has to be running and that plugin has to be installed. This template does not enable community plugins, and the default write path is the vault files plus `scripts/sync.sh`.

The upstream sample uses a loopback address for `OBSIDIAN_HOST`. This example uses `localhost` so the repository stays inside the scrub check's documentation-address rule. Put the plugin's API key in your local client config. Do not commit it. `replace-me` is only a placeholder.

## Hermes

`hermes.config.yaml.example` matches the `mcp_servers` block in gbrain's Hermes guide, with `--surface full` and `GBRAIN_SOURCE` added using the documented flags. `hermes mcp add` can exit 0 when the handshake fails. Check `hermes mcp list` and `hermes mcp test gbrain`.
