# Finalization workflow

Deterministic, in order. Every step reads from Git directly — never from
conversational memory of what "should" have happened.

## 1. Identify the actual commit

```
sha        = git rev-parse HEAD
branch     = git rev-parse --abbrev-ref HEAD
author     = git log -1 --format='%ae' HEAD
timestamp  = git log -1 --format='%aI' HEAD        (commit's own authored date, ISO 8601)
files      = git diff-tree --no-commit-id --name-only -r HEAD
diffstat   = git diff --shortstat HEAD~1 HEAD       (falls back to `git show --shortstat HEAD`
                                                      for a repo's first commit, which has no HEAD~1)
```

Parse `diffstat` for `files_changed`, `lines_added` (`insertions`),
`lines_removed` (`deletions`); any of the three can legitimately be absent
(e.g. a commit with only deletions has no "insertions" clause) — treat a
missing clause as `0`, not an error.

`repository` — derive from `git remote get-url origin` (take the repo name,
strip `.git`/host/org prefix) if a remote exists; otherwise use the working
directory's folder name. Local-only identifier, never uploaded anywhere by
this skill.

## 2. Locate the pending review

Read `.git/ios-precommit/pending-review.json`.

- **File does not exist** → skip to [§5 NOT_REVIEWED](#5-not_reviewed).
- **File exists but fails to parse as JSON, or is missing required fields**
  (`fingerprint`, `files`, `review_status`) → treat identically to "does not
  exist": `NOT_REVIEWED`. Do not attempt partial recovery from a malformed
  record.

## 3. Recompute the fingerprint over the *same* file list

The pending record's `files` array (in the order stored — do not re-sort)
is the exact scope `ios-precommit` fingerprinted, using the per-file
blob-hash formula in its `logging.md` (not a `git diff`). Recompute the
*identical* formula now, against the commit that just landed, over that
**same** ordered list — not over "all files in the commit":

```
buffer = ""
for path in <pending.files>:
    if path exists in HEAD's tree:
        blob = git rev-parse HEAD:<path>
    else:                                   # not part of this commit / deleted
        blob = "0000000000000000000000000000000000000000"
    buffer += "<path> <blob>\n"

actual_fingerprint = sha256(buffer)
```

**Execution constraint (permission UX, not part of the algorithm):** compute
this with simple, individually-issued commands, not a compound script. Run
one `git rev-parse HEAD:<path>` per file as its own separate command — never
a Bash `for` loop, array, or other compound/scripted construct over
`pending.files`. Collect each result and assemble the `<path> <blob>\n`
lines from them one at a time. Compute the final SHA-256 over the assembled
buffer with one simple, separately-issued hashing command (e.g.
`shasum -a 256`), not chained into the same compound script as the per-file
loop. This changes nothing about the algorithm above — same inputs, same
ordering, same formula, same resulting fingerprint — it only avoids
compound shell syntax that this project's permission rules cannot
statically match to the narrow `git rev-parse`/etc. allow rules already
granted for this skill's use.

This works for a repo's very first commit exactly the same way — `HEAD`
already refers to that commit once it exists, so `git rev-parse HEAD:<path>`
needs no special-casing for "no parent commit."

**Why this is comparable to the pending fingerprint at all:** blob hashing
is purely a function of a file's exact byte content — `git hash-object` on
a working-tree file (what `ios-precommit` used) and `git rev-parse
<commit>:<path>` on the same content once committed (what this step uses)
return the *same* hash for identical content, regardless of whether the
file was tracked, untracked, staged, or unstaged when it was reviewed. That
symmetry is what makes "the review-time snapshot" and "the commit-time
snapshot" comparable at all — see `logging.md` for the underlying reasoning
and the empirical basis for it.

## 4. Compare

- **`actual_fingerprint == pending.fingerprint`** → every path in scope has
  byte-identical content between what was reviewed and what got committed.
  Finalize using the pending record's severity counts
  (`blockers`/`high`/`medium`/`low`/`info`) and `review_status`, translated
  per the mapping in [audit-format.md](audit-format.md#status-mapping). Go
  to §6.
- **Any other outcome** (hash differs — including a single changed,
  added, or deleted file among many unchanged ones; the pending file's
  `files` list and this commit's actual changed-file set differ;
  recomputation fails for any reason, e.g. `pending-review.json` is
  unreadable at this point) → `REVIEW_MISMATCH`. This is the case in the
  brief's Scenario C: reviewed state X, developer edited further (including
  editing an untracked file that hadn't been staged yet), committed state
  Y. Do **not** carry forward the pending record's severity counts — they
  described a diff that was never actually committed. Go to §6 with counts
  omitted. Prefer this outcome over guessing whenever integrity cannot be
  cleanly established — never treat an inconclusive check as a match.

## 5. `NOT_REVIEWED`

No pending record exists (or it was unusable) to match against this commit.
Write a record with `review_status: "NOT_REVIEWED"` and all severity count
fields omitted — only the objective commit metrics from §1 are known.

## 6. Write the permanent record

Append exactly one JSON line to the permanent log (path, schema, and field
rules in [audit-format.md](audit-format.md)). Then delete
`.git/ios-precommit/pending-review.json` if it still exists, regardless of
which branch above was taken — a consumed pending record must never be
matchable against a second, later commit.

## 7. Report to the developer

Short, not a report:

```
Commit <short-sha> on <branch> finalized: <STATUS>
<one line of context — e.g. "matches the ios-precommit review that ran just before this commit"
 or "no pending review found for this commit" or "diff changed after the last review ran">
```

## Why intermediate reviews never become permanent records

A developer may run `/ios-precommit` several times while fixing issues
before finally committing. Each run **overwrites** the same
`pending-review.json` (see `ios-precommit`'s `logging.md`) — there is only
ever one pending record at a time, and `ios-commit` only ever reads it once,
at commit time, then deletes it. There is structurally no way for review
attempt #1 or #2 to become a permanent record; only whichever pending state
existed at the moment of the actual `git commit` gets a chance to match.

## Push visibility (informational only — used by `CLAUDE.md`'s push section)

`CLAUDE.md` treats `ios-precommit`/`ios-commit` as developer guidance and
accountability tools, not enforcement gates: an explicit developer request
to push is sufficient on its own, and Claude does not withhold a push over
`NOT_REVIEWED`, `REVIEW_MISMATCH`, or a missing record. This lookup exists
only so Claude can *mention* the audit status of the commits being pushed,
for visibility — never to decide whether the push proceeds.

1. Determine what would actually be pushed:
   ```
   git rev-list <remote-tracking-branch>..HEAD
   ```
   (If the branch has no upstream yet, treat every commit on the current
   branch not present on the configured default remote branch as in scope
   — ask the developer to confirm the intended base if this is ambiguous,
   rather than guessing.)
2. For each commit SHA in that list, look it up in the permanent record
   (append-only, so scan for the last line with a matching `commit` field —
   later entries win if a SHA ever appears twice, which should not happen
   in normal operation).
3. If Claude is already aware that a commit in scope has no entry, or has
   `review_status` of `NOT_REVIEWED` or `REVIEW_MISMATCH`, it may mention
   that plainly alongside the push — but this is informational only. It is
   never a reason to stop, hold back, or ask for confirmation before
   pushing, and never a reason to invent or backfill a record. The push
   proceeds on the developer's request regardless of what this lookup
   finds.
