# Contributing

This is a fork-friendly collection. The opinions baked into these skills (architecture, testing style, which Apple APIs to reach for) are one team's conventions and one author's judgment calls — not universal law. If your project does things differently, fork it, edit the `SKILL.md` files to match, delete what you don't need, and add what's missing.

PRs that add a missing skill, fix a stale instruction, extend tool support, or genericize something further are welcome.

## Adding a new skill

Every skill lives at `skills/<kebab-case-name>/SKILL.md` and follows the same anatomy as the existing 33:

1. **Frontmatter**: `name` (matches the directory name) and `description` — the description should state both *what* the skill does and *when* to use it, since that's what every supported tool uses for auto-discovery. Add `disable-model-invocation: true` only if the skill should run exclusively on an explicit invocation (see `ios-precommit`/`ios-commit` for the pattern — this field is Claude Code-specific; other tools ignore it, see the per-tool docs under `docs/`).
2. **Body**: process-oriented instructions, not a reference dump. Put supporting detail that would bloat the main file into `references/*.md` and link to it.
3. **Verification checklist**: every skill ends with one. This exists so Claude reports what it actually checked rather than asserting "done" — keep that pattern.
4. **No real data**: no client names, real tickets, real credentials, real device/team identifiers, or personal data anywhere — including in examples. Use generic placeholders (`Widget`-style names, `TASK-123`-style ticket references). This project has had to sanitize exactly this kind of leak before; it's the one rule that isn't optional.
5. **Technical accuracy**: if a skill makes a concrete claim about an Apple API or language feature (availability version, exact behavior, a framework's method signature), verify it against developer.apple.com or Swift's actual source/behavior before merging — don't rely on memory alone for anything checkable.

## Adding support for a new tool

1. Add `docs/<tool>-setup.md` describing how that tool discovers skills natively (most tools now read the same `SKILL.md` format — check whether a translation layer is even needed before building one).
2. If the tool needs a destination directory `install.sh` doesn't know about yet, add a case to its `--tool` table.
3. Add a row to the README's "Works with" table.

## Removing or renaming a skill

The plugin manifests (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`) point at the whole `skills/` directory, and `install.sh`'s default install copies every subfolder — neither needs manual updates when a skill is added or removed. What *does* need a manual pass: the README's category tables, and any other skill's prose that happens to reference the renamed/removed one by name.
