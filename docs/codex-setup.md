# Using ios-claude-skills with Codex

This repository is also a [Codex plugin](https://developers.openai.com/codex/plugins/build). The same root-level `skills/` directory Claude Code uses is consumed by Codex directly — nothing is copied or duplicated.

## Install

```bash
codex plugin marketplace add Sajidisrar/ios-claude-skills
codex plugin add ios-claude-skills@ios-claude-skills
```

Requires a recent Codex CLI; see the [Codex CLI docs](https://developers.openai.com/codex/cli) if `codex plugin marketplace` isn't recognized (older releases used `codex marketplace add`). Start a new Codex session after installing so the skills are discovered.

Local clone works too:

```bash
codex plugin marketplace add /path/to/your/clone
codex plugin add ios-claude-skills@ios-claude-skills
```

## Usage

Invoke a skill directly with `@` — e.g. `@ios-bug-triage`, `@ios-storekit-subscriptions` — or just describe the task and let Codex pick the right skill from the `name`/`description` of all 33.

## A caveat: `disable-model-invocation`

`ios-precommit` and `ios-commit` set `disable-model-invocation: true`, which only Claude Code honors. On Codex there's no slash-command layer to begin with — invoke them the same way as any other skill: `@ios-precommit` right before committing, `@ios-commit` right after.

## How it works

- `.codex-plugin/plugin.json` — plugin manifest at the repo root, pointing `skills` at `./skills/`.
- `.agents/plugins/marketplace.json` — marketplace entry declaring the repo root as the plugin source.
- `skills/<name>/SKILL.md` — unchanged. Codex and Claude Code share the same `name` + `description` frontmatter format, so one file serves both.
