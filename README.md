# iOS Claude Code Skills

A collection of 17 [Claude Code Skills](https://docs.claude.com/en/docs/claude-code/skills) for iOS (Swift/SwiftUI) development — covering the day-to-day workflow from writing a feature to shipping a release.

Each skill is a self-contained folder (`SKILL.md`, plus `references/` where needed). Claude Code reads a skill's frontmatter to decide when it's relevant, then follows the instructions inside when it's invoked.

> **Welcome to fork this.** These were extracted and genericized from real project skills — the opinions (architecture, testing style, offline-first patterns) are one team's conventions, not universal law. If your project does things differently, fork it, edit the `SKILL.md` files to match, delete what you don't need, and add what's missing (see [Gaps](#gaps--not-yet-covered) below for ideas). PRs that add a missing skill, fix a stale instruction, or genericize something further are welcome.

## Install

### Option A — all of them, every project (user-level)

```bash
git clone <this-repo-url> ~/Documents/Skills   # or wherever you keep it
cp -R ~/Documents/Skills/*/*/ ~/.claude/skills/
```

That flattens groups `1-build`, `2-quality`, `3-review`, `4-ship` into individual skill folders directly under `~/.claude/skills/<skill-name>/`, so every Claude Code session on your machine sees all 17 skills regardless of project.

### Option B — just one project (project-level, recommended to start)

```bash
mkdir -p .claude/skills
cp -R /path/to/Skills/1-build/ios-feature-module .claude/skills/
```

Copy in only the skills your project actually needs. Project-level skills live in that project's `.claude/skills/` and are only visible inside it — nothing leaks into other repos.

### Option C — pick and choose with a script

```bash
#!/usr/bin/env bash
# install-skills.sh <dest> <skill-name> [skill-name...]
dest="$1"; shift
mkdir -p "$dest"
for name in "$@"; do
  found=$(find /path/to/Skills -maxdepth 2 -type d -name "$name")
  [ -n "$found" ] && cp -R "$found" "$dest/" && echo "installed $name"
done
```

```bash
./install-skills.sh ~/.claude/skills ios-bug-triage ios-secure-review ios-unit-tests
```

After copying, restart Claude Code (or start a new session) so it picks up the new skills.

## How to use a skill

Most skills here trigger automatically — Claude Code reads each `SKILL.md`'s `description` and pulls the skill in when your request matches (e.g. asking "why is this crashing" can trigger `ios-bug-triage` on its own).

Two skills — `ios-precommit` and `ios-commit` — are marked `disable-model-invocation: true`, meaning they **only** run when you explicitly invoke them with a slash command:

```
/ios-precommit
/ios-commit
```

You can invoke any skill explicitly the same way, even ones that would also trigger automatically — useful when you want to be certain which skill runs.

## Examples

**"This screen sometimes just shows nothing, no error."**
→ triggers `ios-bug-triage`. It asks you to confirm the failure (which build, online/offline, every time or intermittent), narrows the layer using its symptom table (a blank screen usually means a `LoadState` stuck in `.loading`), writes a failing test first, then fixes the cause — not a `try?` papering over it somewhere else.

**"Add a Reports feature — list, detail, and create a new report."**
→ triggers `ios-feature-module`. It asks the product questions first (fields, which operations, does this need to work offline), then scaffolds domain model → endpoints → repository → repository tests → view model → view → view-model tests, in that order, mirroring the project's existing reference feature.

**Before committing:**
```
/ios-precommit
```
→ reviews your actual `git diff` (not the whole project), reports findings as 🔴/🟠/🟡/🔵/🟢 with file:line evidence, and ends with exactly one of ❌ DO NOT COMMIT / ⚠️ REVIEW RECOMMENDED / ✅ READY TO COMMIT.

**"Add Alamofire for networking."**
→ triggers `ios-dependency-assessment`. Before writing any code, it asks what problem Alamofire actually solves that the platform or the existing networking layer doesn't, checks licence/maintenance/transitive-dependency risk, and recommends with the trade-off stated explicitly — including "write it ourselves" as a valid answer.

**"The job list screen feels janky when scrolling."** *(swap in your own feature's name)*
→ triggers `ios-performance-tuning`. It asks you to measure with Instruments first, checks the usual causes for this architecture (redundant fetches, whole-list invalidation, formatter churn), and requires a before/after number — "it feels better" isn't a result it accepts.

## 1. Build — writing a feature

| Skill | Purpose |
|---|---|
| `ios-feature-module` | Scaffold a complete feature module — model, endpoints, repository, view models, screens, tests |
| `ios-api-endpoint` | Add or change a single API call — endpoint, wire models, repository method, tests |
| `ios-api-contract-migration` | Adapt the app to a changed backend contract (renamed/removed fields, new error shapes, versioned rollout) |
| `ios-swiftui-screen` | Build or change a SwiftUI screen — loading/empty/error states, forms, navigation, accessibility |
| `ios-offline-write` | Make create/update/delete work offline — outbox queueing, optimistic records, replay on reconnect |

## 2. Quality — making sure it actually works

| Skill | Purpose |
|---|---|
| `ios-unit-tests` | Write or extend unit tests using the codebase's stubs/spies and test doubles |
| `ios-bug-triage` | Diagnose and fix a bug or crash methodically — reproduce, write a failing test, fix the cause |
| `ios-concurrency-audit` | Audit/fix Swift Concurrency issues — actor isolation, Sendable, cancellation, data races |
| `ios-performance-tuning` | Diagnose and fix performance problems — slow launch, jank, redundant network calls, memory growth |
| `ios-accessibility-audit` | Audit/fix accessibility — VoiceOver, Dynamic Type, contrast, hit targets, focus order |

## 3. Review — judgment calls before it ships

| Skill | Purpose |
|---|---|
| `ios-secure-review` | Pre-commit review against architecture, secure-coding and compliance rules |
| `ios-dependency-assessment` | Assess a third-party package/SDK before adding it, as a supplier decision |
| `ios-refactor` | Refactor without changing behaviour — extract types, split files, remove duplication |

## 4. Ship — commit, PR, release

| Skill | Purpose |
|---|---|
| `ios-release-prep` | Prepare a release — version/build numbers, archive, TestFlight, release notes, pre-release checks |
| `ios-commit-and-pr` | Write commits and PR descriptions to a team's conventions |
| `ios-precommit` | Developer pre-commit review of the current diff, with a commit/no-commit decision (explicit `/ios-precommit` only) |
| `ios-commit` | Write the permanent audit record for a commit, reconciling it with `ios-precommit`'s review (explicit `/ios-commit` only) |

`ios-precommit` and `ios-commit` are a matched pair: the first reviews a pending diff and writes a temporary record; the second finalizes that record once the diff is actually committed, matching it by content fingerprint rather than assuming "the last review" is the right one.

Both of those two also mention an `ios-code-review` skill ("a separate CTO/half-yearly project assessment — do not confuse the two") purely as a contrast to explain their own scope. **That skill is not part of this collection** — it's referenced from the source project this was extracted from, not something you need to go find.

## Gaps — not yet covered

This set covers feature work, quality, review and shipping for a single iOS app target. Noticeably absent — good first contributions if you want to extend this collection:

- **CI/CD** — no skill for pipeline config (Fastlane, GitHub Actions/Bitrise/Xcode Cloud lanes).
- **Localization/i18n** — no skill for adding strings, checking translation coverage, or RTL layout.
- **App Store compliance** — `ios-release-prep` covers the mechanics (version bumps, TestFlight) but nothing audits privacy manifests, permission usage strings, or App Store review guidelines before submission.
- **PR *review*** — `ios-precommit`/`ios-secure-review` cover reviewing your *own* diff before committing; nothing covers reviewing a teammate's already-open PR.
- **Incident/hotfix path** — `ios-release-prep` assumes a normal cadence; no fast-path skill for "ship a one-line fix to production now."
- **Persistence/schema migration** — `ios-offline-write` covers the outbox pattern but not Core Data/SwiftData schema versioning or migration.
- **Observability** — `ios-performance-tuning` is reactive (fix what's slow); nothing covers adding crash reporting, analytics events, or structured logging conventions proactively.
- **Extensions/other targets** — nothing for widgets, App Clips, watchOS companions, or notification service extensions.

Whether to fill these in depends on what your own project actually needs — not every app has an extension target or a hotfix process worth automating.

## Adapting these to your project

These were written against one real iOS codebase (Swift Concurrency, SwiftUI, iOS 16 floor, no third-party dependencies, an outbox-based offline-write pattern). Expect to edit:

- **Architecture specifics** — layer names (`Core`/`Features`), protocol names (`APIClient`, `CacheStore`, `Outbox`), and the `Features/Widgets` reference-implementation pointer in `ios-feature-module` all assume a particular project shape. Point them at your own.
- **Ticket/task linkage** — `ios-commit-and-pr` assumes a `TASK-123`-style ticket reference; swap in your own tracker's convention (Jira, Linear, GitHub Issues).
- **Compliance gates** — `ios-secure-review` and `ios-commit-and-pr` reference a generic "AI-code policy" and "data-handling" section where the original had specific internal policy codes. Replace with your own, or delete if you don't have one.
- **iOS version floor** — several skills assume iOS 16 as the minimum target and ban iOS 17+ APIs accordingly. Update if your deployment target is different.

## Notes

- All sample/test data and naming in these skills is intentionally generic (`Widget`-style placeholders) — no real client, product or personal data.
- Each `SKILL.md` ends with a verification checklist. These exist so Claude reports what it actually checked rather than asserting "done" — keep that pattern if you edit or extend a skill.
