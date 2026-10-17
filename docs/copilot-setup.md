# Using ios-claude-skills with GitHub Copilot

This covers Copilot in VS Code. Copilot reads the same `SKILL.md` format this repo already uses — no translation needed, just a different directory.

## Install

Copilot auto-discovers skills from any of `.github/skills/`, `.claude/skills/`, or `.agents/skills/` in your repository:

```bash
mkdir -p .github/skills
rsync -a /path/to/ios-claude-skills/skills/ .github/skills/
```

Or with the repo's installer:

```bash
curl -fsSL https://raw.githubusercontent.com/Sajidisrar/ios-claude-skills/main/install.sh | bash -s -- --tool copilot
```

Each installed skill becomes a slash command named after its frontmatter `name` — `/ios-bug-triage`, `/ios-feature-module`, `/ios-storekit-subscriptions`, and so on. Run `/skills` in Copilot Chat to open the **Configure Skills** menu and confirm what got discovered.

Details: [Creating agent skills for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills) and the [VS Code agent skills guide](https://code.visualstudio.com/docs/agent-customization/agent-skills).

## A caveat: `disable-model-invocation`

`ios-precommit` and `ios-commit` set `disable-model-invocation: true` so Claude Code only runs them on an explicit slash command. **Copilot doesn't read that field** — both will still appear as ordinary slash commands (`/ios-precommit`, `/ios-commit`) and may auto-trigger based on their descriptions like any other skill. That's expected here, not a missing step.

## Optional: project-wide instructions

For conventions you want applied to every Copilot interaction in this repo (not skill-specific), use `.github/copilot-instructions.md`:

```markdown
# Project Coding Standards

## Testing
- Write a failing test before fixing a bug (see the ios-bug-triage skill)
- Prefer the lowest test level that captures the behavior

## Before committing
- Run /ios-precommit before staging, /ios-commit immediately after a real commit
- No secrets, tokens, or real personal data in diffs or fixtures
```

Keep this short — Copilot instructions work best when focused; the skills themselves carry the detailed checklists.

## Optional: short aliases

VS Code's extension-host local agents support [prompt files](https://code.visualstudio.com/docs/agent-customization/prompt-files) at `.github/prompts/<name>.prompt.md` — each becomes a `/<name>` slash command. Useful if you want a shorter alias than a skill's full name. Write the body yourself as a complete, self-contained prompt (don't copy a `SKILL.md` body verbatim — these files have no mechanism to "invoke" another skill, the prompt text is the entire instruction).

```bash
mkdir -p .github/prompts
cat > .github/prompts/precommit.prompt.md <<'EOF'
---
description: Review the current git diff before committing
---

Use the ios-precommit skill. Review only the current staged/unstaged git
diff — not the whole project. Report findings as BLOCKER/HIGH/MEDIUM/LOW/INFO
with file:line evidence, and end with exactly one decision: DO NOT COMMIT,
REVIEW RECOMMENDED, or READY TO COMMIT.
EOF
```

Reload the window, then type `/precommit`.

## If skills don't appear

1. Confirm `SKILL.md` landed under one of `.github/skills/`, `.claude/skills/`, or `.agents/skills/` — a global/user-scope install writes outside the workspace instead.
2. Check the frontmatter `name` is present — it *is* the slash command name.
3. Run `/skills` and confirm the skill shows as enabled.
4. Start a fresh chat session — newly added skills aren't always picked up mid-conversation.
5. Update VS Code and the Copilot Chat extension — skills-as-slash-commands support is recent.
