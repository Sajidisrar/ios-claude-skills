---
name: ios-swiftui-screen
description: Build or change a SwiftUI screen in this iOS 16 codebase — view model, loading/empty/error states, forms, navigation, accessibility and Dynamic Type. Use when asked to add a screen, list, detail page, form, sheet or tab, to fix how a screen behaves while loading or failing, or to make a screen accessible. Also use when a screen must keep working offline from the user's point of view.
---

# Build a screen

## The split

- **View:** layout, bindings, and calls into the view model. Nothing else — no
  `Task` that does work, no formatting rules, no decisions about what to fetch.
- **View model:** `@MainActor final class ... : ObservableObject`, one
  `LoadState` for primary content, `banner: AppError?` for non-blocking failures,
  and presentation helpers (formatted strings, derived flags).

## iOS 16 constraints

Banned (iOS 17+): `@Observable`, `ContentUnavailableView`,
`onChange(of:initial:)`, `SwiftData`, `.scrollTargetBehavior`,
`.containerRelativeFrame`.

Available and preferred: `NavigationStack`, `.searchable`, `.refreshable`,
`.task`, `TextField(_:text:axis:)`, `lineLimit(_:)` with a range,
`.confirmationDialog`, `Grid`, `AnyLayout`, `ShareLink`.

`onChange(of:)` in iOS 16 takes the new value only:
`.onChange(of: value) { newValue in ... }`.

## Steps

1. **View model** — copy `WidgetListViewModel` (list) or `WidgetEditorViewModel`
   (form). Key points:
   - `@Published private(set) var state: LoadState<...>`; mutate only here.
   - First appearance: `.cacheFirst(maxAge:)` for instant paint, then
     `.remoteFirst` to freshen.
   - Every catch: `guard error.isCancellation == false else { return }`, then
     `AppError.from(error)`.
   - A failed refresh with content on screen sets `banner` and keeps the content.
   - Debounce search with a cancellable `Task` and ~350 ms sleep.

2. **View shell**

   ```swift
   @StateObject private var viewModel: WidgetListViewModel

   init(viewModel: WidgetListViewModel) {
       _viewModel = StateObject(wrappedValue: viewModel)
   }
   ```

   Never read a `@StateObject`'s wrapped value inside `init` — pull seed values
   from the parameter before wrapping it.

3. **States** — wrap content in `LoadStateView`, which handles loading, empty,
   error and retry consistently. Do not hand-roll the four branches.

   ```swift
   LoadStateView(
       state: viewModel.state,
       emptyMessage: "No widgets yet.",
       isEmpty: { $0.isEmpty },
       retry: { await viewModel.retry() }
   ) { widgets in
       list(widgets)
   }
   ```

4. **Forms** — bind straight to a draft on the view model
   (`$viewModel.draft.title`). Disable Save with `canSave`. Optional strings need
   an explicit `Binding` that maps empty to `nil`. Use
   `.interactiveDismissDisabled(viewModel.hasUnsavedChanges)`.

5. **Presentation** — one piece of state for "which sheet is showing", using an
   `Identifiable` mode enum and `.sheet(item:)`.

6. **Accessibility** — required, not optional:
   - `.accessibilityLabel` on every icon-only control.
   - `.accessibilityElement(children: .combine)` on composite rows.
   - No fixed heights on anything containing text; test at the largest Dynamic
     Type size.
   - Never encode meaning in colour alone — the status chip carries text too.
   - Announce state changes that matter (a queued save, a failed sync).

7. **Copy** — sentence case, British English, no exclamation marks, no blame. All
   error text comes from `AppError`, never written inline in the view.

## Verification

- [ ] No iOS 17+ API.
- [ ] Loading, empty, error and offline states all render sensibly — check each.
- [ ] A failed refresh does not blank out content the user was reading.
- [ ] Cancellation never appears as an error.
- [ ] Icon-only buttons have labels; rows combine for VoiceOver.
- [ ] Layout survives the largest Dynamic Type size.
- [ ] The view contains no business logic and no direct data access.
- [ ] A preview exists in `PreviewSupport.swift` or beside the view, using
      `PreviewWidgetRepository`-style doubles and invented data only.
