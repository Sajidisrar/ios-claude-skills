---
name: ios-feature-module
description: Scaffold a complete feature module in this iOS codebase — domain model, endpoints, repository with read policies, view models, SwiftUI screens and tests — following the Features/Widgets reference implementation. Use when asked to add a new feature, screen set, resource or CRUD area to the app (for example "add a Projects feature", "we need Reports in the app", "build the Notifications section"), or when a new API resource needs an app-side home.
---

# Scaffold a feature module

Produces a feature that matches this codebase exactly, in the order that keeps
the data layer testable before any UI exists.

## Before writing code

Establish these four things. Ask the user if the answer is not in the request —
they are product decisions, not implementation details.

1. **Resource and fields.** Name, fields, types, which are server-owned
   (`id`, `reference`, `updatedAt`) and which the user edits.
2. **Operations.** Which of list / detail / create / update / delete exist.
3. **Offline stance.** Must reads work offline? Must writes? If stale data could
   be dangerous here, say so and use `.remoteOnly`.
4. **Screens.** List, detail, editor — and what each shows when empty, loading
   and failed.

Do not add an outbox unless offline writes are required. An unused queue is a
liability.

## Steps

Work in this order. Read the corresponding `Features/Widgets` file before writing
each one and mirror its structure.

1. **`Features/<Name>/Domain/<Name>.swift`**
   - Model: `Identifiable, Equatable, Hashable, Codable`, `let id`, `var` for the
     rest.
   - Status or enum fields: `String`-backed with explicit raw values matching the
     API exactly (`case inProgress = "in_progress"`).
   - `<Name>Draft`: the editable subset only, plus `init(<name>:)` and
     `validationMessages`.
   - If the feature has offline writes, add `syncState: SyncState` with a custom
     `init(from:)` using `decodeIfPresent` and a `.synced` default, and a
     `localID()` helper.

2. **`Features/<Name>/Data/<Name>Endpoints.swift`**
   - `enum <Name>Endpoints` of static functions returning `Endpoint`.
   - Paths relative, no leading slash.
   - `enum <Name>CacheKeys` with a shared `prefix` and a `pending` key if
     offline writes are in scope.
   - `enum <Name>OutboxKind` constants if offline writes are in scope.

3. **`Features/<Name>/Data/<Name>Repository.swift`**
   - `protocol <Name>Repository: Sendable` first — this is the seam.
   - `Live<Name>Repository: <Name>Repository, @unchecked Sendable` composing
     `APIClient`, `CacheStore`, `Outbox`.
   - Reads honour `ReadPolicy` and return provenance where the UI needs it.
   - Writes invalidate the list cache; validate the draft before any request.
   - Offline writes: catch `error.isConnectivityFailure`, queue, upsert an
     optimistic record, and conform to `OutboxHandler` with `replay(_:)`.
   - Use `.cache` coders for queued payloads, never `.api`.

4. **Repository tests** — write these before the UI.
   `AppTemplateTests/Features/<Name>RepositoryTests.swift`, using
   `StubAPIClient`, `InMemoryCacheStore`, `InMemoryOutbox`. Cover every read
   policy the feature uses and every offline path.

5. **`Features/<Name>/UI/<Name>ListViewModel.swift`**
   - `@MainActor final class ... : ObservableObject`.
   - `@Published private(set) var state: LoadState<[<Name>]>`, plus
     `banner: AppError?`.
   - `onAppear()` does cache-first then remote; `refresh()` does remote.
   - Cancellation checked in every catch. Long work held in a `Task` handle and
     cancelled before replacement.

6. **`Features/<Name>/UI/<Name>ListView.swift`** and editor view
   - `@StateObject` initialised through `_viewModel = StateObject(wrappedValue:)`.
   - Content inside `LoadStateView`; `.task`, `.refreshable`.
   - Accessibility labels on icon-only controls.

7. **View-model tests** — success, failure with existing content, failure with no
   content, cancellation ignored, each mutation and its rollback.

8. **Register in `AppEnvironment`**
   - Construct the repository beside `widgetRepository`, expose it as a `let`, and
     call `syncCoordinator.register(...)` only if it queues writes.

## Verification

Before reporting done, check each of these and say which you verified:

- [ ] No iOS 17+ API used anywhere in the new files.
- [ ] `Core` gained no reference to the new feature's types.
- [ ] The view model imports no `URLSession`, `Endpoint` or `CacheStore`.
- [ ] Every catch block checks `error.isCancellation`.
- [ ] No `print`, no force-unwrap, no `try!`.
- [ ] Sample and test data is obviously invented — no client names, no real
      addresses, no personal data.
- [ ] Tests exist for each offline path the feature claims to support.
- [ ] `project.pbxproj` untouched — new files and folders need no project
      change (synchronised folder groups).
- [ ] Remind the user that this code needs human review, a passing test run and a
      clean SAST scan before commit.
