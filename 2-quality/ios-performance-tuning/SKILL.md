---
name: ios-performance-tuning
description: Diagnose and fix performance problems in this iOS app — slow launch, janky scrolling, redundant network calls, memory growth, battery drain from sync. Use when a screen feels slow, a list stutters, the app is slow to start, memory climbs, the same request fires repeatedly, or when asked to profile or optimise something.
---

# Tune performance

Measure first. In SwiftUI, the cause of jank is almost never where it feels like
it is, and an optimisation applied on a hunch usually costs readability for
nothing.

## Measure

| Symptom | Tool |
| --- | --- |
| Slow launch | Instruments → App Launch; check what runs in `bootstrap()` |
| Janky scrolling | Instruments → SwiftUI, plus `Self._printChanges()` in the suspect view (temporary debug aid only — an undocumented, underscore-prefixed API with no stability guarantee; strip it before committing) |
| Redundant requests | The `AppLog` networking category — every request logs `→ METHOD /path` |
| Memory growth | Instruments → Allocations and Leaks; retain cycles in closures |
| Battery | Xcode Energy gauge; look at sync frequency and monitor callbacks |

Note the number before and after. "It feels better" is not a result.

## The usual causes in this architecture

1. **Redundant fetches.** `onAppear()` guards on `case .idle` for a reason — remove
   that guard and every tab switch refetches. Check:
   - `.task` on a row triggering paging more than once (`loadMoreIfNeeded` guards
     on `isLoadingMore`).
   - Search not debounced, so four keystrokes are four requests.
   - Two view models built for the same screen because the view was recreated —
     `@StateObject`, not `@ObservedObject`, for owned view models.

2. **Whole-list invalidation.** `ObservableObject` invalidates the view on any
   `@Published` change. So:
   - Keep the primary content in one `LoadState` and avoid publishing properties
     that change on every keystroke alongside it where possible.
   - Give `ForEach` stable identity (`Identifiable` with a real id, never
     `.indices`).
   - Keep row views cheap: no date formatter created in `body`, no filtering or
     sorting in `body`. Precompute in the view model.

3. **Formatter and encoder churn.** `DateFormatter` and `JSONEncoder` are
   expensive to create. This project keeps them as statics (`JSONDecoder.api`,
   `ISO8601DateFormatter.api`). Never construct one inside `body` or inside a
   loop.

4. **Cache writes on the hot path.** `FileCacheStore` writes whole JSON files. For
   a large collection, write once per fetch rather than per item, and consider
   caching only the first page or two — a user who is offline needs the recent
   screens, not everything.

5. **Launch work.** `AppEnvironment.bootstrap()` runs before the first screen. It
   should do the minimum: restore the session, start the monitor, count pending
   items. Draining the outbox is fine because it is awaited off the critical path;
   anything that blocks the first paint is not.

6. **Sync frequency.** Sync is triggered by connectivity returning, the app
   becoming active, and explicit refresh — deliberately not a timer. Do not add
   one; a repeating timer that fires while offline burns battery for nothing.

7. **Images.** Not covered by this template. If images arrive, add a bounded cache
   with downsampling before decode (`CGImageSourceCreateThumbnailAtIndex`) — full
   resolution decoded into a 60-point row is the most common memory bug in list
   screens.

## Retain cycles to check

- `Task { }` inside a view model capturing `self` strongly and outliving it — use
  `[weak self]` for anything long-running.
- Closures stored as properties (`onSignedOut`, `setStateHandler`) — both use
  `[weak self]` at the capture site; keep it that way.
- `NWPathMonitor.pathUpdateHandler` capturing `self` — already `[weak self]`.

## Verification

- [ ] A measurement before and after, with the numbers stated.
- [ ] The fix addresses what the measurement showed, not what you guessed.
- [ ] No readability sacrificed for an unmeasured gain.
- [ ] Request count for the scenario checked in the networking log — no
      duplicates.
- [ ] Memory stable after ten navigations in and out of the screen.
- [ ] No new caching layer added without a cap and an eviction story.
