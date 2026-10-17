---
name: ios-commit
description: Finalizes the permanent audit record for an ACTUAL Git commit, immediately after `git commit` succeeds. Matches the just-made commit against ios-precommit's pending review by content fingerprint (not by "latest review" assumption), then writes exactly one compact, machine-readable record. This is NOT a second code review — invoke explicitly with /ios-commit right after a successful commit, per project CLAUDE.md's mandatory commit workflow.
disable-model-invocation: true
---

# ios-commit

Closes the loop that `ios-precommit` opens. `ios-precommit` reviews
*proposed* changes and writes a **temporary** pending record. This skill
runs *after* `git commit` has actually succeeded, decides whether that
commit corresponds to a reviewed state, and writes the **one** permanent
record for that commit. It never reviews code itself.

Do not confuse this with `ios-precommit` (pre-commit diff review) or
`ios-code-review` (separate CTO/project-level assessment skill — unrelated,
not read or written by this skill).

## When this runs

Only when Claude Code, following project `CLAUDE.md`'s Git workflow, has
just executed `git commit` on the developer's behalf inside this
conversation. Never run this speculatively, never run it before a commit
exists, and never run it for a commit made outside this session (that case
is exactly what produces `NOT_REVIEWED` — see below, not something to work
around).

This skill does not install or rely on any Git hook. It is only ever
triggered by an explicit invocation immediately following a commit Claude
Code itself performed.

## What this skill does NOT do

- Does not review code, style, security, or architecture — that already
  happened (or didn't) in `ios-precommit`.
- Does not modify application source code.
- Does not run `git commit`, `git push`, or any state-changing Git command
  itself — the commit it finalizes has already happened before this skill
  is invoked.
- Does not install, modify, or reference `.git/hooks/`.
- Does not weaken, bypass, or reinterpret `.claude/settings.json` permissions.
- Does not create dashboards, rankings, trends, or any cross-developer
  comparison. The permanent log is an audit trail, not a scorecard.
- Does not invent or guess a review outcome when no matching review exists
  — that case is `NOT_REVIEWED`, recorded plainly.

## Procedure

Full mechanics are in [references/workflow.md](references/workflow.md) —
follow it exactly, in order. Summary:

1. Identify the actual latest commit: SHA, branch, author, changed files,
   diffstat — all read from Git itself (`git log -1`, `git diff-tree`,
   etc.), never assumed or inferred.
2. Look for `.git/ios-precommit/pending-review.json`.
3. If it's absent → `NOT_REVIEWED`.
4. If present, recompute the actual commit's fingerprint over the pending
   record's own `files` list and compare to the pending record's
   `fingerprint`:
   - Match → finalize using the pending record's severity counts and
     status.
   - Mismatch (different file set, or same files but different content —
     i.e. the developer changed something after the review ran) →
     `REVIEW_MISMATCH`. Never carry the mismatched severity counts into the
     permanent record.
5. Write exactly one line to the permanent record (schema and location in
   [references/audit-format.md](references/audit-format.md)).
6. Clear/delete `pending-review.json` so it can never be matched against a
   later commit.
7. Report the outcome to the developer in a few lines — status, commit SHA,
   short summary. Do not reproduce a full review report here; that already
   happened in `ios-precommit`.

## Hard rules

- One commit → at most one permanent record. Never write more than one line
  per commit SHA.
- A precommit review that was never followed by a commit produces **no**
  permanent record, ever — see `references/workflow.md` for why intermediate
  review attempts (a developer iterating through several `/ios-precommit`
  runs before actually committing) must never each become a permanent
  event.
- Never fabricate, backfill, or guess a fingerprint match. If verification
  is inconclusive, prefer `REVIEW_MISMATCH`/`NOT_REVIEWED` over a false
  `READY_TO_COMMIT`-style finalization.
- Never store full review text, source-code snippets, diffs, secrets,
  tokens, credentials, or unnecessary personal information — see
  `references/audit-format.md`'s exact prohibited-fields list.
- This skill's own I/O is confined to `.git/ios-precommit/pending-review.json`
  (read + delete) and the permanent record location (append-only). It does
  not read or write application source files.
