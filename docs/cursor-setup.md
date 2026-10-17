# Using ios-claude-skills with Cursor

Cursor has native support for the same `SKILL.md` format this repo uses — no translation needed, just a different discovery path.

## What Cursor supports

| Layer | Path | Role |
|---|---|---|
| Project skills | `.cursor/skills/<skill-name>/SKILL.md` | Agent-discovered workflows; read when the task matches the skill's `description` |
| User skills | `~/.cursor/skills/<skill-name>/SKILL.md` | Available in every workspace |
| Project rules | `.cursor/rules/*.mdc` | Short, always-on or file-scoped policies — not a place to paste full skill bodies |

Docs: [Cursor Rules](https://docs.cursor.com/context/rules) · [Cursor Skills](https://docs.cursor.com/context/skills) (URLs may move as Cursor updates its docs).

## Install

From a local clone of this repo:

```bash
mkdir -p .cursor/skills
rsync -a /path/to/ios-claude-skills/skills/ .cursor/skills/
```

Or with the repo's installer:

```bash
curl -fsSL https://raw.githubusercontent.com/Sajidisrar/ios-claude-skills/main/install.sh | bash -s -- --tool cursor
```

For every project on your machine instead of just one:

```bash
curl -fsSL https://raw.githubusercontent.com/Sajidisrar/ios-claude-skills/main/install.sh | bash -s -- --tool cursor --scope user
```

### Just one skill

```bash
curl -fsSL https://raw.githubusercontent.com/Sajidisrar/ios-claude-skills/main/install.sh | bash -s -- --tool cursor --skill ios-bug-triage
```

## Optional: a routing rule

Cursor applies skills automatically based on `description`, so this is optional — useful mainly if you want a standing reminder. Create `.cursor/rules/ios-claude-skills.mdc`:

```markdown
---
description: Use ios-claude-skills workflows from .cursor/skills
alwaysApply: true
---

Before non-trivial iOS work, check whether a skill under `.cursor/skills/`
already covers it (feature scaffolding, bug triage, concurrency/performance
audits, secure review, release prep, or an Apple-framework skill like
Swift 6 concurrency migration or StoreKit). Prefer the matching skill over
guessing — the user does not need to say "use the skill" each time.
```

Keep this rule short. Let the skills themselves carry the long checklists.

## A caveat: `disable-model-invocation`

Two skills in this repo — `ios-precommit` and `ios-commit` — set `disable-model-invocation: true` in their frontmatter so they only run on an explicit Claude Code slash command. **Cursor doesn't read that field.** It will still auto-apply both skills based on their `description` like any other skill. That's expected, not a bug — if you want the explicit-only behavior Claude Code has, invoke them by name in chat ("use the ios-precommit skill") rather than relying on them staying quiet.

## Verify

1. Settings → Rules — your `.mdc` files are listed, if you added any.
2. Ask Cursor to do something a skill covers (e.g. "there's a bug where this screen shows nothing") without naming the skill — it should pick up `ios-bug-triage` on its own.

## Troubleshooting

| Symptom | Check |
|---|---|
| Skill never used | Is `SKILL.md` actually under `.cursor/skills/<name>/`? Valid frontmatter `description`? |
| Stale workflow after an update | Re-run the `rsync`/installer command |
| `ios-precommit`/`ios-commit` fire when you didn't ask | Expected on Cursor — see the caveat above |
