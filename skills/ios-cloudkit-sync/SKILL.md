---
name: ios-cloudkit-sync
description: Sync app data via CloudKit — private/shared database choice, record zones, push-driven sync with CKSubscription and silent notifications, and conflict resolution. Use when asked to add iCloud sync, set up a CloudKit container, handle a CloudKit sync conflict, debug data not syncing between a user's devices, or decide between CloudKit and a custom backend for a sync feature.
---

# Sync data with CloudKit

CloudKit is Apple's hosted database with built-in per-user sync — the right choice when "sync this user's data across their own devices, backed by their iCloud account" is the actual requirement. It is not a general-purpose backend: there's no cross-user querying beyond what a shared database explicitly exposes, and it doesn't replace this codebase's own API layer for anything server-logic-driven.

## 1. Private vs. shared database, and when CloudKit is the wrong tool

| Need | Fit |
|---|---|
| Sync one user's own data across their devices, no collaboration | CloudKit private database — a strong fit, little custom backend needed |
| Share specific records with named other users (collaboration, a shared list) | CloudKit shared database, via `CKShare` | 
| Data visible to all users, server-side business logic, anything needing a backend you control the behavior of | Not CloudKit — this app's existing `APIClient`/backend, CloudKit has no general server-side compute |
| Social/discovery features (find other users, public leaderboards) | CloudKit's public database can technically do this but is a poor fit for anything with real query/scale needs — treat as `ios-dependency-assessment`-style judgment, not a default |

Don't reach for CloudKit because "it's free iCloud sync" when the feature actually needs server-side logic this app's own backend already provides — that's two sources of truth for the same data, not a sync feature.

## 2. Record zones and schema

```swift
let container = CKContainer(identifier: "iCloud.com.example.widgetapp")
let database = container.privateCloudDatabase

let zoneID = CKRecordZone.ID(zoneName: "Widgets", ownerName: CKCurrentUserDefaultName)
let zone = CKRecordZone(zoneID: zoneID)
try await database.save(zone)

let record = CKRecord(recordType: "Widget", recordID: CKRecord.ID(recordName: "widget-\(id)", zoneID: zoneID))
record["title"] = title as CKRecordValue
record["createdAt"] = createdAt as CKRecordValue
try await database.save(record)
```

- Use a **custom record zone**, not the default zone, for anything you'll want to subscribe to changes on (§3) or delete as a unit — the default zone can't be deleted and doesn't support zone-level change tokens the way a custom zone does.
- CloudKit's schema (record types and their fields) is inferred from what you save in development, and must be deployed to the production CloudKit environment explicitly via CloudKit Console (or `cktool`) before release — a field that works in the sandbox/development environment but was never promoted to production is a real, easy-to-miss release blocker.
- Map CloudKit records to/from this app's own domain models explicitly — don't let `CKRecord`'s dictionary-like `subscript` access leak into the view/view-model layers; a repository-style boundary here follows the same reasoning as `ios-api-endpoint`'s wire-model boundary.

## 3. Push-driven sync — don't poll

```swift
let subscription = CKDatabaseSubscription(subscriptionID: "widgets-changes")
let notificationInfo = CKSubscription.NotificationInfo()
notificationInfo.shouldSendContentAvailable = true
subscription.notificationInfo = notificationInfo
try await database.save(subscription)
```

- A `CKDatabaseSubscription` with a silent push (`shouldSendContentAvailable = true`) is what tells the app "something changed, go fetch" without the user seeing a notification — this is the mechanism, not a polling timer. A sync feature that only refreshes on app foreground is missing the point of using CloudKit at all.
- On receiving the silent push, use `CKFetchDatabaseChangesOperation` with the **previously saved server change token** to fetch only what's new, then `CKFetchRecordZoneChangesOperation` per changed zone — never re-fetch the whole dataset on every push; that defeats the incremental-sync design and is the CloudKit equivalent of `ios-performance-tuning`'s "redundant fetches" problem.
- Persist the change token durably (it's what makes the next fetch incremental) — losing it means the next sync has to fall back to a full re-fetch, which is correct-but-slow degraded behavior, not silently wrong behavior.

## 4. Conflict resolution

CloudKit saves fail with `CKError.serverRecordChanged` when the record changed on the server since you last fetched it — this is expected under concurrent edits from multiple devices, not an error path to just retry blindly:

```swift
do {
    try await database.save(record)
} catch let error as CKError where error.code == .serverRecordChanged {
    guard let serverRecord = error.serverRecord else { throw error }
    // Merge your local changes onto the server's current version of the
    // record, field by field, then save the merged record — not the
    // original local one, which CloudKit will reject again with the same error.
    let merged = merge(local: record, server: serverRecord)
    try await database.save(merged)
}
```

- The merge strategy is a product decision, not a technical default — last-write-wins per field, a manual "which version do you want" prompt, or additive merge (for a list/collection field) all answer "what does the user actually expect" differently. State which one this feature uses and why, the same way `ios-offline-write` documents its own last-write-wins stance.
- `error.serverRecord` already has the current server state — always merge onto that, not onto a record you fetch again separately, or you've just recreated the same race.

## 5. Account and availability state

- Check `CKContainer.accountStatus()` before assuming sync is available — the user might not be signed into iCloud, might have iCloud Drive disabled for this app, or might be in a restricted/unavailable state. A feature built on CloudKit needs a real degraded-but-functional local-only mode for these cases, not a crash or a silently broken sync indicator.
- Listen for `CKAccountChanged` (the user signs out of iCloud, switches accounts, etc. while the app is running) and react — stale data from the previous account must not keep showing as if it belongs to the newly active one.

## Verification

- [ ] CloudKit was chosen for a genuine per-user-sync-across-devices need, not as a substitute for this app's own backend logic.
- [ ] Sync uses custom record zones and a `CKDatabaseSubscription` with silent push — not a foreground-only polling refresh.
- [ ] Incremental fetch uses saved server change tokens; nothing re-fetches the whole dataset on every sync trigger.
- [ ] `CKError.serverRecordChanged` is handled by merging onto `error.serverRecord`, not by retrying the original local record unchanged.
- [ ] The merge/conflict strategy for this feature is stated explicitly, not left implicit.
- [ ] `CKContainer.accountStatus()` is checked, with a real fallback for "not signed into iCloud" / "iCloud Drive disabled."
- [ ] The production CloudKit environment has the deployed schema needed for this feature, verified before release.
