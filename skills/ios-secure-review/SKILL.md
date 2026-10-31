---
name: ios-secure-review
description: Review a change in this iOS codebase before it is committed — architecture rules, iOS 16 compliance, error handling, secure coding and an AI-code review gate. Use when asked to review code, check a diff, sanity-check a change before a pull request, or confirm something is ready to commit. Also use after generating a substantial amount of code, to check it against the project's own rules.
---

# Review a change

A structured review against this project's rules. Report findings as a short
list, most serious first, each naming the file and the rule. Do not restate what
is fine at length.

## 1. Architecture

- [ ] Dependency direction holds: `App → Features → Core`. Does `Core` reference
      any feature type? Does one feature reference another?
- [ ] `URLSession` appears only in `Core/Networking`.
- [ ] Tokens and Keychain access appear only in `Core/Auth`.
- [ ] `CacheStore` and `Outbox` are touched only by repositories.
- [ ] View models depend on repository *protocols*, not concrete types.
- [ ] Views hold no business logic, no data access, no formatting rules that
      belong in a view model.
- [ ] Concrete types are named only in `AppEnvironment`. No new singletons.

## 2. iOS 16 compliance

- [ ] No iOS 17+ API: `@Observable`, `ContentUnavailableView`,
      `onChange(of:initial:)`, `SwiftData`, `.scrollTargetBehavior`.
- [ ] Anything recent is either available on 16 or properly gated.

## 3. Concurrency

- [ ] View models and views are `@MainActor`; published state mutates nowhere
      else.
- [ ] Shared mutable state lives in an `actor`, not behind an ad-hoc lock.
- [ ] No Combine, no completion handlers, no `DispatchQueue` in feature code.
- [ ] Long-running work is held in a `Task` handle and cancelled before being
      replaced.
- [ ] No unstructured `Task { }` that outlives the view that started it without a
      reason.

## 4. Error handling

- [ ] Every catch checks `error.isCancellation` before surfacing anything.
- [ ] User-visible failures go through `AppError`; no status code, stack trace or
      raw server string reaches a view.
- [ ] A failed refresh does not blank out content the user was reading.
- [ ] Errors are not swallowed: no empty `catch { }`, no `try?` where the failure
      matters.
- [ ] New error copy is British English, sentence case, blames nobody, and lives
      in `AppError.from(_:)`.

## 5. Secure coding

- [ ] No secret, token, password, API key or `.env` value in code, xcconfig,
      Info.plist, fixtures or comments. Anything in the bundle is readable —
      treat it as public.
- [ ] No credential, token, personal data or full request/response body written to
      a log. No `print` anywhere.
- [ ] Keychain items use an appropriate accessibility class and are not
      backup-eligible.
- [ ] Input validated before use; the server's verdict still wins.
- [ ] Personal data does not outlive the session unless that is a stated,
      documented decision (see `docs/SECURITY.md`).
- [ ] No force-unwrapping, `try!` or `as!` outside tests.
- [ ] Transport is HTTPS only; no ATS exception has crept into Info.plist.
- [ ] New dependency? It needs a supplier assessment, not a convenience argument.

## 6. Data handling

- [ ] No real client name, production identifier, personal data or client source
      material in code, sample data, fixtures or test names.
- [ ] Sample data is obviously invented.

## 7. Tests

- [ ] New behaviour has tests, including its failure paths.
- [ ] Tests assert rules, not incidental values, and do not rely on timing.
- [ ] A bug fix has a regression test that would have caught it.

## 8. The gate

Say this plainly in the summary rather than implying it:

> This change is not ready to commit until a named human has reviewed it, the
> test suite passes, and SAST runs clean. AI-generated code is untrusted by
> default under this project's AI-code policy.

If the change touches authentication, storage, transport or logging, say that a
second reviewer is required.

## Reporting

For each finding: file and line, the rule it breaks, the concrete consequence,
and the smallest fix. Separate "must fix before commit" from "worth doing". If
you find nothing, say so in one line — do not pad the review.

## Verification

- [ ] Every section 1–7 was checked against the actual diff, not assumed; sections that
      don't apply are named as not applicable.
- [ ] Each finding has file and line, the rule, the consequence and the smallest fix.
- [ ] "Must fix before commit" is separated from "worth doing".
- [ ] The gate statement from section 8 appears in the summary, plus the second-reviewer
      note if authentication, storage, transport or logging changed.
