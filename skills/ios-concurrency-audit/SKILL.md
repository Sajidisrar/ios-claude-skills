---
name: ios-concurrency-audit
description: Audit or fix Swift Concurrency problems in this iOS codebase — actor isolation, MainActor violations, Sendable conformance, task cancellation, single-flight work and data races. Use when a crash or warning involves threading, when state updates from the wrong thread, when something happens twice that should happen once, when adopting stricter concurrency checking, or when asked to review async code.
---

# Audit concurrency

This project uses Swift Concurrency exclusively. Build setting is
`SWIFT_STRICT_CONCURRENCY = targeted`, so the compiler does not catch everything
— the checks below are the ones a reviewer must do by hand.

## The intended model

- **`@MainActor`**: all views and view models. Published state mutates nowhere
  else, by construction.
- **`actor`**: anything owning mutable state that several tasks reach —
  `AuthSessionStore`, `FileCacheStore`, `FileOutbox`.
- **`Sendable` value types** cross boundaries. `@unchecked Sendable` appears only
  where a type is immutable in practice (`LiveAPIClient`, repositories) or is a
  lock-protected test double, and each use carries a comment saying why.
- No Combine, no completion handlers, no `DispatchQueue` in feature code.

## What to check

1. **MainActor integrity**
   - Every `ObservableObject` view model is `@MainActor`.
   - No `nonisolated` method mutates published state.
   - No `DispatchQueue.main.async` used to "fix" an isolation error — that hides
     the problem rather than solving it. (One exception exists in `LoginView` for
     a delayed notice clear; anything new needs a better reason.)

2. **Actor re-entrancy** — the subtle one. Every `await` inside an actor method is
   a suspension point at which another caller can enter and change state. So:
   - Re-read state after an `await` rather than trusting a value captured before
     it.
   - Check that "only one at a time" invariants survive interleaving. The pattern
     to copy is `AuthSessionStore.performRefresh`: store the in-flight `Task`,
     have later callers await it, clear it in both success and failure paths.
   - Ask of any new actor method: what happens if this runs twice, concurrently,
     with the second call arriving mid-`await`?

3. **Cancellation**
   - Work that a view can trigger repeatedly (search, reload, paging) is held in a
     `Task` handle and cancelled before being replaced.
   - After an `await` in a long operation, `Task.isCancelled` is checked before
     publishing results.
   - Every catch checks `error.isCancellation` and returns silently.
   - `Task.sleep` failures are treated as cancellation, not as errors to report.

4. **Task lifetime**
   - No unstructured `Task { }` that outlives the object that started it and then
     touches its state. Capture `[weak self]` in long-lived tasks.
   - Fire-and-forget tasks that perform writes are suspicious: who observes the
     failure?
   - Prefer `async let` or a task group over several detached tasks.

5. **Sendable**
   - Closures crossing isolation boundaries are `@Sendable` and capture only
     `Sendable` values (see `AuthSessionStore.setStateHandler`).
   - No reference type shared across actors without either immutability, an actor,
     or a documented lock.
   - `@unchecked Sendable` has a comment justifying it. If you cannot write the
     justification, the design is wrong.

6. **Duplicated work**
   - Anything expensive and idempotent that several callers can trigger at once
     (token refresh, outbox drain, cache warm) needs the single-flight pattern:
     an in-flight `Task` stored and shared. `SyncCoordinator.drain()` and
     `AuthSessionStore` both do this — copy them.

## Testing concurrency

Do not use sleeps to create overlap. Inject a delay into the double instead
(`SpyAuthenticationAPI.setRefreshDelay`) and drive concurrent callers with a task
group, then assert on the count:

```swift
let count = await api.refreshCount
XCTAssertEqual(count, 1, "Ten concurrent callers must cause exactly one refresh")
```

Read actor state with `await` in assertions, never by reaching into it
synchronously.

## Verification

- [ ] No published state mutated off the main actor.
- [ ] Every new actor method reasoned about for re-entrancy, in a comment where
      the answer is non-obvious.
- [ ] Repeatable work is cancelled before being replaced.
- [ ] Every `@unchecked Sendable` justified in a comment.
- [ ] Concurrency behaviour has a test that would fail if the invariant broke.
- [ ] `Thread Sanitizer` and `Main Thread Checker` were run, or say plainly that
      they were not.
