# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/): a new skill or install path is a
minor release, a fix to an existing skill or the installer is a patch, and
removing or renaming a skill is a major release.

## [Unreleased]

## [1.2.0] - 2026-10-31

### Added
- `ios-sdk-upgrade` (Xcode 27 / iOS 27 SDK), `ios-app-intents-siri`,
  `ios-localization` and `ios-build-configuration` (33 → 37 skills).
- SwiftPM command plugin: add this repo as a package dependency, then run
  `swift package --allow-writing-to-package-directory install-ios-skills`.
- `CHANGELOG.md`, `scripts/bump-version.sh` and a tag-triggered release workflow.

### Changed
- iOS 27 additions, alongside the existing guidance for earlier versions:
  `ios-coreml-apple-intelligence` (Language Model protocol, multimodal prompts,
  Core AI, Evaluations), `ios-release-prep` (SDK deadline, App Review changes),
  `ios-deep-linking` (`canOpenURL` deprecation), `ios-performance-tuning`
  (`MetricManager`), `ios-widgetkit-live-activities` and `ios-latest-os-adoption`.
- README: positioning next to Xcode 27's built-in agent skills; localization
  removed from the gaps list.

## [1.1.0] - 2026-10-31

### Added
- `ios-design-fix`, `ios-knowledge-base`, `ios-port-to-android` and
  `ios-port-from-android` (29 → 33 skills).
- Closing Verification section in `ios-secure-review`.

### Fixed
- `install.sh` under `curl | bash` copied the current directory's `skills/`
  folder instead of fetching this repo.
- `install.sh --help` failed when piped.
- Local-clone installs exited with status 1.
- A missing option value crashed with an unbound-variable error.
- Root `plugin.json` description now matches the other manifests.

## [1.0.0] - 2026-10-17

### Added
- 29 skills: 17 lifecycle workflows and 12 Apple-framework skills.
- Support for Claude Code, Codex, Cursor, GitHub Copilot, Gemini CLI and
  OpenCode, plus `install.sh`.

[Unreleased]: https://github.com/Sajidisrar/ios-claude-skills/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/Sajidisrar/ios-claude-skills/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Sajidisrar/ios-claude-skills/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Sajidisrar/ios-claude-skills/releases/tag/v1.0.0
