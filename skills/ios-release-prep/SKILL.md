---
name: ios-release-prep
description: Prepare a release of this iOS app — version and build numbers, environment configuration, archive and TestFlight steps, release notes, and the pre-release checks that are easy to skip. Use when asked to cut a release, prepare a build for testing or the App Store, bump the version, produce release notes, or check whether something is ready to ship.
---

# Prepare a release

## 1. Decide the version

Version numbers live in `Config/Base.xcconfig`, not in `Info.plist` — the plist
reads `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)` from the build
settings.

- `MARKETING_VERSION` is semantic: major for a breaking change to how the app is
  used, minor for features, patch for fixes.
- `CURRENT_PROJECT_VERSION` is the build number. It must increase for every
  upload to App Store Connect and never reset. In CI, pass it at build time
  (`BUILD_NUMBER=482 ./Scripts/build.sh archive production`) rather than
  committing a bump.

Tag the release commit: `v1.4.0`.

## 2. Verify the configuration is the one you think it is

This is where releases go wrong. Check, in the Release configuration:

- [ ] `API_BASE_URL` in `Config/Environment-Production.xcconfig` points at
      production, and is
      `https`. `AppConfiguration` refuses anything else at launch, which is a
      backstop, not a substitute for checking.
- [ ] `ENVIRONMENT_NAME` is `production`.
- [ ] You are archiving from the **`AppTemplate-Production` scheme**, not merely a
      Release configuration. The scheme decides what an archive contains, and
      this is the single most common release mistake.
- [ ] `ALLOW_INSECURE_LOGGING` is `NO`. `AppConfiguration` forces it off in
      production regardless, but the file should say what it means.
- [ ] `LOG_LEVEL` is `error`.
- [ ] Bundle identifier and display name have no `.dev` suffix.
- [ ] No App Transport Security exception has appeared in `Info.plist`.
- [ ] Signing: correct team, distribution certificate, current provisioning
      profile, push entitlement if used.

Build with the Release configuration and confirm the app talks to production, not
to whatever the last debug session used.

## 3. Pre-release checks

- [ ] Full test suite green on CI, not just locally.
- [ ] SwiftLint clean with no new suppressions.
- [ ] SAST clean; any accepted finding recorded with a rationale and an owner.
- [ ] No `TODO`, `FIXME`, debug flag or feature toggle left switched on. `Grep`
      for them.
- [ ] Upgrade path tested: install the previous version, use it, create queued
      offline work, then install this build over the top. Queued writes must still
      replay and cached data must not decode into something wrong. This is the
      check most often skipped and the one that produces the worst bugs.
- [ ] A signed-out cold launch, a signed-in cold launch, and an expired-session
      launch all behave correctly.
- [ ] Offline behaviour on a real device with aeroplane mode — not just the
      simulator's Network Link Conditioner.
- [ ] Accessibility pass on new screens (VoiceOver, largest text size).
- [ ] Tested on the oldest supported OS (iOS 16) and the smallest supported
      device, not only the latest simulator.
- [ ] Privacy manifest and App Store privacy answers still accurate if data
      handling changed.

### 3a. Platform requirements for this release

Check Apple's *Upcoming Requirements* page (developer.apple.com/news/upcoming-requirements)
and the current *App Review Guidelines* before every release — both change during the year.
As of October 2026:

- [ ] From April 2027, iOS and iPadOS uploads must be built with the iOS 27 SDK or later
      (see `ios-sdk-upgrade`). Builds with the iOS 27 SDK must include a launch screen and
      adopt the scene-based life cycle.
- [ ] App Review tightened its rules on low-quality and minimal-functionality apps in
      June 2026, and the guidelines were revised again in October 2026. Re-read the
      sections your app touches (payments, sign-in, user-generated content, AI features).
- [ ] The build configuration and scheme are the ones you think they are
      (`ios-build-configuration` if anything looks off).

## 4. Archive and distribute

```bash
BUILD_NUMBER=482 ./Scripts/build.sh archive production

xcodebuild -exportArchive \
  -archivePath build/AppTemplate-production.xcarchive \
  -exportOptionsPlist Config/ExportOptions-AppStore.plist \
  -exportPath build/export
```

Set `teamID` in `Config/ExportOptions-AppStore.plist` before the first use.
`Config/ExportOptions-AdHoc.plist` is the equivalent for distributing a
Development or Staging build to registered devices.

Verify what you actually built before uploading — unzip the `.ipa` and check
`API_BASE_URL` and `ENVIRONMENT_NAME` in `Info.plist`. Thirty seconds, and it has
saved releases.

Keep the archive and its dSYMs — symbolising a crash report from a build whose
dSYM was discarded is not possible.

## 5. Release notes

Two audiences, two versions:

- **Testers and stakeholders:** what changed in plain language, what to test,
  what is knowingly not finished. Link the tasks and tickets.
- **App Store "What's New":** user-facing benefit only. No internal references,
  no ticket numbers, no apologies for bugs users never saw.

## 6. After release

- Tag the commit and push the tag.
- Record the build number against the release in the tracker.
- Watch crash reports and the sync failure counts for the first day.
- Note anything that made this release awkward, so the next one is less so.

## Verification

- [ ] Version and build numbers correct and build number increased.
- [ ] Release configuration verified line by line against the list above.
- [ ] Upgrade-over-previous-version test performed, including queued offline work.
- [ ] Tests, lint and SAST all clean on CI.
- [ ] Archive and dSYMs retained.
- [ ] Release notes written for both audiences.
- [ ] Confirm with the release owner before uploading — do not distribute a build
      on your own initiative.
