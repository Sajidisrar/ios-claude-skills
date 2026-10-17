# Permanent audit record

## Where it lives

`.git/ios-commit/commit-log.jsonl` — append-only, one JSON object per line,
inside the repository the commit was made in.

`.git/` is always local, never tracked, and never pushed. This is a
separate file from `ios-precommit`'s `.git/ios-precommit/pending-review.json`
— that one is temporary and owned by `ios-precommit`; this one is permanent
and owned by this skill. Never write the permanent record into
`.git/ios-precommit/`, and never let `ios-precommit` write to this path.

If `.git/` isn't writable, say so plainly ("commit record not saved — no
writable .git directory") and continue — never fail the workflow over a
logging problem, and never claim a record was written when it wasn't.

## Schema (one line per commit)

```json
{
  "timestamp": "2026-09-10T10:15:00+05:00",
  "repository": "MyApp-iOS",
  "branch": "feature/example-branch",
  "commit": "8e601590a1b2c3d4e5f6...",
  "developer": "developer@example.com",
  "files_changed": 7,
  "lines_added": 148,
  "lines_removed": 37,
  "blockers": 0,
  "high": 0,
  "medium": 1,
  "low": 0,
  "info": 2,
  "review_status": "READY_TO_COMMIT"
}
```

- `timestamp`, `repository`, `branch`, `commit`, `developer`,
  `files_changed`, `lines_added`, `lines_removed` — always populated,
  derived directly from Git (see `workflow.md` §1). `commit` is the full
  SHA, not the short form.
- `blockers`/`high`/`medium`/`low`/`info` — populated **only** when
  `review_status` is one of `READY_TO_COMMIT`, `REVIEW_RECOMMENDED`,
  `BLOCKED` (a real, matched review). **Omit these five fields entirely**
  (do not write them as `0` or `null`) when `review_status` is
  `NOT_REVIEWED` or `REVIEW_MISMATCH` — there is no trustworthy count to
  report in either case, and writing `0`s would misrepresent an unreviewed
  or mismatched commit as clean.

## Status mapping

`ios-precommit`'s report/pending record uses `READY_TO_COMMIT` /
`REVIEW_RECOMMENDED` / `DO_NOT_COMMIT` (matching its own report's decision
language exactly — see `ios-precommit/references/severity.md`). This
skill's **permanent** record uses a five-value vocabulary instead, per
project convention:

| Pending record's `review_status` | Permanent record's `review_status` | When |
|---|---|---|
| `READY_TO_COMMIT` | `READY_TO_COMMIT` | fingerprint matched |
| `REVIEW_RECOMMENDED` | `REVIEW_RECOMMENDED` | fingerprint matched |
| `DO_NOT_COMMIT` | `BLOCKED` | fingerprint matched (see note below) |
| *(any / mismatch)* | `REVIEW_MISMATCH` | fingerprint did not match |
| *(no pending record)* | `NOT_REVIEWED` | no pending record found |

Only the `DO_NOT_COMMIT` → `BLOCKED` rename crosses the pending/permanent
boundary; the other two pass through unchanged. This translation exists so
the permanent audit vocabulary is stable even if `ios-precommit`'s
human-facing report wording ever changes independently.

A `BLOCKED` permanent record should be rare in practice — `CLAUDE.md`'s
workflow means Claude Code itself never runs `git commit` while the pending
review says `DO_NOT_COMMIT`. Seeing one means the commit was made outside
that guarded path (e.g. the developer committed manually in a terminal
while a matching `DO_NOT_COMMIT` pending review happened to exist). Record
it as `BLOCKED` honestly; do not suppress or reinterpret it.

## Never store

- Full review text, findings, or narrative.
- Source-code snippets or diffs of any size.
- Passwords, tokens, API keys, credentials, or any secret value.
- Unnecessary personal information beyond the committer's Git-configured
  email (already the minimum needed for `developer`).

## Never do

- Never write more than one line for the same commit SHA.
- Never backfill a record for a commit from a previous session/context —
  only finalize a commit `ios-commit` is invoked for immediately after it
  was made.
- Never compute aggregate stats, trends, or per-developer comparisons from
  this file. It is a flat audit trail; interpretation is out of scope for
  every skill in this project.
