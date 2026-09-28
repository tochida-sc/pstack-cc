# pstack-cc

English | [日本語](README.ja.md)

A Claude Code plugin marketplace for [pstack](https://github.com/cursor/plugins/tree/main/pstack), the Cursor plugin by Lauren Tan (poteto), converted to run in Claude Code. MIT licensed.

Extracted with history from `pstack-cc/` in [souljazzfunk/lab](https://github.com/souljazzfunk/lab/tree/main/pstack-cc).

## Install

In Claude Code:

```
/plugin marketplace add tochida-sc/pstack-cc
/plugin install pstack@lab
```

Skills are invoked as `/pstack:<name>` (for example `/pstack:poteto-mode`, `/pstack:how`). Run `/pstack:setup-pstack` once to choose which model each role uses; the defaults work without it.

## Docs

- Tutorial: [`pstack-cc/docs/tutorial.en.md`](pstack-cc/docs/tutorial.en.md)
- Skill map: [`pstack-cc/docs/skill-map.en.md`](pstack-cc/docs/skill-map.en.md)
- How the conversion works and how to pull upstream updates: [`pstack-cc/README.md`](pstack-cc/README.md) (Japanese)

## License

MIT. pstack itself: `vendor/pstack/LICENSE` (Lauren Tan). Conversion tooling: `LICENSE` (souljazzfunk).
