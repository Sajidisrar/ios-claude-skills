---
name: ios-unit-tests
description: Write or extend unit tests in this iOS codebase using its existing seams and test doubles — StubHTTPSession, StubAPIClient, in-memory cache and outbox, spy auth. Use when asked to add tests, improve coverage, test a repository or view model, test networking, retry, token refresh or offline behaviour, or when a bug needs a regression test before it is fixed.
---

# Write tests

## The seams

Every awkward path in this app is testable without a simulator network, a live
backend or `URLProtocol` tricks, because of four seams:

| Seam | Double | Use it to test |
| --- | --- | --- |
| `HTTPSession` | `StubHTTPSession` | Real `LiveAPIClient`: status mapping, retry, 401 refresh-and-retry, decoding failures |
| `APIClient` | `StubAPIClient` | Real repository: read policies, cache, offline queueing, replay |
| `CacheStore` / `Outbox` | `InMemoryCacheStore` / `InMemoryOutbox` | Repository behaviour with no disk |
| `<X>Repository` | `StubWidgetRepository` | Real view model: states, banners, rollbacks |
| `AuthenticationAPI` / `TokenStorage` | `SpyAuthenticationAPI` / `InMemoryTokenStorage` | Real `AuthSessionStore`: single-flight refresh, sign-out |

Extend the existing doubles rather than adding new ones. They live in
`AppTemplateTests/Support`; the in-memory app-target implementations live beside
their protocols.

## Rules

- Test **behaviour**, not implementation. "A POST is never retried
  automatically", not "the retry policy's delay function returns nil".
- Prefer the real object under test with doubles beneath it. Testing
  `LiveAPIClient` over a stub session is far more valuable than testing a mock of
  it.
- View-model test classes are `@MainActor final class ... : XCTestCase`.
- Name tests as sentences: `testFailedDeleteRestoresTheRow`.
- Assertion messages explain the *rule*, not the values:
  `XCTAssertEqual(count, 1, "Ten concurrent callers must cause exactly one refresh")`.
- No sleeps to synchronise. Await the work. Where a delay is genuinely needed to
  create overlap (the single-flight test), inject it into the double.
- Actor state is read with `await`: `let count = await api.refreshCount`.
- Never name a local variable the same as a method used in the same scope — Swift
  will not forgive it.
- Test data is invented. No client names, no real addresses, no personal data, no
  credentials — not even plausible-looking ones.

## What to cover

For a **repository**:
- each `ReadPolicy` the feature actually uses;
- cache hit avoids the network (assert on the request count, not just the result);
- offline falls back to cache and reports `.cacheWhileOffline`;
- `.remoteOnly` does *not* fall back;
- every offline write path and its replay;
- validation rejected before any request leaves the device.

For a **view model**:
- success populates state;
- failure with no content → `.failed`;
- failure with existing content → content kept plus banner;
- cancellation produces nothing visible;
- each mutation, including its rollback on failure.

For **networking**:
- one test per `APIError` case the app depends on;
- retry happens for idempotent methods and never for POST;
- 401 refreshes once, retries once, and does not loop.

## Running them

```bash
./Scripts/build.sh test development
```

or directly, naming the environment's scheme and configuration:

```bash
xcodebuild test -scheme AppTemplate-Development -configuration Debug-Development \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Tests must run on a `Debug-*` configuration: `@testable import` needs
`ENABLE_TESTABILITY`, which only the Debug flavour sets.

## Verification

- [ ] Each new test fails if the behaviour it describes is broken — check by
      reasoning through the change, or by temporarily inverting the logic.
- [ ] No test depends on wall-clock timing to pass.
- [ ] No test data resembles real client or personal data.
- [ ] Failure paths are covered, not just the happy path.
- [ ] Tests were actually run, or say plainly that they were not and why.
