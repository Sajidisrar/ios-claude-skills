# Using ios-claude-skills with Gemini CLI

Gemini CLI has a native skills system that auto-discovers `SKILL.md` files — same format this repo already uses, no translation needed.

## Install as skills (recommended)

```bash
gemini skills install https://github.com/Sajidisrar/ios-claude-skills.git --path skills
```

Or from a local clone:

```bash
git clone https://github.com/Sajidisrar/ios-claude-skills.git
gemini skills install /path/to/ios-claude-skills/skills/
```

Workspace-only scope:

```bash
gemini skills install /path/to/ios-claude-skills/skills/ --scope workspace
```

Workspace-scoped skills land in `.gemini/skills/` (or `.agents/skills/`); user-level installs go to `~/.gemini/skills/`. Verify with:

```
/skills list
```

Gemini CLI injects skill names and descriptions into the prompt automatically and asks permission to activate a matching skill before loading its full instructions.

## Alternative: GEMINI.md for always-on skills

If you want a specific skill loaded as persistent context for every prompt (rather than activated on demand), append it to your project's `GEMINI.md`:

```bash
cat /path/to/ios-claude-skills/skills/ios-secure-review/SKILL.md >> GEMINI.md
```

Use skills (on-demand) for most of this collection — 37 skills loaded persistently would eat your context budget for no benefit. `GEMINI.md` is better reserved for the one or two conventions you want enforced every single turn.

## A caveat: `disable-model-invocation`

`ios-precommit` and `ios-commit` set `disable-model-invocation: true`, honored only by Claude Code. Gemini CLI will still auto-activate both based on their `description` like any other skill — expected, not a bug. Invoke them by name if you want to be certain which one runs: "use the ios-precommit skill."

## Usage tips

1. Skills activate on demand and keep context focused — prefer them over `GEMINI.md` for anything that isn't needed every turn.
2. Each `SKILL.md`'s `description` is written to state both *what* the skill does and *when* to use it, for auto-discovery across tools — Gemini CLI included.
3. Explicitly load a skill with `@` if you don't want to wait for auto-discovery: `Use the @skills/ios-storekit-subscriptions/SKILL.md skill to add subscriptions to this screen.`
