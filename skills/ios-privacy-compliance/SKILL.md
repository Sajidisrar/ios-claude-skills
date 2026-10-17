---
name: ios-privacy-compliance
description: Prepare or audit an iOS app's privacy surface before submission — the privacy manifest (PrivacyInfo.xcprivacy), required-reason API declarations, permission usage strings, and the App Store Connect privacy nutrition-label answers. Use when asked to add a privacy manifest, declare a required-reason API, write a permission usage string, fill out App Store privacy details, or check whether a change affects what the app discloses about data collection.
---

# Privacy manifest and App Store privacy compliance

This is a disclosure-accuracy problem, not a code-correctness one: the risk is the manifest, usage strings, and App Store answers describing something *other* than what the app actually does. Treat every one of these as needing to match the real behavior of the current build, not the behavior at the time they were last written.

## 1. The privacy manifest (`PrivacyInfo.xcprivacy`)

Every app target, and every third-party SDK that collects data, needs one. It declares, as structured data (not prose):

- **`NSPrivacyCollectedDataTypes`** — what categories of data this target/SDK collects (e.g. name, email, device ID, usage data), whether each is linked to the user's identity, whether it's used for tracking, and the purpose (app functionality, analytics, product personalization, etc.).
- **`NSPrivacyAccessedAPITypes`** — which **required-reason APIs** this target calls, each with one of Apple's enumerated reason codes. These are APIs Apple has flagged as commonly misused for fingerprinting (e.g. file timestamp APIs, `UserDefaults` access on behalf of another app, disk space APIs, system boot time). Using one of these APIs *without* declaring a matching reason, or declaring a reason that doesn't match how it's actually used, is a real App Store Connect rejection risk — not a style nitpick.
- **`NSPrivacyTracking`** — whether this target engages in tracking as Apple defines it (linking data with third parties for advertising/measurement purposes across apps/websites the user doesn't control) and, if so, the associated tracking domains.

For a dependency added via `ios-dependency-assessment`: check whether it ships its own `PrivacyInfo.xcprivacy` (most modern SPM packages that collect any data should). If it doesn't and it clearly uses a required-reason API or collects data, that's a real finding for the dependency assessment, not something to work around by omitting the declaration.

## 2. Required-reason APIs — declare honestly, not just "whichever reason compiles"

Each required-reason API category has a fixed, enumerated set of valid reason codes — you pick the one that actually describes why your code calls it, you don't invent a plausible-sounding string. If none of the available reason codes honestly describe the actual use, that's a signal the API call itself needs reconsidering, not that a reason code should be picked anyway to satisfy the manifest. Grep the target for the API families Apple's required-reason list covers (file modification/creation timestamps, volume/disk space, active keyboard list, system boot time, and a few others) before assuming the manifest is complete — a required-reason API reached indirectly through a utility function is just as much a required declaration as a direct call.

## 3. Permission usage strings (`Info.plist`)

Every permission prompt (camera, location, contacts, notifications, etc.) needs an `NS*UsageDescription` string that's specific about *why this app* needs it — "This app needs access to your location" is the kind of generic string Apple review has rejected; "Used to show nearby [thing] in the list" states the actual reason. Write the string for the actual current feature, and update it when the feature using that permission changes — a leftover usage string describing a removed feature is a disclosure that no longer matches the app's behavior, which is exactly the kind of mismatch this whole skill exists to catch.

Request the permission at the point the feature actually needs it (not at launch, not speculatively) — this isn't just a UX guideline, it's what makes the usage string's "why" legible to the user in the first place.

## 4. App Store Connect privacy ("nutrition label") answers

These are a separate, broader declaration from the manifest — covering the *whole app's* data practices as presented to users in the App Store listing, not per-API-call detail. When a feature changes what data the app collects or how it's used:

- Update the relevant data-type entry (collected, linked to identity, used for tracking, purpose) in App Store Connect before that build ships — this is a manual step outside the codebase, easy to forget because nothing in the build fails if it's stale.
- Treat a new third-party SDK the same way: if it collects data on the app's behalf, that's the app's disclosure to make, not something that's automatically covered by the SDK vendor's own privacy policy.

## 5. What changes should trigger a review of all three

- Adding a new SDK/dependency that collects any data or uses a required-reason API.
- Adding, removing, or changing the purpose of a permission request.
- Adding analytics, crash reporting, or any new logging that leaves the device.
- Changing what a feature actually does with data it already had access to (e.g. a location permission that previously only showed nearby items now also gets logged for analytics — same permission, different disclosure obligation).

A code change that doesn't touch any of the above doesn't need this skill revisited — don't treat every PR as a privacy audit; treat the ones that touch data collection, permissions, or third-party SDKs as one.

## Verification

- [ ] Every required-reason API actually called by this target (directly or through a dependency) has a matching, honestly-chosen reason code declared.
- [ ] Every third-party dependency that collects data or uses a required-reason API ships its own manifest, or that gap is flagged as a dependency-assessment finding.
- [ ] Every active permission usage string describes the feature that currently uses it — not a removed or changed one.
- [ ] Permissions are requested at point of use, not speculatively at launch.
- [ ] If this change adds/changes data collection, analytics, or a data-collecting SDK, the App Store Connect privacy answers are flagged as needing an update before this build ships.
- [ ] No privacy-manifest or usage-string change describes behavior the app doesn't actually have.
