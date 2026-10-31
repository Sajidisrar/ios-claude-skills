---
name: ios-widgetkit-live-activities
description: Build Home Screen/Lock Screen widgets and Live Activities — TimelineProvider design, deep linking from a widget tap, and updating a running Live Activity from the app or a push. Use when asked to add a widget, build a Live Activity, update a Live Activity's state, make a widget deep-link into the app, or debug a widget that shows stale data.
---

# WidgetKit: widgets and Live Activities

Both live in a Widget Extension — a separate process from the main app, with its own memory and execution-time budget, that cannot assume anything the main app is doing right now is still true. Most widget bugs are "the extension can't do what app code takes for granted," not SwiftUI mistakes.

## 1. Widgets: a `TimelineProvider` is a schedule, not a live view

```swift
struct WidgetEntry: TimelineEntry {
    let date: Date
    let widget: Widget
}

struct Provider: TimelineProvider {
    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetEntry(date: .now, widget: .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let widget = try? await fetchLatest()
            let entry = WidgetEntry(date: .now, widget: widget ?? .placeholder)
            // .atEnd means "call getTimeline again once this timeline's
            // entries run out" — the widget does NOT re-render live in
            // between; it shows whatever entry's date has most recently passed.
            completion(Timeline(entries: [entry], policy: .atEnd))
        }
    }
}
```

- The widget shows the entry whose `date` has most recently arrived, from whatever timeline was last provided — it is not a live view into app state. A widget showing stale data almost always means the timeline wasn't refreshed, not that the view failed to update.
- `getSnapshot` must return fast and must work even with no network/data available — it's used for the widget gallery preview and must not block on a real fetch.
- Call `WidgetCenter.shared.reloadTimelines(ofKind:)` from the main app whenever app-side state changes in a way the widget should reflect — the extension has no way to know on its own that something changed; the app has to tell it.
- The extension has a real memory limit (tens of MB, well below the main app's budget) and a real execution-time budget for `getTimeline` — loading a large cache or doing heavy work here will get the extension killed, not just slow.

## 2. Widget data access

A Widget Extension is a separate sandbox from the main app — it cannot read the main app's container's files or `UserDefaults` directly. Shared data goes through an **App Group**:

```swift
let defaults = UserDefaults(suiteName: "group.com.example.widgetapp")
defaults?.set(encodedSnapshot, forKey: "latestWidgetSnapshot")
```

Write a small, purpose-built snapshot for the widget to read (not the app's entire cache) — the widget's job is to render a timeline entry quickly from minimal data, not to re-derive state the way the full app does.

## 3. Deep linking from a widget

```swift
Link(destination: URL(string: "https://example.com/widget/\(widget.id)")!) {
    WidgetContentView(widget: widget)
}
```

Tapping a widget (or a specific element inside a widget, via `widgetURL`/`Link` per-element in iOS 17+'s multi-target widgets) opens the app via the same Universal Link / URL-routing mechanism covered in `ios-deep-linking` — don't build a second, widget-specific routing path; funnel through the same `route(for:)` logic the rest of the app uses.

## 4. Live Activities

A Live Activity is a different mechanism from a widget's timeline — it's a single, long-running activity whose state the app (or a push) updates directly, shown on the Lock Screen and in the Dynamic Island.

```swift
struct WidgetTrackingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var progress: Double
    }
    var widgetID: String
}

// Starting one, from the app:
let activity = try Activity<WidgetTrackingAttributes>.request(
    attributes: WidgetTrackingAttributes(widgetID: id),
    content: .init(state: .init(status: "In progress", progress: 0.2), staleDate: nil)
)

// Updating it later, from the app:
await activity.update(.init(state: .init(status: "Almost done", progress: 0.9), staleDate: nil))

// Ending it:
await activity.end(activity.content, dismissalPolicy: .default)
```

- Set a **`staleDate`** when the state has a natural expiry (a delivery ETA, a timer) — the system visually marks a stale activity so the user isn't looking at a confidently-wrong number; omitting it means a Live Activity that stopped updating (app killed, push missed) looks perpetually current.
- Updating from a **push** (not just from the running app) is what keeps a Live Activity accurate when the app isn't foregrounded or running at all — `pushType: .liveactivity` push notifications carry the new `ContentState` directly; a Live Activity that only ever updates while the app happens to be open misses most of its real-world use case (tracking something that changes while you're not looking at your phone).
- End the activity explicitly once the thing it's tracking is actually finished — a Live Activity left running indefinitely after its real-world event ended is exactly the kind of "stale indicator" problem `staleDate` is meant to prevent, just permanently instead of temporarily.
- There's a limit on how many Live Activities an app can have running at once and the system can end one early under memory/resource pressure — don't assume `end()` is the only way an activity's lifecycle terminates; handle `Activity.activityStateUpdates` reporting `.dismissed`/`.ended` from the system side too.

## 4a. Additions in iOS 27

Per Apple's WWDC26 iOS guide, widgets gain customization through App Intents and dynamic
styling. Reuse the app's existing intents (`ios-app-intents-siri`) for configuration
rather than adding a parallel configuration path, and gate new APIs with
`if #available(iOS 27, *)` — the timeline guidance above still applies on every version.

## 5. Testing and debugging

- Preview widgets with `#Preview` and multiple `WidgetPreviewContext` family sizes (`.systemSmall`, `.systemMedium`, etc.) rather than only testing the size you happened to build first — a layout that works in one family can clip or overflow in another.
- "Widget shows stale data" is almost always either: the app never called `reloadTimelines`, the app-group-shared data wasn't actually written before the reload was requested, or the timeline's `policy` scheduled the next update further out than expected — check in that order before assuming a SwiftUI rendering bug.
- Live Activity push updates need testing against a real push (sandbox APNs with `liveactivity` push type) — there's no way to fully fake the "app isn't running and a push updates the activity anyway" path from the simulator alone.

## Verification

- [ ] `getSnapshot` returns fast with placeholder-safe data; it never depends on a real network fetch succeeding.
- [ ] The app calls `WidgetCenter.shared.reloadTimelines` whenever relevant state changes — the widget isn't expected to notice on its own.
- [ ] Widget-shared data goes through an App Group, as a small purpose-built snapshot, not the main app's full cache.
- [ ] Widget taps route through the same deep-link logic as the rest of the app.
- [ ] Live Activities set a `staleDate` where the tracked state has a natural expiry.
- [ ] Live Activity updates are pushed (not only app-triggered) for anything that should stay accurate while the app isn't foregrounded.
- [ ] The activity is ended explicitly when its real-world event completes, and the app also handles the system ending it early.
