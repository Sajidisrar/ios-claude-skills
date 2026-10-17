---
name: ios-precommit
description: Developer pre-commit review of the CURRENT Git changes in an iOS (Swift/Objective-C) project — not a project-wide audit. Invoke explicitly with /ios-precommit before committing to catch correctness, regression, security, performance, maintainability, and test-gap issues in the diff, with exact file/line evidence and a clear commit/no-commit decision.
disable-model-invocation: true
---

# ios-precommit

Fast, practical, developer-facing review of the code a developer is about to
commit. This is **not** the `ios-code-review` CTO/half-yearly project
assessment — do not reuse its scoring model, and do not modify that skill.
See [references/report-template.md](references/report-template.md) for exactly
what "do not reproduce" means in output form.

## Scope: review the change, not the project

1. Determine the current branch (e.g. `git rev-parse --abbrev-ref HEAD`) and
   run `git status`, `git diff`, and `git diff --cached` to determine the
   current state. Treat the three status/diff commands as the source of
   truth for scope. Never infer, invent, or hard-code the branch name —
   always read it from the actual repository state.
2. Classify what you're looking at:
   - Unstaged changes only
   - Staged changes only
   - Both staged and unstaged (review both, but **clearly label which is
     which** — do not imply unstaged changes are part of what will be
     committed if the developer has staged a subset)
   - Untracked files relevant to the change (new source files, new tests) —
     include them; ignore untracked files clearly unrelated to the change
     (build artifacts, IDE junk, unrelated scratch files)
3. Before starting the review, print a short status line — never the full
   diff — reflecting what was actually found:
   - **Reviewable changes found** (staged, unstaged, or relevant untracked
     files per the classification above):
     ```
     Branch: <current-branch>
     <file-count> files changed — starting pre-commit review...
     ```
     `<file-count>` is the count of files actually in scope per step 2
     (dedupe files that are both staged and unstaged so they aren't
     double-counted). The full changed-file list may be shown later as part
     of the normal review/report — do not duplicate it here.
   - **Clean working tree** (no staged changes, no unstaged changes, no
     in-scope untracked files): output exactly
     ```
     Branch: <current-branch>
     No uncommitted changes to review. Working tree is clean.
     ```
     and stop. Do not invent findings, and do not fall back to reviewing
     the whole project or a past commit — a clean tree means there is
     nothing in scope for `/ios-precommit` right now.
   - Never show the "no uncommitted changes" message when staged, unstaged,
     or in-scope untracked changes actually exist, and never show the
     "files changed" message when the tree is clean.
4. You may read surrounding/related code (callers, callees, protocol
   conformances, related tests) when needed to judge whether a changed line
   introduces a real problem. Do not audit unrelated files just because they
   exist in the repo.
5. Never run destructive or history-rewriting Git commands. Read-only Git
   inspection only.

## What to review

Apply the categories and engineering principles in
[references/review-checks.md](references/review-checks.md): correctness,
regression risk, security, performance, maintainability, testing, and
AI-generated-code quality. That file also explains how to reuse the spirit of
a formal compliance checklist (naming/structure, reliability/security,
architecture, AI code ownership) as per-change questions, without turning
this into a scored audit.

Key judgment calls:

- **Legacy/inherited code, Objective-C, UIKit, MVC, older APIs, and existing
  technical debt are not automatically findings.** Judge the *change*, not
  the codebase's age or style. See references/review-checks.md for the
  inherited-vs-modified-vs-new distinction.
- Only report a pre-existing issue in surrounding code if the change
  modifies/worsens it, or ignoring it would make the change unsafe.
- Do not force modern patterns (MVVM, Swift concurrency, SwiftUI, etc.) onto
  a change unless they're actually appropriate for this project and this
  change.
- Security findings are held to a strict bar — see
  [references/severity.md](references/severity.md). Never reproduce an
  actual secret/token/credential value in output; name the type and
  location only.

## Validation (optional, read-only)

Where useful and permitted (check project config / CLAUDE.md / permissions
first), run targeted, cheap validation: a build of the affected
target/scheme, relevant unit tests, linting, or static analysis. Do not run
expensive project-wide operations by default, and do not modify the working
tree to enable validation. Only state "build passes" or "tests pass" if you
actually ran them and they actually passed; otherwise say validation was not
performed and why.

If required evidence sits behind a restricted file or a deny rule (e.g.
`.xcconfig`, `Info.plist`, secret stores, certificates), do not try to work
around it. Report `Unable to verify — restricted file/access` and name the
type of evidence that's missing.

## Severity and decision

Use the five levels and escalation rules in
[references/severity.md](references/severity.md) (🔴 BLOCKER, 🟠 HIGH, 🟡
MEDIUM, 🔵 LOW, 🟢 INFO). Be balanced: isolated minor issues stay LOW/INFO;
a single serious security or correctness issue can be a BLOCKER on its own.

Every substantive finding needs evidence: file path, line number,
symbol/function, problem, impact, fix. Never fabricate line numbers, APIs,
build/test results, or vulnerabilities — if something can't be confidently
established, say `Requires verification`.

## Output format

Follow [references/report-template.md](references/report-template.md)
exactly: concise, figures-first, no Executive Summary, no 20-rule scorecard,
no project-wide percentages. End with exactly one decision:

- ❌ **DO NOT COMMIT** — any BLOCKER present
- ⚠️ **REVIEW RECOMMENDED** — HIGH/MEDIUM present, no BLOCKER
- ✅ **READY TO COMMIT** — nothing above LOW/INFO

Each invocation reviews the current Git state only. Do not carry forward
findings from earlier invocations in this conversation if they're no longer
present in the diff — re-derive from the current diff every time.

## Commit-level record (mandatory step, reported honestly)

Immediately after presenting the review above, persist a compact pending
record so the separate `ios-commit` skill can later reconcile this review's
state with the actual commit (see project `CLAUDE.md` for when Claude Code
runs `ios-commit`). Follow [references/logging.md](references/logging.md)
exactly — it covers the pending-vs-permanent distinction, the review↔commit
fingerprint matching (`NOT_REVIEWED` / `REVIEW_MISMATCH`, finalized by
`ios-commit`, not here), the pending record schema, and the required
write-then-verify sequence.

This never blocks or changes the primary review/decision text above it — the
review's findings and decision always stand on their own regardless of what
happens next — but presenting the review is not finished until this step's
outcome is stated out loud, because a silent failure here is exactly what
lets a review look complete while `ios-commit` later has nothing to match
against:

- Write `pending-review.json`, then **read it back** and confirm it parses
  and its `fingerprint`/`files` match what was just computed for this run.
- Verified success → append one line after the DECISION line:
  `Pending review record saved (<branch>, <n> files).`
- Any failure (unwritable `.git/`, not a Git repository, the read-back not
  matching what was written, or any other fault) → append instead:
  `⚠️ Pending review record NOT saved — <reason>. /ios-commit will report
  NOT_REVIEWED for this review even if you commit right away. Consider
  rerunning /ios-precommit immediately before committing.`

Never show the success line without having actually performed the read-back
verification in this run — a decision line must never be presented next to a
persistence claim that wasn't just confirmed true. Do not build any ranking,
dashboard, or cross-developer comparison — that is explicitly out of scope
for this skill. This skill never installs a Git hook and never runs
`git commit`.
