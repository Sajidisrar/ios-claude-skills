# Report format

The report is figures-first and evidence-dense, not prose-dense. It is
explicitly **not** the `ios-code-review` CTO report — never include any of:

- Executive Summary
- Five-category scorecard / 20-rule checklist table
- Project-wide compliance percentage
- Weight = 1 style scoring
- Passed/Failed/Unverified category table
- "Human Verification Required" formal section
- Long narrative/compliance prose

## Status line (always shown first, before the report body)

Before the report itself, show one of the two status lines below — never
the full diff. See SKILL.md "Scope: review the change, not the project"
step 3 for exactly when each applies.

Reviewable changes found:

```
Branch: <current-branch>
<file-count> files changed — starting pre-commit review...
```

Clean working tree (then stop — no report body follows):

```
Branch: <current-branch>
No uncommitted changes to review. Working tree is clean.
```

## Standard template (findings present)

```
# PRE-COMMIT CODE REVIEW

Scope: <staged | unstaged | staged + unstaged> changes
Files changed: <n>
Files reviewed: <n>
Lines added: <n>
Lines removed: <n>

🔴 Blockers: <n>
🟠 High: <n>
🟡 Medium: <n>
🔵 Low: <n>
🟢 Info: <n>

## BLOCKERS

### 1. 🔴 <short title>

`<path>:<line>`
`<Symbol.function()>`

**Impact:** <one line>

**Fix:** <one line>

## HIGH
### 2. 🟠 <short title>
...

## MEDIUM
### N. 🟡 <short title>
...

## LOW / INFO
(only if non-empty; keep to one line per item, no impact/fix subsections
needed unless the fix isn't obvious)

## SUMMARY

| Severity   | Count |
| ---------- | ----: |
| 🔴 Blocker |   <n> |
| 🟠 High    |   <n> |
| 🟡 Medium  |   <n> |
| 🔵 Low     |   <n> |
| 🟢 Info    |   <n> |

## DECISION

❌ **DO NOT COMMIT**   (or ⚠️ **REVIEW RECOMMENDED**, or ✅ **READY TO COMMIT** — pick exactly one per severity.md)

<one line: what to fix and to rerun `/ios-precommit`, or that it's clear to commit>
```

Number findings sequentially across all severities (1, 2, 3, ...) — don't
restart numbering per section.

## Clean-result template (no findings, or LOW/INFO only)

Keep this short — do not repeat the full template scaffolding when there's
nothing to report in detail:

```
# PRE-COMMIT CODE REVIEW

Scope: <staged | unstaged | staged + unstaged> changes
Files changed: <n>
Files reviewed: <n>

🔴 Blockers: 0
🟠 High: 0
🟡 Medium: 0
🔵 Low: <n>
🟢 Info: <n>

Security: PASS
Correctness: PASS
Tests: PASS
Architecture: PASS

## DECISION

✅ **READY TO COMMIT**

No blocking or high-risk issues found.
```

(Only claim PASS for a category you actually reviewed; omit a category line
you didn't have a basis to assess rather than asserting it.)

## No-change template

```
Branch: <current-branch>
No uncommitted changes to review. Working tree is clean.
```

## Style rules

- No paragraphs longer than 2 sentences anywhere in the report.
- Every finding needs a location (`path:line` at minimum; symbol when
  helpful) — if a precise line can't be established, say
  `Requires verification` instead of guessing a number.
- Don't restate the whole diff; quote only the minimal relevant snippet
  when a quote clarifies the problem.
- Never print an actual secret/token/credential value — name the type and
  location.
- End every report (including the no-change case is exempt) with exactly
  one DECISION line.
