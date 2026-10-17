---
name: ios-commit-and-pr
description: Write commits and pull request descriptions for this iOS project to the team's conventions, including ticket linkage and an AI-code review gate. Use when asked to commit, stage changes, write a commit message, open or describe a pull request, or summarise a change for review.
---

# Commit and pull request conventions

## Before committing anything

- Never commit to the default branch. Branch first:
  `feature/TASK-123-offline-sync`, `fix/TASK-456-stuck-spinner`,
  `chore/lint-config`.
- Never commit without being asked to. Producing the change and committing it are
  separate decisions.
- Check `git status` and `git diff --staged` and read what you are about to
  commit. Watch for: a stray `print`, a `.xcodeproj` (git-ignored — if it appears,
  the ignore file was bypassed), a secret in an xcconfig, a fixture with real
  data, a debug flag left on.

## Commit messages

```
<type>(<scope>): <imperative summary, under 72 characters>

Why this change is needed, if it is not obvious from the summary.
What was decided and what was deliberately left out.

Refs: TASK-123
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `build`.
Scope is the feature or Core area: `widgets`, `auth`, `networking`, `sync`.

Good:

```
feat(widgets): queue widget creation while offline

Users on a poor connection lose signal mid-session and were losing
unsaved creates. Creates now fall back to the outbox and appear
immediately with a pending badge. Conflict handling is still
last-write-wins — see docs/DECISIONS.md D12.

Refs: TASK-123
```

Not this: "fixed stuff", "WIP", "address review comments" (say what changed), or
a message that restates the diff line by line.

One logical change per commit. A refactor and a behaviour change in one commit
cannot be reviewed or reverted separately.

## Pull request description

```markdown
## What
One or two sentences. What now works that did not before.

## Why
The problem, the task or ticket, and the decision if one was made.

## How
The approach, and anything a reviewer would otherwise have to reverse-engineer.
Name any layer boundary the change touches.

## Testing
- Unit tests added: <which behaviours, including failure paths>
- Manual: <device, iOS version, and the states checked — including offline,
  expired session, empty and error states where relevant>

## Risk and rollback
What could go wrong, who is affected, how to revert.

## Checklist
- [ ] Builds for iOS 16 simulator
- [ ] SwiftLint clean
- [ ] Tests pass locally and in CI
- [ ] SAST clean
- [ ] No secrets, credentials or personal data in the diff
- [ ] Accessibility checked (VoiceOver + largest text size) for UI changes
- [ ] Docs updated (ARCHITECTURE / DECISIONS / SECURITY) if a decision changed
- [ ] Named human reviewer assigned
```

## Attribution and the AI-code gate

Where a change was written with AI assistance, say so in the pull request body —
one line is enough ("Drafted with Claude Code; reviewed and tested by <name>").
Treat AI-generated code as untrusted until a named human has reviewed it and
taken ownership, and require a clean test run and SAST pass before merge — adjust
this to whatever your own project's policy requires. Do not describe a change as
"ready to merge" on your own authority — describe it as ready for review.

Changes touching authentication, token storage, transport or logging need a
second reviewer. Say so in the description rather than leaving it to be noticed.

## Verification

- [ ] Branch is not the default branch.
- [ ] One logical change per commit.
- [ ] Message says *why*, and references the task or ticket.
- [ ] Diff read through before staging; no debug leftovers, no secrets, no real
      data.
- [ ] Pull request body includes testing done and risk.
- [ ] AI assistance disclosed where applicable.
- [ ] Second reviewer flagged for security-relevant changes.
