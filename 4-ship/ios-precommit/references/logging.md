# Commit-level record (secondary feature)

This is a best-effort, secondary mechanism to leave a small objective trail
that the separate `ios-commit` skill consumes to finalize an audit record
once (and only once) an actual commit happens — see project `CLAUDE.md` for
when that runs. It must never interfere with, slow down, or change the
primary review shown to the developer. If any part of this fails, the
review output above still stands unmodified.

Do not build ranking, dashboards, or developer comparisons here — that is
explicitly out of scope for `ios-precommit`.

## Where records live

Store the pending review under `.git/ios-precommit/` inside the repository
the developer is working in:

- `.git/ios-precommit/pending-review.json` — the most recent review's
  pending state (overwritten every run)

The **permanent**, commit-associated record lives elsewhere and is owned by
a different skill — see "Finalizing into a permanent record" below. This
skill (`ios-precommit`) only ever writes the one pending file above.

`.git/` is always local, never tracked, and never pushed — this keeps the
record out of the repository's history and off other developers' machines.
Do not put these files anywhere that could be committed or synced (no
tracked directory, no `.gitignore` entry needed since `.git/` itself is
never versioned).

If `.git/` isn't writable, or this isn't a Git repository, skip logging
silently (a one-line note is fine, e.g. "commit record not saved — no
writable .git directory") and continue — never block the review over this.

## Fingerprint: matching a review to its eventual commit

The fingerprint must be a **per-file content hash**, not a `git diff` of the
working tree. `git diff HEAD -- <path>` produces empty output for a
genuinely untracked (new) file — there is no blob in the index or HEAD to
diff against — so a plain diff-based hash is blind to the actual content of
any new file in scope. That would let someone review a new file, then
rewrite it entirely before committing, with the fingerprint staying
identical (proven: `git diff HEAD -- <untracked>` returns nothing regardless
of the file's content, so `sha256("")` never changes no matter what the file
contains). Use blob hashes instead — they're exact-content-addressed and,
critically, computed identically whether the file is currently untracked in
the working tree or already sitting inside a commit (`git hash-object` on a
working-tree file and `git rev-parse <commit>:<path>` on the same content
once committed return the *same* SHA — this is what lets `ios-commit`
recompute a comparable value later; see its `workflow.md`).

For `<files>` = the exact list of paths touched by the review (staged,
unstaged, and relevant untracked — same set `SKILL.md` step 2 already
classifies), in that exact order:

```
buffer = ""
for path in <files>:
    if path exists on disk:
        blob = git hash-object <path>
    else:                                   # deleted in the working tree
        blob = "0000000000000000000000000000000000000000"
    buffer += "<path> <blob>\n"

fingerprint = sha256(buffer)
```

Recompute it fresh each run — never reuse a stale value. This intentionally
has nothing to do with `git diff`'s text/context format; it's a snapshot of
*what each file's content currently is*, not a delta.

**Execution constraint (permission UX, not part of the algorithm):** compute
this with simple, individually-issued commands, not a compound script.
Run one `git hash-object <path>` per file as its own separate command —
never a Bash `for` loop, array, or other compound/scripted construct over
the file list. Collect each result and assemble the `<path> <blob>\n` lines
from them one at a time. Compute the final SHA-256 over the assembled
buffer with one simple, separately-issued hashing command (e.g.
`shasum -a 256`), not chained into the same compound script as the
per-file loop. This changes nothing about the algorithm above — same
inputs, same ordering, same formula, same resulting fingerprint — it only
avoids compound shell syntax that this project's permission rules cannot
statically match to the narrow `git hash-object`/`git status`/etc. allow
rules already granted for this skill's use.

Write `pending-review.json` after presenting the review:

```json
{
  "fingerprint": "<sha256>",
  "files": ["Sources/Foo.swift", "Sources/FooTests.swift"],
  "timestamp": "<ISO 8601>",
  "branch": "<current branch>",
  "files_changed": 7,
  "lines_added": 148,
  "lines_removed": 37,
  "blockers": 0,
  "high": 0,
  "medium": 0,
  "low": 1,
  "info": 2,
  "review_status": "READY_TO_COMMIT"
}
```

`files` is the exact, repo-relative path list the fingerprint was computed
over, **in this exact order** — not just a count. Whatever consumes this
record later (currently `ios-commit`) must recompute the per-file blob-hash
buffer over this *same* file list, in this *same* order, to get a
comparable hash; without it, a later fingerprint comparison is meaningless.

`review_status` is one of `READY_TO_COMMIT`, `REVIEW_RECOMMENDED`,
`DO_NOT_COMMIT` — mirroring the decision in this run's report.

Each new run **overwrites** `pending-review.json`. It is intentionally
transient — running `/ios-precommit` five times while iterating produces
five overwrites, not five records. Nothing here is a permanent event yet.

## Write-then-verify (required every run)

Writing the file is not the last step — confirming it landed is:

1. Write `.git/ios-precommit/pending-review.json` with the object above.
2. Read the file back from disk.
3. Confirm it parses as JSON and that its `fingerprint` field equals the
   `fingerprint` just computed in this run, and its `files` array equals the
   list just used (same paths, same order).
4. Only step 3 succeeding counts as "persisted." Report that outcome
   truthfully per `SKILL.md`'s "Commit-level record" section — a
   success line only after this check actually passes; the ⚠️ failure line
   for anything else, including a write that silently produced empty or
   truncated content, a permissions error, a missing `.git/` directory, or
   this not being a Git repository at all.

This check exists because a decision line (e.g. `✅ READY TO COMMIT`) shown
to the developer without a truly persisted pending record is
indistinguishable, to the developer, from one that's actually backed by a
record `ios-commit` can find — until the commit lands and `ios-commit`
reports `NOT_REVIEWED` for a review the developer was just told was clean.
The read-back step is what prevents that gap from being silent.

## Finalizing into a permanent record (only on an actual commit)

`/ios-precommit` running by itself **never** writes a permanent record —
`pending-review.json` is temporary/pending, full stop, regardless of what
its `review_status` says. It only becomes a permanent record once matched
to a real commit.

That matching is performed by the separate **`ios-commit`** skill, installed
alongside this one, which project `CLAUDE.md` instructs Claude Code to run
explicitly, immediately after a successful `git commit` it just performed.
See that skill's `references/workflow.md` for the exact fingerprint-matching
and finalization procedure, and its `references/audit-format.md` for the
permanent record's schema and storage location.

**No Git hook is installed anywhere in this workflow, by design.** Nothing
in `ios-precommit` (or `ios-commit`) touches `.git/hooks/`. This only covers
commits Claude Code itself performs in response to an explicit request —
a developer running `git commit` directly in a terminal, outside Claude
Code, is unaffected and unobserved, and that is expected.

## Hard rules

- Never store: full review text/findings, source-code snippets or diffs,
  secrets, tokens, credentials, or any sensitive value.
- Never claim a commit was cleanly reviewed when the fingerprint doesn't
  match — `NOT_REVIEWED` / `REVIEW_MISMATCH` (produced by `ios-commit`, not
  this skill) exist precisely so review coverage is never overstated.
- Never interpret the pending record or any permanent log (no "developer X
  has more blockers than developer Y", no scoring, no trends). This skill
  only ever writes one objective, transient row for the *current* review;
  reading/interpreting finalized history belongs to `ios-commit`'s domain
  only in the narrow sense of match/no-match — never analytics.
- Never install, modify, or reference `.git/hooks/` in any form. This skill
  never runs `git commit`, `git push`, or any state-changing Git command.
