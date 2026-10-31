# AGENTS.md

This file configures AI agents working on the [`Sajidisrar/ios-claude-skills`](https://github.com/Sajidisrar/ios-claude-skills) repository itself.

> **Scope:** This is not meant to be copied into other projects or into a global agent configuration. The reusable assets are the skills in `skills/`, not this file.

## What this repo is

A flat `skills/` directory of 37 Claude Code-format skills for iOS/Swift development: 22 lifecycle-workflow skills (feature work, quality, review, shipping — presented in the README under "Build/Quality/Review/Ship" though the directory itself has no category subfolders) plus 15 Apple-framework skills (Swift concurrency migration, SwiftData, StoreKit, and others — presented under "Frameworks & Platform").

## Working on this repo

- **Don't reintroduce nested category folders under `skills/`.** Every supported tool's native skill discovery (Claude Code, Codex, Cursor, Copilot, Gemini CLI) expects `skills/<name>/SKILL.md` directly, one level deep. The Build/Quality/Review/Ship/Frameworks grouping is presentation-only — it belongs in README tables, never in the filesystem.
- **Follow `CONTRIBUTING.md`'s skill anatomy** when adding or editing a skill — frontmatter, verification checklist, no real client/business/personal data, technical claims checked against Apple's actual documentation rather than written from memory.
- **Keep the per-tool docs (`docs/*.md`), `install.sh` and the SwiftPM plugin (`Plugins/InstallIOSSkills/plugin.swift`, same `--tool` table) in sync** with what's actually true of each tool's current skill-discovery mechanism — these are living integrations, not a one-time snapshot; a tool changing its skill directory convention should prompt an update here, not just in a comment.
- **The plugin manifests are directory-based, not list-based** (`"skills": "./skills"`), so adding or removing a skill folder doesn't require touching `.claude-plugin/plugin.json` or `.codex-plugin/plugin.json`. It does require updating the README's category tables.
- **Version every release the same way:** follow CONTRIBUTING.md's "Versioning and releases" — `scripts/bump-version.sh` for all manifests, a CHANGELOG.md entry, then a `vX.Y.Z` tag. Never set a manifest version by hand, and never move or delete a published tag (SwiftPM users resolve against it).
