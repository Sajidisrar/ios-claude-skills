---
name: ios-sdk-upgrade
description: Move an iOS app to a new Xcode and iOS SDK (currently Xcode 27 / iOS 27 SDK) — host requirements, build breaks, behaviour changes that apply just by rebuilding, deprecations, and App Store upload deadlines. Use when upgrading Xcode, when a project stops building or launching after an Xcode update, or when Apple announces a new minimum SDK for App Store uploads. Not for adopting new features (see ios-latest-os-adoption) or Swift 6 language mode (see ios-swift6-concurrency-migration).
---

# Upgrade to a new Xcode and SDK

Building with a new SDK changes behaviour even with no code change: some APIs switch
implementation, some requirements become mandatory, and some deprecated paths stop
working. Treat the upgrade as its own change, separate from feature work, so a regression
can be traced to it.

## 0. Read Apple's notes first, not memory

For the target versions, read Apple's *Xcode Release Notes* and *iOS & iPadOS Release
Notes* (developer.apple.com/documentation), and the *Upcoming Requirements* page
(developer.apple.com/news/upcoming-requirements). The checklist below was checked against
the Xcode 27 / iOS 27 notes; re-check it for any later release.

## 1. Can this machine and CI build at all?

Xcode 27 (checked October 2026):
- Runs only on **Apple silicon** Macs, and needs **macOS Tahoe 26.6 or later**. Update CI
  runners/images first; an Intel build agent can no longer run it.
- Includes **Swift 6.4**. Language mode doesn't change by itself, but new warnings appear.
- On-device debugging needs iOS 17 or later; older test devices can't be debugged.

## 2. Build breaks to fix (Xcode 27 / iOS 27 SDK)

| Change | What breaks | Fix |
|---|---|---|
| **ld64 removed**; `-ld_classic` no longer supported | Builds passing `-ld_classic` or `-ld64` in `OTHER_LDFLAGS` | Remove the flag; fix whatever it was working around |
| **`@State` is now a macro** | `@State` with an initial value *and* assigned in `init`; `@State` combined with another property wrapper or macro; some generic inference; the synthesized private memberwise init of a struct whose stored members are all private | Give the value in only one place; write types explicitly; write the init yourself |
| SE-0508 known source break | A computed property with an `init` accessor and an array/dictionary literal initial value, getter written first | Put the `init` accessor first |
| Unique Clang module names | Duplicate module names in the dependency graph may error | Rename one module |

## 3. Launch and runtime requirements (iOS 27 SDK)

- **Scene-based life cycle is required.** Apps built with the latest SDK that don't adopt
  it fail to launch. UIKit apps need a scene configuration and a `UISceneDelegate`; move
  app-delegate window and lifecycle code into it. SwiftUI `App` apps already comply.
- **A launch screen is required.** `Info.plist` must contain `UILaunchStoryboardName`,
  `UILaunchStoryboards`, `UILaunchScreen` or `UILaunchScreens`, or App Store uploads are
  rejected.
- **`TabView` selection must be a visible tab** — setting it to a hidden or unavailable
  tab can now crash.
- **Presented view controllers inherit traits through the view hierarchy**, not directly
  from the presentation controller. Check custom `UIPresentationController` subclasses.
- **Selectable `Text`** uses the system text-selection UI, with extra gestures. Check
  screens that put `.textSelection(.enabled)` inside gesture-heavy containers.

## 4. Deprecations to plan (warnings only, no deadline yet)

- `PreviewProvider` and its preview modifiers → `#Preview`.
- `canOpenURL(_:)` → open the URL and handle failure; prefer Universal Links
  (`ios-deep-linking`).
- `FileDocument` → `ReadableDocument` / `Document`.
- Original MetricKit (`MXMetricManager`, `MXMetricPayload`…) → `MetricManager`
  (`ios-performance-tuning`). Recompile if you reference `ScrollHitchTimeMetric`, or it
  crashes at launch on iOS 27.

Fix deprecations in their own commits, after the app builds and launches cleanly.

## 5. Deadlines

- From **April 2027**, App Store uploads for iOS and iPadOS must be built with the iOS 27
  SDK or later. Plan the upgrade to land well before that, including a TestFlight cycle.
- Check *Upcoming Requirements* for any other dated requirement before each release.

## 6. Order of work

1. Upgrade CI and one developer machine; build on a branch.
2. Fix build breaks (§2) until it compiles with no new errors.
3. Fix launch/runtime requirements (§3); run the app on the newest OS and the oldest
   supported OS.
4. Full test suite; then `ios-accessibility-audit` and a visual pass on key screens
   (system components can look different after a rebuild).
5. Deprecations (§4), each in its own commit.
6. Record the upgrade (Xcode/SDK/Swift versions, date) in the knowledge base.

## Verification

- [ ] Apple's release notes for the exact Xcode and SDK versions were read; anything here
      that changed in a later release was updated.
- [ ] CI and local machines meet the host requirements; CI builds with the new Xcode.
- [ ] No `-ld_classic`/`-ld64` flags remain; the app builds with no new errors.
- [ ] Scene-based life cycle adopted and a launch-screen key present in `Info.plist`.
- [ ] App launches and the main flows work on the newest OS and the oldest supported OS.
- [ ] Test suite green; visual and accessibility pass done on key screens.
- [ ] Remaining deprecations listed with owners; upload deadline noted in the release plan.
