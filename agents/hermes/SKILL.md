---
name: obsidian-vault
description: Search and update the fictional-sample Obsidian vault through gbrain. Use when answering from notes, filing an inbox capture, or logging a session.
---

# Obsidian vault

Use this skill when the user asks about the vault, Sam Rivera's sample notes, or wants a capture filed into the wiki.

Also follow the repository `AGENTS.md`. Grok Bot and other MCP clients use that same policy even when they do not load this skill.

## Search before asking

Run `gbrain search "<query>" --source obsidian-vault`, or the `mcp_gbrain_search` tool when Hermes namespaced it. On a verbs-only surface use `recall` or `entity`. Read the markdown files if gbrain is down, and say so.

## Write-back

- Update `wiki/people/`, `wiki/projects/`, or `wiki/topics/` in place. Do not add a second page for the same subject.
- Keep the inbox note. Set `status: filed` and link the wiki page.
- Append `sessions/YYYY-MM-DD.md` for this session.
- Frontmatter keys: `type`, `tags`, `created`, `updated`, `sources`.
- Cite the note you used. Never write secrets, phone numbers, home-directory paths, or an email outside `example.com`.

Write the markdown file, then run `scripts/sync.sh DEST`. `gbrain put SLUG --source obsidian-vault < page.md` also writes the file into the vault.

## Do not

- Do not import unrelated directories.
- Do not turn on embeddings, ambient writeback, or `gbrain mcp expose` unless the user asks.
- Do not treat `templates/` as facts.
