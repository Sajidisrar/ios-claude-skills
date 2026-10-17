# Review checks

Apply these categories to the **changed** code (and directly relevant
surrounding code). Skip a category entirely if it has no bearing on this
diff — do not pad the report with "N/A" sections.

## Inherited vs. modified vs. new

Before flagging anything, classify the line/block:

1. **Existing/inherited** — untouched by this diff. Not in scope unless it's
   directly relevant to whether the change is safe.
2. **Modified existing** — in scope. Judge whether the modification makes it
   worse, not whether the original design was ideal.
3. **Newly introduced** — in scope, full scrutiny.
4. **New problems caused by the change** — e.g. a new caller that violates an
   existing contract, a new state that an existing switch/if-chain doesn't
   handle. In scope even though the touched file/function is "old."

A developer should never be penalized for working in a legacy codebase they
didn't choose. Objective-C, UIKit, MVC, delegates, GCD, force-unwrap-heavy
legacy modules, etc. are not findings by themselves.

## A. Correctness

- Logic errors, incorrect conditions/state transitions, wrong assumptions
- Optional/nil handling; force unwraps (`!`) and force casts (`as!`) that
  create *meaningful* crash risk in the new/changed code path
- Incorrect API usage (wrong method for the intent, misunderstood semantics,
  deprecated/removed API)
- Incorrect data transformations, off-by-one/boundary conditions
- Missing or wrong error handling on the changed path
- Concurrency: race conditions, async/await misuse, actor isolation
  violations, `Sendable` conformance gaps, main-thread violations (UI work
  off the main thread, or blocking work on it)
- SwiftUI: state/data-flow bugs (`@State`/`@Binding`/`@ObservedObject`
  misuse, view identity issues, side effects in `body`)
- UIKit: lifecycle problems (wrong load/appear/disappear ordering, missing
  `super` calls, view controller retain issues)
- Memory management: retain cycles (especially `self` capture in closures
  and delegate references that should be `weak`), over-retention

## B. Regression risk

- Does the change break existing behavior for other call sites?
- Does it alter a public/internal API contract (signature, return
  semantics, thrown errors, nullability) in a way that affects existing
  callers?
- Does it introduce state/data inconsistency (e.g. a cache or model updated
  in one place but not a related place)?
- Does it silently drop or reorder handling of an existing edge case?

When a signature or contract changes, check known callers in the repo for
compatibility — don't assume.

## C. Security (strict bar — see severity.md)

- Secrets, tokens, passwords, OTPs, API keys, or auth data hardcoded, logged,
  or newly persisted in source
- Sensitive data written to logs/console/analytics
- Insecure persistence: sensitive data in `UserDefaults`, plist, or
  unencrypted files instead of Keychain
- Keychain misuse (wrong accessibility level, missing access control)
- AuthN/AuthZ logic changes: bypass risk, missing checks, privilege issues
- Insecure networking: cleartext HTTP where HTTPS is expected, disabled
  certificate/TLS validation, ATS exceptions added without justification
- Unsafe (de)serialization of untrusted data
- Injection risk (e.g. building SQL/predicate/URL strings from unsanitized
  input)
- Accidental disclosure (verbose error messages exposing internals, debug
  flags left enabled)

Never print an actual secret value in the report. State the type ("hardcoded
API key", "logged bearer token") and its location only.

## D. Performance

Only flag *meaningful* impact — skip micro-optimizations:

- New network calls that are redundant, unbatched, or on a hot path
- Expensive work (parsing, sorting, image processing, crypto) added to the
  main thread
- Obvious new O(n²)-or-worse pattern on data that can be large
- Repeated recomputation of something that could be cached/hoisted
- New unnecessary DB/CoreData/file-system round trips in a loop
- SwiftUI: expensive work inside `body`, or state changes that force
  unnecessary full-tree re-renders

## E. Maintainability

- Unnecessary complexity introduced by the change (vs. the previous
  implementation's complexity, which is not in scope)
- Significant duplication of logic that already exists elsewhere in the
  touched area
- Naming that's actively unclear (not just "not what I'd have chosen")
- New coupling that crosses an existing architectural boundary
  (e.g. view directly reaching into persistence/network layer where the
  project otherwise routes through a service/view-model layer)
- Inconsistency with conventions clearly established elsewhere in the same
  module/file

Do not report stylistic preference as a defect. If the project has no
established convention for something, don't invent one to fault the change
against.

## F. Testing

- Does the changed behavior need a test (new logic, new edge case, bug fix
  without a regression test)?
- Does an existing test now assert the wrong thing because of this change?
- Is there an important untested failure/edge path introduced by the
  change?

Judge by risk and behavior, not by a fixed coverage percentage — never
invent or assume a coverage number. Trivial changes (renames, comments,
constant tweaks, pure formatting) do not need new tests.

## G. AI-generated code quality

When changed code looks templated, oddly verbose, or unfamiliar relative to
the surrounding style, check for (without assuming AI origin is itself a
problem):

- Calls to APIs/methods/properties that don't exist on the type (hallucinated
  API)
- Assumptions about framework behavior that are wrong for the SDK/OS version
  the project targets
- Copy-paste artifacts (leftover unrelated logic, mismatched variable names,
  dead branches)
- Logic that's unnecessarily convoluted for what it accomplishes
- Any of the correctness/security issues above — apply the same scrutiny
  regardless of suspected origin

## H. Project architecture conformance (when the project documents one)

This skill has no built-in knowledge of any specific project's architecture —
no fixed notion of layers, folder names, or patterns. A project may instead
maintain its own machine-readable conformance file, in its own repository,
generated from its own approved architecture document. Check, in order, the
first of these that exists (the second matches the `docs/DECISIONS.md` /
`docs/SECURITY.md` convention other skills in this collection assume):

```
docs/ARCHITECTURE.md
Documentation/Architecture/architecture-rules.md
```

- **If one of those files exists:** read it, then evaluate only the files already in
  the current review's scope (never the whole project) against whatever
  rules it defines — e.g. required/allowed file locations, prohibited
  dependencies between the project's own named layers, boundary rules. If
  the file distinguishes mandatory rules from structural/allowed
  alternatives, honor that distinction exactly — an alternative it marks as
  explicitly permitted is never a violation, no matter how it looks.
- **If neither file exists:** do not invent architecture rules on your
  own, do not fail or skip the rest of the review over its absence, and do
  not treat the absence itself as a defect. State plainly in the report
  that project-specific architecture conformance could not be evaluated
  because no architecture-rules file was found, then continue normally.
- A finding from this category uses the same severity levels and evidence
  format as every other category (file, line, symbol, problem, impact,
  fix) — never a separate architecture score, percentage, ranking, or
  decision system.
- Same inherited-vs-modified-vs-new discipline as the rest of this skill: a
  pre-existing architectural issue is only a finding here if the current
  change introduces it, worsens it, or depends on it in a way that makes
  the current change unsafe — not merely because it's visible nearby.

## Reusing CTO-checklist principles (not its scoring)

Where relevant to the diff, apply the *engineering intent* behind a formal
whole-project checklist as a per-change question — never as a scored rule:

| Project-level rule (elsewhere)        | Per-change question here |
|----------------------------------------|---------------------------|
| No sensitive data stored/logged        | Did this change add sensitive-data logging, storage, or exposure? |
| Architecture/SOLID followed            | Does this change add inappropriate coupling, a responsibility violation, duplication, or reduced testability? |
| Use of modern language/framework features | Does this change needlessly introduce an obsolete pattern when a suitable modern one already fits the project and deployment target? |
| Project-wide coverage target           | Does this specific change have coverage appropriate to its risk? |

Do not compute a percentage, a pass/fail table, or a category score anywhere
in this skill's output.
