# Contributing

The sample vault is fiction. Do not add real people, employers, addresses, phone numbers, account identifiers, or notes from a private vault.

Before you open a pull request:

```sh
scripts/scrub-check.sh
scripts/scrub-check.sh --self-test
scripts/lint-markdown.sh
shellcheck -s bash scripts/install.sh scripts/update.sh scripts/doctor.sh scripts/uninstall.sh scripts/lib/*.sh
shellcheck -s sh scripts/setup.sh scripts/sync.sh scripts/scrub-check.sh
```

`.scrub-denylist` at the repository root is gitignored. Use it for private terms that must fail the scrub check locally. Do not commit that file.

gbrain flags in `scripts/setup.sh` and `scripts/sync.sh` should match current gbrain help. If a flag cannot be confirmed, document it as a TODO instead of guessing.

This project is MIT, copyright Zach Pippin. gbrain and Obsidian are separate projects and are not affiliated with this kit.
