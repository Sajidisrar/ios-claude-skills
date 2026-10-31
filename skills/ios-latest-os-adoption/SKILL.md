---
name: ios-latest-os-adoption
description: Decide what to adopt from a new iOS release — checking a screen or feature against Apple's current Human Interface Guidelines and the newest OS's design language (e.g. Liquid Glass) and APIs, and distinguishing what's worth adopting now from what can wait. Use when a new iOS version has shipped, when asked to update the app's look for the newest OS, to audit a screen against current HIG, or to decide whether a new API is worth adopting this cycle.
---

# Adopt a new iOS release deliberately

A new OS version is not an obligation to rewrite anything — it's a prompt to make three separate decisions: does anything look wrong now, is there a new API worth adopting, and is there a deprecation that needs a response. Conflating these into "update everything for iOS N" produces unfocused, risky changes.

## 1. Visual regression check first, before adopting anything new

Apple's system components (navigation bars, lists, controls, system materials) can visually shift between OS versions even with no app code change — a new release's design language (most recently, the Liquid Glass material introduced across the system) changes how standard controls render by default. Before writing any adoption code:

- Run the current app, unmodified, on the new OS and look for: standard controls rendering unexpectedly, custom chrome that assumed a previous system look now clashing with it, contrast or legibility regressions where a custom background interacts badly with a new translucent/material system element.
- A regression found here is a bug-fix task (`ios-bug-triage`-shaped), not an adoption task — fix what broke before deciding what to adopt.

## 2. What's worth adopting now vs. later

| Signal | Adopt now | Can wait |
|---|---|---|
| The new API replaces something explicitly deprecated with a removal timeline | Yes — plan it like any other deprecation, don't let it become urgent later | — |
| The new design language changes a standard control your screens already use unmodified | Usually free — you get it by raising the deployment target / rebuilding against the new SDK, not by writing adoption code | — |
| A new capability directly serves a planned feature | Yes, scoped to that feature | — |
| A new capability is cosmetically nicer but serves no current feature | — | Yes — this is `ios-dependency-assessment`-style reasoning applied to a platform API: is the need real now, or anticipated |
| The new API requires a deployment-target bump that drops support for devices/OS versions this app currently supports | Needs an explicit product decision (how many real users are on the dropped versions) before any code changes | — |

## 3. Checking against current HIG

Apple's Human Interface Guidelines change incrementally, not wholesale, each cycle — check the specific areas a screen actually touches rather than re-reading the whole document for every change:

- **Materials and depth** — is this screen using a custom opaque background where the current guidance now favors a system material that adapts automatically (and gets future OS visual updates for free)? A hand-rolled background is a maintenance cost every cycle after this one.
- **Controls** — are standard controls used as-is (inheriting the current OS look automatically) versus custom-drawn equivalents that now need manual updates to match? Prefer standard controls unless the custom look is a deliberate brand decision, in which case that decision's cost (manual upkeep every OS cycle) should be stated, not assumed away.
- **Icons and symbology** — SF Symbols get new glyphs and rendering modes with new OS releases; a custom icon set doesn't automatically benefit, which is itself a cost worth weighing against brand consistency, not an oversight to silently fix.
- **Accessibility baseline** — a HIG update sometimes raises the bar on something `ios-accessibility-audit` already checks (contrast, Dynamic Type, motion). Re-run that skill's checklist on a screen being touched for OS adoption anyway — one pass, not two separate audits.

### 3a. What changed in the iOS 27 cycle (as of October 2026)

Additive to the checks above; for build breaks and required changes, use `ios-sdk-upgrade`.

- **Design:** refreshed materials, refined typography, and updated tab and navigation bars.
  Re-check custom bars and backgrounds next to system ones.
- **Menus:** on iPadOS 27 the menu bar, and on macOS 27 context menus too, show a reduced
  set of item images by default. Review the HIG for which items should keep images; use
  `labelStyle(.titleAndIcon)` in SwiftUI or `preferredImageVisibility` in UIKit to opt in.
- **Status bar:** SwiftUI can set it with `.toolbarColorScheme(_:for: .statusBar)` and hide
  it with `.toolbarVisibility(_:for: .statusBar)`.
- **Search:** with center search-bar placement, `UISearchController`'s scope bar now sits
  inline beside the search field.
- **Navigation bar minimization:** `UINavigationItem.navigationBarMinimization` replaces
  `barMinimizeBehavior` and `barMinimizationSafeAreaAdjustment`.
- **SwiftUI:** `AsyncImage` now honours HTTP caching; document apps get `ReadableDocument`
  and `WritableDocument`; pickers gain `TabsPickerStyle`.
- **Apple Intelligence on screen:** see `ios-app-intents-siri` (View Annotations) and
  `ios-coreml-apple-intelligence`.

## 4. Gating new APIs for a range of supported OS versions

```swift
if #available(iOS 26, *) {
    // Adopt the new API/material here.
} else {
    // Existing behavior — not a degraded experience, just the previous one.
}
```

- Availability-gate at the smallest reasonable scope (the specific view/call site), not by duplicating a whole screen into an "old" and "new" version — that doubles the maintenance surface for every subsequent change to that screen.
- The `else` branch is the *previous, working* behavior, not a second-class one that gets left to bitrot — a user on last year's supported OS isn't using a worse app, they're using the version appropriate to their OS.
- Don't raise the deployment target just to simplify away an `#available` check unless dropping those OS versions is the explicit decision from §2's table — the availability check existing is not itself a problem to clean up.

## Verification

- [ ] The app was actually run on the new OS before any adoption work started, and any visual regression found was fixed as a bug, separately from adoption work.
- [ ] Each adopted API/material has a stated reason tied to a real deprecation, a planned feature, or a free upgrade via standard components — not adopted just because it's new.
- [ ] Availability checks are scoped to the specific call site, with the `else` branch treated as equally valid previous behavior.
- [ ] Any accessibility implication of the OS update was checked via `ios-accessibility-audit`'s checklist, not skipped because "it's just a visual update."
- [ ] A deployment-target bump, if proposed, has an explicit stated decision about which supported OS versions/devices it drops — not a quiet side effect of adopting one new API.
