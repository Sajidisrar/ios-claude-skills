---
name: ios-combine-patterns
description: Work with Combine publishers and subscribers in a codebase that predates or mixes with Swift Concurrency — deciding when to bridge Combine into async/await, when to leave it alone, and avoiding Combine-specific retain-cycle and threading traps. Use when asked to fix a Combine subscription leak, bridge a Combine publisher into an async context, review Combine code, or decide whether new code should use Combine or async/await.
---

# Work with Combine

Combine predates Swift Concurrency and most new code in this codebase should use `async`/`await` and `AsyncSequence` instead (see `ios-concurrency-audit` for the project's concurrency conventions). This skill is for the Combine code that already exists, and the specific cases where Combine still earns its place.

## 1. New code: default to async/await, not Combine

Combine is still the right tool for a small set of cases async/await doesn't cover as cleanly:

- A value that needs multiple independent subscribers receiving every update (`@Published`/`CurrentValueSubject` fan-out) — `AsyncSequence` is naturally single-consumer per iteration unless you build a broadcast wrapper yourself.
- Declarative operator chains over a continuous stream (`debounce`, `combineLatest`, `removeDuplicates`) where the equivalent `AsyncSequence` adaptation either doesn't exist in the standard library or is noticeably more code.
- Bridging to an existing KVO-based or delegate-based system that only exposes a Combine publisher already (some older AppKit/UIKit and system framework APIs).

Everything else — a one-shot async operation, sequential async work, a single subscriber reacting to a single stream — reads more plainly as `async`/`await` or `for await` over an `AsyncStream`, and gets this project's existing cancellation/actor-isolation discipline for free instead of needing its own.

## 2. Bridging Combine into async/await

```swift
// A Combine publisher you don't control (e.g. from a system framework)
// consumed once, async-style:
let value = try await publisher.values.first { _ in true }

// Or, for a publisher you want to turn into an AsyncSequence for `for await`:
for await value in publisher.values {
    // runs once per emission; the loop ends when the publisher completes
}
```

`Publisher.values` (a `AsyncPublisher`) is the standard bridge — it exists specifically so Combine-based APIs can be consumed from async code without hand-rolling a continuation. Reach for it before writing a custom `withCheckedContinuation` wrapper around a publisher; that's solving an already-solved problem and is easy to get wrong (forgetting to handle multiple emissions, or the publisher completing with a failure).

Going the other direction — exposing an `async` function's result as a Combine publisher for an old subscriber that hasn't migrated yet — is a one-time bridge while that caller migrates, not a pattern to build new call sites around:

```swift
func publisher(for id: String) -> AnyPublisher<Widget, Error> {
    Future { promise in
        Task {
            do { promise(.success(try await repository.detail(id: id, policy: .cacheFirst(maxAge: 60)))) }
            catch { promise(.failure(error)) }
        }
    }.eraseToAnyPublisher()
}
```

## 3. Retain cycles Combine is specifically prone to

- **`sink` capturing `self` strongly.** `.sink { [weak self] value in ... }` is the default, not an occasional precaution — a `Cancellable` stored as a property on the same object it captures strongly will keep both alive for as long as the subscription lives, which for a `@Published` property subscribed in `init` is "forever."
- **`Set<AnyCancellable>` never cleared.** Cancellables stored in a `Set` on a view model live as long as the view model unless explicitly cancelled or the set is deallocated with it — usually fine if the subscribing object's lifetime is what should bound the subscription, a bug if something shorter-lived (a single screen's one-time load) subscribes into a longer-lived object's set.
- **Nested `sink`s.** Subscribing inside another subscription's closure without storing/cancelling the inner one creates a new subscription every time the outer one fires, silently multiplying work.

## 4. Threading

Combine publishers don't run on any particular queue/actor by default — an upstream publisher can deliver on a background thread, and `@Published` properties on a `@MainActor` view model still need `.receive(on: DispatchQueue.main)` (or `.receive(on: RunLoop.main)`) before the `sink` that writes to them, or Combine's lack of actor-isolation awareness will let a background-thread write through to main-actor state. The compiler won't catch this the way it catches an isolation violation in plain Swift Concurrency code — it's a Combine-specific footgun that `ios-concurrency-audit`'s automated-checking assumptions don't cover, so it needs an explicit manual check in review.

## 5. Testing Combine code

- Collect emissions synchronously where possible rather than sleeping: subscribe, trigger the action, then assert on an array the `sink` appended to — don't use `XCTestExpectation`/`Task.sleep` to "wait and see" what arrived.
- A publisher under test that never completes (e.g. a `@Published` property's publisher) needs an explicit cancel at the end of the test, or the subscription outlives the test case.

## Verification

- [ ] New code defaults to async/await; Combine is used only where §1's cases actually apply, and the reason is stated if it's not obvious.
- [ ] Every `sink` that captures `self` uses `[weak self]` unless the subscribing object's lifetime is deliberately meant to bound the subscription.
- [ ] Any `@Published` write reachable from a non-main-actor-isolated publisher chain has an explicit `.receive(on:)` before it.
- [ ] No nested `sink` creates a new subscription per emission without being cancelled.
- [ ] Tests assert on collected emissions, not on a sleep-and-hope timing assumption.
