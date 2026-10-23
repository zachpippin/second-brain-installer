# Vault agent instructions

You are working with a template Obsidian vault that gbrain indexes. The sample notes are fiction about Sam Rivera, a hobbyist woodworker and developer. Do not add real people, employers, addresses, phone numbers, or secrets.

Codex and other agents that read this file should follow it. Claude Code also has `CLAUDE.md`. Hermes has `agents/hermes/SKILL.md`. Any MCP client, including Grok Bot, uses the same rules.

## Search before asking

Before you ask the user a question the vault might answer, search.

```sh
gbrain search "the question" --source obsidian-vault
```

Use the source id from `.gbrain-source` in the vault when it is different. On the memory-verb surface, `recall` and `entity` are the read tools. If gbrain is not available, read the markdown under `wiki/`, `inbox/`, and `sessions/` directly and say that search did not run.

Keyword search is the keyless default. An empty result is not proof the note is missing when embeddings are off and the wording does not match. Say so.

## Write-back policy

1. Search before creating a page. If a wiki page already covers the subject, update that page. Do not create a second page for the same person, project, or topic.
2. Append the day's work to `sessions/YYYY-MM-DD.md`. One file per day. Create it from `templates/session.md` when it does not exist.
3. Never store secrets. That includes API keys, tokens, passwords, private keys, phone numbers, home-directory paths, and overlay-network hostnames. If an email is required, use `example.com` only.
4. Cite sources. Put vault links or URLs in the frontmatter `sources` list and name them in the prose. When a gbrain result includes a source id, also cite `[source-id:slug]`.
5. The markdown file is the note the user opens in Obsidian. Either edit the file and run `scripts/sync.sh DEST`, or write through gbrain:

```sh
gbrain put wiki/projects/example --source obsidian-vault < page.md
```

`gbrain put` writes `slug.md` under the source path (`file_written` / `write_through`). Then keep the frontmatter valid. Do not enable ambient writeback, embeddings, or connectors unless the user asks.

## Frontmatter

Every note, including session logs and inbox captures, starts with:

```yaml
---
type: person
tags:
  - people
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: []
---
```

`type` is one of `person`, `project`, `topic`, `session`, `inbox`, or `map` (the vault home page only). `sources` is a citation list. It is not a gbrain source id. Optional `status` on inbox notes is `open` or `filed`.

Update `updated` when you change a page. Do not rewrite `created`.

gbrain's default pack `gbrain-base-v2` declares `person` and `project`. It does not declare `topic`, `session`, or `inbox`. Import and `gbrain put` store those types as-is and warn. Do not fork the user's schema pack unless they ask.

## Layout

| Path | Use |
| --- | --- |
| `inbox/` | Raw captures. Leave the original note in place when you file it. |
| `wiki/people/` | One page per person. |
| `wiki/projects/` | One page per project. |
| `wiki/topics/` | Concepts that more than one project uses. |
| `sessions/` | Agent session logs named `YYYY-MM-DD.md`. |
| `templates/` | Blank forms. Do not treat them as facts. |
| `attachments/` | Files linked from notes. |

Link with vault paths: `[[wiki/people/sam-rivera|Sam Rivera]]`.

## Filing an inbox note

1. Search for an existing wiki page.
2. Update that page, or create one from the matching template when search finds nothing.
3. On the inbox note, set `status: filed`, set `updated`, and add a link to the wiki page.
4. Add the inbox link to the wiki page's `sources`.
5. Record the search, the edit, and the citations in today's session log.

The sample pair `inbox/2026-03-02-raised-bed-sketch.md` and `wiki/projects/garden-planner.md` is the pattern.

## Clients

Local stdio, from gbrain's install guide:

```sh
claude mcp add gbrain -- "$(command -v gbrain)" serve --surface full
codex mcp add gbrain -- "$(command -v gbrain)" serve --surface full
```

Generic MCP config: `scripts/mcp/gbrain.mcp.json`.

Hermes, from gbrain's Hermes guide (`--args` last, one `--env` flag):

```sh
printf 'Y\n' | hermes mcp add gbrain \
  --env GBRAIN_HOME="$HOME" GBRAIN_SOURCE=obsidian-vault \
  --connect-timeout 60 \
  --command "$(command -v gbrain)" \
  --args serve --surface full
```

Verify with `hermes mcp test gbrain`. Copy `agents/hermes/` into the skills directory your Hermes install uses. This kit does not guess that path.

Grok Bot and other remote MCP clients should follow gbrain's current client guide. Do not run `gbrain mcp expose` unless the user asks to publish the brain.
