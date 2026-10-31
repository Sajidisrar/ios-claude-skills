# iOS Claude Skills

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Skills](https://img.shields.io/badge/skills-37-brightgreen)](#1-build--writing-a-feature)

A collection of 37 [Claude Code Skills](https://docs.claude.com/en/docs/claude-code/skills) for iOS/Swift development — lifecycle workflows (feature work, quality, review, shipping) plus skills for the core Apple frameworks nearly every real app touches (Swift concurrency, SwiftData, StoreKit, and more).

```
  BUILD ──▶ QUALITY ──▶ REVIEW ──▶ SHIP
    │                                        FRAMEWORKS & PLATFORM
    └── feature work, screens,               (used wherever relevant —
        offline writes, API calls             not stage-bound: concurrency,
                                               SwiftData, StoreKit, CloudKit,
                                               widgets, push, privacy, HIG…)
```

Each skill is a self-contained folder (`SKILL.md`, plus `references/` where needed) directly under `skills/` — one flat directory, so every supported tool's native skill discovery finds it without translation. Claude Code (and every other tool below) reads a skill's frontmatter to decide when it's relevant, then follows the instructions inside when it's invoked.

**Welcome to fork this.** The opinions baked in (architecture, testing style, which Apple APIs to reach for) are one team's conventions and one author's judgment calls, not universal law. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a skill, add tool support, or adapt one to your own project.

## Works with

Every tool below reads the same `SKILL.md` files — no per-tool content translation, just a different discovery path.

| Tool | Install | Setup detail |
|---|---|---|
| **Claude Code** | `/plugin marketplace add Sajidisrar/ios-claude-skills` then `/plugin install ios-claude-skills` — or `install.sh` below | — |
| **Cursor** | `curl -fsSL .../install.sh \| bash -s -- --tool cursor` | [docs/cursor-setup.md](docs/cursor-setup.md) |
| **GitHub Copilot** | `curl -fsSL .../install.sh \| bash -s -- --tool copilot` | [docs/copilot-setup.md](docs/copilot-setup.md) |
| **Gemini CLI** | `gemini skills install https://github.com/Sajidisrar/ios-claude-skills.git --path skills` | [docs/gemini-cli-setup.md](docs/gemini-cli-setup.md) |
| **OpenAI Codex CLI** | `codex plugin marketplace add Sajidisrar/ios-claude-skills` then `codex plugin add ios-claude-skills@ios-claude-skills` | [docs/codex-setup.md](docs/codex-setup.md) |
| **OpenCode** | Reads `skills/` natively — point it at a clone of this repo, no setup | — |
| **Swift Package Manager** | Add the package, then `swift package --allow-writing-to-package-directory install-ios-skills` | [below](#swift-package-manager) |

## Install

One-liner, defaults to Claude Code project-level:

```bash
curl -fsSL https://raw.githubusercontent.com/Sajidisrar/ios-claude-skills/main/install.sh | bash
```

```bash
# A specific tool, or every project on your machine instead of just one, or one skill only:
curl -fsSL .../install.sh | bash -s -- --tool cursor
curl -fsSL .../install.sh | bash -s -- --tool claude --scope user
curl -fsSL .../install.sh | bash -s -- --skill ios-bug-triage
```

Run `install.sh --help` for the full flag list. After installing, restart your tool (or start a new session) so it picks up the new skills.

### Swift Package Manager

If your project is a Swift package, add this repo as a dependency and use its command plugin — it copies the skills into your package, with the same `--tool` and `--skill` options as `install.sh`:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Sajidisrar/ios-claude-skills.git", from: "1.2.0"),
],
```

```bash
swift package --allow-writing-to-package-directory install-ios-skills
swift package --allow-writing-to-package-directory install-ios-skills --tool cursor --skill ios-bug-triage
```

Run it from your package's root (where `Package.swift` is). It writes only inside your package, so there is no user-level scope; use `install.sh --scope user` for that. Apps managed only as an Xcode project, without a `Package.swift`, should use the plugin marketplace or `install.sh` instead.

### Versions and updates

Releases follow [Semantic Versioning](https://semver.org/) and are tagged `vX.Y.Z` — see [CHANGELOG.md](CHANGELOG.md) and [Releases](https://github.com/Sajidisrar/ios-claude-skills/releases). SwiftPM's `from:` picks up new minor and patch releases with `swift package update`; plugin installs update through your tool's plugin manager.

## How to use a skill

Most skills trigger automatically — each tool reads a skill's `description` and pulls it in when your request matches (e.g. asking "why is this crashing" can trigger `ios-bug-triage` on its own).

Two skills — `ios-precommit` and `ios-commit` — are marked `disable-model-invocation: true` in Claude Code, meaning they **only** run there on an explicit slash command:

```
/ios-precommit
/ios-commit
```

That field is Claude Code-specific; other tools ignore it and will auto-trigger these two like any other skill based on their description — see each tool's setup doc under `docs/` for the exact caveat. You can invoke any skill explicitly by name on any tool, even ones that also trigger automatically, when you want to be certain which one runs.

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

**"We need to upgrade this module to Swift 6."**
→ triggers `ios-swift6-concurrency-migration`. It has you surface the concurrency warnings under Swift 5 first (rather than flipping the language mode blind), works leaf-modules-first, and treats every new `@preconcurrency`/`@unchecked Sendable` as needing a one-line justification, not a silencer.

**"Add Alamofire for networking."**
→ triggers `ios-dependency-assessment`. Before writing any code, it asks what problem Alamofire actually solves that the platform or the existing networking layer doesn't, checks licence/maintenance/transitive-dependency risk, and recommends with the trade-off stated explicitly — including "write it ourselves" as a valid answer.

**"The list screen feels janky when scrolling."**
→ triggers `ios-performance-tuning`. It asks you to measure with Instruments first, checks the usual causes for this architecture (redundant fetches, whole-list invalidation, formatter churn), and requires a before/after number — "it feels better" isn't a result it accepts.

## 1. Build — writing a feature

| Skill | Purpose | Triggers on |
|---|---|---|
| `ios-feature-module` | Scaffold a complete feature module — model, endpoints, repository, view models, screens, tests | Adding a new feature, screen set, resource or CRUD area |
| `ios-api-endpoint` | Add or change a single API call — endpoint, wire models, repository method, tests | Wiring up a new backend call or changing a request/response shape |
| `ios-api-contract-migration` | Adapt the app to a changed backend contract (renamed/removed fields, new error shapes, versioned rollout) | The API changed — renamed fields, new error shape, a version bump |
| `ios-swiftui-screen` | Build or change a SwiftUI screen — loading/empty/error states, forms, navigation, accessibility | Adding/changing a screen, or fixing loading/empty/error states |
| `ios-offline-write` | Make create/update/delete work offline — outbox queueing, optimistic records, replay on reconnect | A save must survive a dropped connection |
| `ios-knowledge-base` | Keep a compact, git-tracked map of the app's structure, decisions and conventions, refreshed from `git diff`, so agents skip re-exploring the code (fewer tokens) | Starting on an unfamiliar codebase, mapping/documenting the app, KB stale after merges |
| `ios-port-to-android` | Port an iOS app to native Android (Kotlin/Compose) — inventory, platform mapping, gap list, vertical slices, parity check | Bringing an iOS app to Android, finding an Android equivalent |
| `ios-port-from-android` | Port an Android app to native iOS (Swift/SwiftUI) — inventory, platform mapping, App Review limits, vertical slices, parity check | Bringing an Android app to iOS, finding an iOS equivalent |

## 2. Quality — making sure it actually works

| Skill | Purpose | Triggers on |
|---|---|---|
| `ios-unit-tests` | Write or extend unit tests using the codebase's stubs/spies and test doubles | Adding tests, improving coverage, a bug needs a regression test |
| `ios-bug-triage` | Diagnose and fix a bug or crash methodically — reproduce, write a failing test, fix the cause | A crash log, bug report, or "why is this not working" |
| `ios-concurrency-audit` | Audit/fix Swift Concurrency issues — actor isolation, Sendable, cancellation, data races | A crash/warning involves threading, or reviewing async code |
| `ios-performance-tuning` | Diagnose and fix performance problems — slow launch, jank, redundant network calls, memory growth | A screen feels slow, stutters, or a request fires repeatedly |
| `ios-accessibility-audit` | Audit/fix accessibility — VoiceOver, Dynamic Type, contrast, hit targets, focus order | Checking/improving accessibility, or a pre-release screen review |
| `ios-design-fix` | Compare screens to the design source (prototype, Figma export, screenshots), fix differences in SwiftUI, verify on iPhone and iPad simulators | Matching screens to the design, or fixing and verifying UI bugs from tickets |

## 3. Review — judgment calls before it ships

| Skill | Purpose | Triggers on |
|---|---|---|
| `ios-secure-review` | Pre-commit review against architecture, secure-coding and compliance rules | Reviewing a diff before a pull request |
| `ios-dependency-assessment` | Assess a third-party package/SDK before adding it, as a supplier decision | Evaluating or adding a third-party package/SDK |
| `ios-refactor` | Refactor without changing behaviour — extract types, split files, remove duplication | Cleaning up, splitting, or modernising existing code |

## 4. Ship — commit, PR, release

| Skill | Purpose | Triggers on |
|---|---|---|
| `ios-build-configuration` | Set up configurations, schemes and `.xcconfig` build variables per environment, and investigate configuration-caused build, signing or wrong-environment issues | Adding an environment or build variable, or a build/archive/launch fails for configuration reasons |
| `ios-release-prep` | Prepare a release — version/build numbers, archive, TestFlight, release notes, pre-release checks | Cutting a release, bumping the version |
| `ios-commit-and-pr` | Write commits and PR descriptions to a team's conventions | Committing, writing a commit message, or describing a PR |
| `ios-precommit` | Developer pre-commit review of the current diff, with a commit/no-commit decision | Explicit `/ios-precommit`, before committing |
| `ios-commit` | Write the permanent audit record for a commit, reconciling it with `ios-precommit`'s review | Explicit `/ios-commit`, right after a successful commit |

`ios-precommit` and `ios-commit` are a matched pair: the first reviews a pending diff and writes a temporary record; the second finalizes that record once the diff is actually committed, matching it by content fingerprint rather than assuming "the last review" is the right one.

Both of those two also mention an `ios-code-review` skill ("a separate CTO/half-yearly project assessment — do not confuse the two") purely as a contrast to explain their own scope. **That skill is not part of this collection** — it's referenced from the source project this was extracted from, not something you need to go find.

## 5. Frameworks & Platform

These are framework-scoped rather than lifecycle-stage-scoped — reach for the one that matches what you're integrating, at whatever point in the build/quality/review/ship cycle it comes up.

| Skill | Purpose | Triggers on |
|---|---|---|
| `ios-swift6-concurrency-migration` | Upgrade a module to Swift 6 language mode — Sendable audits, actor-isolation fixes, incremental per-module rollout | Migrating to Swift 6, fixing new Sendable/isolation errors |
| `ios-swift-testing-migration` | Adopt Swift Testing (`@Test`, `@Suite`, `#expect`) alongside or instead of XCTest | Migrating tests to Swift Testing, adding parameterized tests |
| `ios-swiftdata` | SwiftData schema design, relationships, `VersionedSchema` migrations | Adding SwiftData persistence, migrating a schema |
| `ios-combine-patterns` | Combine in a codebase that predates/mixes with async-await — bridging, retain-cycle traps | Fixing a Combine leak, bridging Combine into async code |
| `ios-coreml-apple-intelligence` | Core ML integration and the Foundation Models framework (Apple Intelligence) | Adding an ML feature, using Core ML or Foundation Models |
| `ios-storekit-subscriptions` | StoreKit 2 in-app purchases and subscriptions — purchase flow, verification, renewal | Adding IAP, implementing a paywall, handling renewal |
| `ios-privacy-compliance` | Privacy manifest, required-reason APIs, permission strings, App Store privacy answers | Adding a privacy manifest, declaring a required-reason API |
| `ios-deep-linking` | Universal Links and custom URL schemes — associated domains, routing, testing | Adding deep linking, handling a Universal Link |
| `ios-cloudkit-sync` | Sync via CloudKit — record zones, push-driven sync, conflict resolution | Adding iCloud sync, debugging a sync conflict |
| `ios-widgetkit-live-activities` | Widgets and Live Activities — timeline design, deep linking, push updates | Adding a widget, building a Live Activity |
| `ios-push-and-background-tasks` | Push notifications and `BackgroundTasks` scheduling | Adding push notifications, scheduling background work |
| `ios-latest-os-adoption` | Check a screen against current HIG and the newest OS's design language/APIs | A new iOS version shipped; auditing against current HIG |
| `ios-sdk-upgrade` | Move to a new Xcode/iOS SDK (currently Xcode 27 / iOS 27) — host requirements, build breaks, required launch changes, deprecations, upload deadlines | Upgrading Xcode, or the app stops building/launching after an update |
| `ios-app-intents-siri` | Expose content and actions to Siri, Spotlight, Shortcuts and Apple Intelligence with App Intents — entities, intents, schemas, View Annotations, testing | Adding Siri/Shortcuts/Spotlight support, migrating from SiriKit |
| `ios-localization` | Localize with String Catalogs — localizable strings, plurals, formatting, RTL, agent translation with review, coverage | Adding a language, fixing untranslated or truncated strings |

This category closes the "basic requirements" gap this repo had against comparable Apple-platform skill collections (Axiom, rshankras/claude-code-apple-skills, Prisma-Labs-Dev/apple-skills) — those are **framework-reference** packs (one skill per Apple framework); the 1–4 categories above are **workflow-process** (one skill per dev-lifecycle stage). Both matter; this repo now has both.

**Next to Apple's own agent skills.** Xcode 27 ships Apple-authored agent skills (for example a SwiftUI specialist and security-settings audit) and lets Xcode's agents load plugins that contain skills. Those cover how to use Apple's APIs; this collection covers the workflow around them — scoping, testing, reviewing, configuring and shipping — and the two work side by side. iOS 27-specific guidance here is added alongside the existing advice for earlier iOS versions, never in place of it.

## Gaps — not yet covered

- **CI/CD** — no skill for pipeline config (Fastlane, GitHub Actions/Bitrise/Xcode Cloud lanes).
- **PR *review*** — `ios-precommit`/`ios-secure-review` cover reviewing your *own* diff before committing; nothing covers reviewing a teammate's already-open PR.
- **Incident/hotfix path** — `ios-release-prep` assumes a normal cadence; no fast-path skill for "ship a one-line fix to production now."
- **Extensions beyond widgets** — App Clips, watchOS companions, notification service extensions aren't covered.
- **ASO/App Store marketing** — keyword optimization, screenshots, store listing copy. Deliberately out of scope: this collection is engineering workflows, not marketing.

**Not included, on purpose:** agent personas, an eval test-case harness, session hooks, a published npm/npx installer package. These show up in some comparable repos; adding them would be a meaningfully different kind of commitment (ongoing package maintenance, a much larger file surface) than this collection currently takes on.

## Project structure

```
ios-claude-skills/
├── .claude-plugin/       # Claude Code plugin + marketplace manifest
├── .codex-plugin/        # Codex plugin manifest
├── .agents/plugins/      # Codex-ecosystem marketplace entry
├── plugin.json           # generic fallback for other plugin-aware hosts
├── skills/               # all 37 skills, flat — skills/<name>/SKILL.md
├── docs/                 # per-tool setup guides
├── install.sh            # curl | bash installer
├── Package.swift         # SwiftPM manifest for the install-ios-skills command plugin
├── Plugins/              # the plugin's source
├── scripts/              # bump-version.sh
├── .github/workflows/    # release.yml — publishes a GitHub Release for each vX.Y.Z tag
├── CHANGELOG.md
├── CONTRIBUTING.md
├── AGENTS.md             # meta-instructions for contributors to this repo
└── README.md
```

## Adapting these to your project

These were written against one real iOS codebase (Swift Concurrency, SwiftUI, iOS 16 floor, an outbox-based offline-write pattern). Expect to edit:

- **Architecture specifics** — layer names (`Core`/`Features`), protocol names (`APIClient`, `CacheStore`, `Outbox`), and the `Features/Widgets` reference-implementation pointer in `ios-feature-module` all assume a particular project shape. Point them at your own.
- **Ticket/task linkage** — `ios-commit-and-pr` assumes a `TASK-123`-style ticket reference; swap in your own tracker's convention.
- **Compliance gates** — `ios-secure-review` and `ios-commit-and-pr` reference a generic "AI-code policy" where the original had specific internal policy codes. Replace with your own, or delete if you don't have one.
- **iOS version floor** — several lifecycle skills assume iOS 16 as the minimum target and ban iOS 17+ APIs accordingly. Update if your deployment target is different.

## Notes

- All sample/test data and naming in these skills is intentionally generic (`Widget`-style placeholders, `example.com`) — no real client, product or personal data.
- Each `SKILL.md` ends with a verification checklist. These exist so an agent reports what it actually checked rather than asserting "done" — keep that pattern if you edit or extend a skill.
