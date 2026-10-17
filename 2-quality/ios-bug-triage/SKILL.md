---
name: ios-bug-triage
description: Diagnose and fix a bug or crash in this iOS codebase methodically — reproduce it, write the failing test first, fix the cause rather than the symptom. Use when given a crash log, a stack trace, a bug report, a "this screen sometimes shows nothing" complaint, a flaky test, or any report that the app misbehaves. Also use when asked why something is not working.
---

# Diagnose and fix a bug

The rule that makes this reliable: **do not change code until you can describe
the failing sequence in one sentence.** A fix applied to a symptom you have not
located moves the bug rather than removing it.

## 1. Establish the failure

Gather, and state back:

- What the user did, what happened, what should have happened.
- Which build (Debug or Release), which environment, which iOS version.
- Was the device offline, or on a poor connection? Was the session near expiry?
  These two conditions cause most of the odd behaviour in this app.
- Is it every time, or intermittent? Intermittent almost always means
  concurrency, cancellation, or an expiring token.

## 2. Locate the layer before reading code

Use the architecture to narrow it down:

| Symptom | Look first at |
| --- | --- |
| Wrong or stale data on screen | Repository read policy, cache invalidation after writes |
| Screen stuck on a spinner | A `LoadState` never leaving `.loading` — usually an early `return` in a catch, often the cancellation guard |
| Content disappears on refresh | View model replacing state with `.failed` instead of keeping content and setting `banner` |
| Signed out at random | Token refresh — check for more than one refresh in flight, or a rejected refresh token |
| A write vanishes | Outbox: was it queued, replayed, or dropped after five attempts? |
| Duplicate records | A retried non-idempotent request, or queued work merged into more than the first page |
| Crash on a background thread | State mutated off `@MainActor`, or a `Sendable` violation |
| Nothing shown for a real error | `AppError.from` mapping, or a swallowed `try?` |

Search for the mechanism, not the message:
`Grep` for the endpoint path, the cache key prefix, the outbox kind, or the
`LoadState` assignment in the suspect view model.

## 3. Reproduce it in a test

Write the failing test **before** the fix, in the layer where the bug lives —
this is the step that stops it coming back:

- Wrong data or cache behaviour → repository test with `StubAPIClient` and
  `InMemoryCacheStore`.
- Stuck spinner, lost content, missing error → view-model test with
  `StubWidgetRepository`.
- Auth oddity → `AuthSessionStore` test with `SpyAuthenticationAPI`
  (`setRefreshDelay` creates the overlap that exposes races).
- Retry, status mapping, refresh-and-retry → `LiveAPIClient` over
  `StubHTTPSession`.

Run it and confirm it fails for the reason you predicted. If it passes, your
theory is wrong — go back to step 2 rather than adjusting the test.

## 4. Fix the cause

- Fix it in the layer that owns the concern. A repository bug is not fixed in a
  view.
- Do not add a defensive check somewhere else to mask it.
- If the fix reveals that the design was wrong, say so and propose the change
  rather than working around it.
- If the bug came from an ambiguous requirement (what should this screen show
  when the cached data is two days old?), ask — that is a product decision.

## 5. Check the neighbours

The same mistake is usually in more than one place. If a view model forgot the
cancellation guard, `Grep` for `catch {` across the features and check them all.

## Verification

- [ ] The failing test now passes, and it failed before the fix for the right
      reason.
- [ ] The fix is in the layer that owns the concern.
- [ ] Nothing was made "defensive" elsewhere to compensate.
- [ ] Sibling occurrences of the same mistake were checked.
- [ ] No debugging leftovers: no `print`, no commented-out code, no temporarily
      relaxed lint rule.
- [ ] The summary names the root cause in one sentence, not just the fix.
- [ ] Human review, passing tests and a clean SAST run are still required before
      commit.
