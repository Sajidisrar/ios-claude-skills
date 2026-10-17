---
name: ios-deep-linking
description: Wire up Universal Links and custom URL schemes correctly — associated domains setup, apple-app-site-association, routing a link to the right screen and state, and testing deep links on-device. Use when asked to add deep linking, handle a Universal Link, set up a custom URL scheme, route a notification tap to a specific screen, or debug a link that opens the app but lands on the wrong screen.
---

# Deep linking (Universal Links and custom schemes)

Universal Links and custom URL schemes solve the same problem differently, and most apps need the former with the latter as a narrow fallback — not a free choice between equally good options.

## 1. Universal Links vs. custom URL scheme

| | Universal Links (`https://example.com/widget/42`) | Custom scheme (`widgetapp://widget/42`) |
|---|---|---|
| Works when the app isn't installed | Yes — opens the web page instead | No — the link just fails silently or the OS reports it can't be opened |
| Can be hijacked by another app claiming the same identifier | No — ownership is verified via the associated domain | Yes — any app can register the same scheme; there's no ownership check |
| Setup cost | Associated domains entitlement + a server-hosted `apple-app-site-association` file | A few lines in `Info.plist` |
| Good fit for | Anything shared externally (sent in a message, posted on the web, in an email) | In-app-only or OS-only triggers you fully control (a notification payload your own backend generates, an internal test harness) |

Default to Universal Links for anything a link might be shared or clicked outside the app. Keep a custom scheme only as a fallback for contexts Universal Links can't reach, or where the "no app installed" case genuinely doesn't matter.

## 2. Associated domains and the server side

The app side is an entitlement:

```
# Associated Domains capability, entitlements file
applinks:example.com
```

The server side is what actually proves ownership — a JSON file at `https://example.com/.well-known/apple-app-site-association`, served over HTTPS with no redirect, declaring the app ID and which paths it handles:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAMID.com.example.widgetapp"],
        "components": [
          { "/": "/widget/*", "comment": "Match any widget detail link" }
        ]
      }
    ]
  }
}
```

iOS fetches and caches this file; a mistake here (wrong team/bundle ID, wrong path pattern, the file not actually reachable at that exact path) is the single most common reason Universal Links "just don't work" and look like an app bug when they aren't one. Verify the file is actually served correctly — `curl -I` for the right content type and a 200, not a redirect — before debugging the app side at all.

## 3. Routing the link to the right screen and state

The part that's actually app code: turning a URL (or a custom-scheme URL, or a notification payload containing one) into navigation.

```swift
func route(for url: URL) -> DeepLinkDestination? {
    guard url.host == "example.com",
          url.pathComponents.count >= 3,
          url.pathComponents[1] == "widget"
    else { return nil }

    let id = url.pathComponents[2]
    return .widgetDetail(id: id)
}
```

- Resolve the link into a typed destination (an enum case with associated data), not a raw URL carried deep into the view layer — the view layer shouldn't need to know link syntax to know which screen to show.
- Handle the "link points at something that doesn't exist or you don't have access to" case explicitly (deleted record, no permission) — show a real empty/error state, don't silently fail to navigate or crash on a force-unwrap of data the link promised but didn't have.
- A link that arrives before the app has finished restoring its session (cold launch, not yet signed in) needs to be held and replayed once the app is actually ready to navigate — dropping it on the floor because the destination screen doesn't exist yet is a common bug, and so is routing before authentication state is known and ending up on the wrong screen's error state.
- `NSUserActivity`/`UIApplication.open(_:options:)` (depending on what's actually invoking this — Universal Link continuation vs. a custom scheme open vs. a notification tap) are different entry points that should all funnel into the same `route(for:)` logic, not three parallel ad hoc implementations that can drift out of sync.

## 4. Testing on-device

- `xcrun simctl openurl booted "https://example.com/widget/42"` opens a Universal Link in the Simulator without needing it actually hosted and clickable somewhere.
- On a real device, Universal Links can silently fall back to opening Safari instead of the app if the association file didn't validate — that's a signal to check the server file and entitlement, not a signal to add a custom-scheme fallback to paper over it.
- Test the cold-launch case specifically (app not running at all when the link is tapped), not just warm-launch — the two code paths for "receive a link" (app launch vs. already running) are genuinely different and a fix verified only warm can still be broken cold.

## Verification

- [ ] Universal Links are used for anything shareable outside the app; a custom scheme, if present at all, is scoped to contexts that genuinely can't use Universal Links.
- [ ] The `apple-app-site-association` file is verified reachable and correctly served (not redirected, correct content type) independent of the app.
- [ ] Link routing resolves to a typed destination, not a raw URL threaded into the view layer.
- [ ] A link to a missing/inaccessible resource shows a real error state, not a crash or a silent no-op.
- [ ] A link arriving before the session is restored is held and replayed once ready, not dropped.
- [ ] Tested both cold-launch and warm-launch delivery of the same link.
