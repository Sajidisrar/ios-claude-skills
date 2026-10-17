---
name: ios-swift-testing-migration
description: Adopt Apple's Swift Testing framework (@Test, @Suite, #expect, #require) alongside or instead of XCTest — converting existing XCTestCase tests, deciding what must stay on XCTest, and writing new tests in the framework that fits the behavior. Use when asked to migrate tests to Swift Testing, write a new test file, add parameterized tests, or decide whether a test belongs in Swift Testing or XCTest.
---

# Adopt Swift Testing

Swift Testing is a separate framework from XCTest, not a drop-in replacement — both can live in the same target and the same test plan. The decision isn't "migrate everything," it's "which new tests go in Swift Testing, and is the conversion of an existing test worth doing on its own."

## 1. What actually moves and what doesn't

| Capability | Swift Testing | XCTest |
|---|---|---|
| Ordinary assertions | `#expect(condition)` | `XCTAssert*` family |
| Assertion that must stop the test immediately on failure | `#require(condition)` (throws, so needs `try`) | `XCTUnwrap`, `XCTFail` + early `return` |
| Test grouping | `@Suite` struct/class, nesting allowed | `XCTestCase` subclass |
| Parameterized tests | `@Test(arguments:)` — built in | Not built in; hand-rolled loop or a third-party helper |
| Async tests | `@Test func ...() async throws` — no special setup | `func test...() async throws` — same, already supported |
| UI tests (`XCUIApplication`) | Not supported | Required — stays on XCTest |
| Performance tests (`measure {}`) | Not supported | Required — stays on XCTest |
| Objective-C test targets | Not supported (Swift-only) | Required |
| `setUp`/`tearDown` lifecycle | `init()` / `deinit` on the suite type (runs per-test, not shared) | `setUp()`/`tearDown()` methods |

If a test suite leans on any row in the right column, it stays on XCTest. A target can have both a `Tests/` folder of `XCTestCase` subclasses and a `Tests/` folder of Swift Testing suites side by side — no migration is required to start writing new tests in Swift Testing.

## 2. Converting an existing XCTestCase test

Only convert a test when you're already touching it for another reason (a bug fix, a behavior change) — a pure mechanical conversion with no other motivation is churn that makes the diff harder to review for no behavioral benefit.

```swift
// Before — XCTest
final class WidgetRepositoryTests: XCTestCase {
    func testCacheHitAvoidsNetwork() async throws {
        let api = StubAPIClient()
        let cache = InMemoryCacheStore()
        await cache.store(Widget.fixture, for: WidgetCacheKeys.detail(id: "1"))
        let repo = LiveWidgetRepository(client: api, cache: cache)

        _ = try await repo.detail(id: "1", policy: .cacheFirst(maxAge: 60))

        XCTAssertEqual(api.requestCount, 0)
    }
}

// After — Swift Testing
@Suite
struct WidgetRepositoryTests {
    @Test
    func cacheHitAvoidsNetwork() async throws {
        let api = StubAPIClient()
        let cache = InMemoryCacheStore()
        await cache.store(Widget.fixture, for: WidgetCacheKeys.detail(id: "1"))
        let repo = LiveWidgetRepository(client: api, cache: cache)

        _ = try await repo.detail(id: "1", policy: .cacheFirst(maxAge: 60))

        #expect(api.requestCount == 0)
    }
}
```

Notice what changed beyond the macros: the type became a plain `struct` (no `XCTestCase` superclass), the method lost its `test` prefix (the `@Test` attribute is what makes it a test now, not the name), and each test gets a fresh instance — there is no shared mutable state between tests in one suite unless you deliberately design for it, which also means tests that accidentally depended on run order will fail loudly instead of silently passing together.

## 3. Where Swift Testing is a genuine improvement, not just a different spelling

- **Parameterized tests** collapse what would otherwise be a loop-in-one-test or several near-duplicate test methods:

  ```swift
  @Test(arguments: [401, 403, 404, 409, 422, 500])
  func statusMapsToDistinctAppError(_ status: Int) async throws {
    let error = AppError.from(APIError.http(status: status, body: nil))
    #expect(error != .generic)
  }
  ```

  Each argument runs and reports as its own test case — one failing status doesn't hide the others, and the failure message names the exact input.

- **Tests run in parallel by default** within a suite (unless marked `.serialized`) — a suite with shared mutable state (a real file on disk, a shared `UserDefaults` suite) needs `@Suite(.serialized)` or the tests will race each other. This is a real behavior change from XCTest's default serial execution, not a style choice — audit for shared state before converting a suite wholesale.

- **`#require` vs. a chain of `XCTUnwrap`** reads more clearly for "stop here if this precondition isn't met":

  ```swift
  @Test
  func createdWidgetHasServerAssignedID() async throws {
      let created = try await repo.create(draft)
      let id = try #require(created.id)
      #expect(id.isEmpty == false)
  }
  ```

## 4. What doesn't change

- Test doubles (`StubAPIClient`, `InMemoryCacheStore`, `SpyAuthenticationAPI`, etc.) are plain Swift types — they work identically under either framework. Nothing about `ios-unit-tests`'s seam list changes.
- `@MainActor` view-model tests still need to be `@MainActor` — mark the whole suite `@Suite(.serialized) @MainActor` or the individual `@Test` functions, matching whichever XCTest did.
- CI configuration: Swift Testing tests run through the same `xcodebuild test` / `swift test` invocation as XCTest — no separate test runner or scheme setting is required.

## Verification

- [ ] Every converted test still asserts the same behavior — a conversion changed syntax, not what's being verified.
- [ ] Tests that depend on `XCUIApplication`, `measure {}`, or Objective-C stayed on XCTest; nothing was force-converted.
- [ ] Any suite with shared mutable state (real files, shared defaults, a singleton) is marked `.serialized` or was redesigned to not share state across tests.
- [ ] New parameterized tests use `@Test(arguments:)` instead of a hand-rolled loop where the inputs are genuinely independent cases.
- [ ] `@MainActor` isolation on view-model tests was preserved across the conversion.
- [ ] The test suite was actually run (not just compiled) after conversion, and the diff states that plainly.
