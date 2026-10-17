---
name: ios-swift6-concurrency-migration
description: Migrate a Swift codebase or module to Swift 6 language mode (complete concurrency checking) — resolving Sendable and actor-isolation compiler errors, sequencing an incremental per-module rollout, and deciding where @preconcurrency is a legitimate bridge versus a workaround. Use when asked to upgrade to Swift 6, enable strict/complete concurrency checking, fix a wave of new Sendable or actor-isolation errors after an Xcode/toolchain upgrade, or adopt Swift 6 one module at a time.
---

# Migrate to Swift 6 concurrency

Swift 6 language mode doesn't add new concurrency rules — it makes the checks that already exist (actor isolation, `Sendable`) compile *errors* instead of warnings, and closes a few inference gaps that let unsafe code through under Swift 5. The migration is almost entirely about satisfying checks the compiler could already describe to you under Swift 5 with strict concurrency warnings turned up; Swift 6 mode just stops it from being optional.

This pairs with `ios-concurrency-audit`: that skill judges whether concurrency code is *correct*; this one is about the specific project of getting a module to compile cleanly under Swift 6's complete checking, module by module.

## 1. Don't jump straight to language mode 6

Flipping `SWIFT_VERSION` to `6` (Xcode) or a target's Swift tools version without first seeing the errors as *warnings* means discovering every problem at once, at a point where the build no longer compiles. Do this instead, per module/target:

1. Stay on Swift 5 language mode. Set the build setting `SWIFT_STRICT_CONCURRENCY = complete` (Xcode) — or for a Swift package target, add `swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]` in `Package.swift` — so every Swift 6 concurrency diagnostic appears as a **warning**.
2. Fix the warnings for that one module.
3. Only then flip that module's language mode to 6: the Xcode build setting `SWIFT_VERSION = 6` scoped to that target, or `swiftLanguageMode(.v6)` in the target's `swiftSettings` for a Swift package (SwiftPM tools version 6.0+).

Per-target scoping is what makes an incremental rollout possible at all — a Swift package's targets can each sit at a different language mode simultaneously; an Xcode project can override `SWIFT_VERSION` per target too. Once a target is in Swift 6 mode, `SWIFT_STRICT_CONCURRENCY` no longer has anything to tune — complete checking is simply how Swift 6 mode works, not an opt-in level anymore.

## 2. Migration order

Start from the leaves and work up: a module with no internal dependencies on your other modules migrates without anything upstream also needing to move. In this codebase's layering, that usually means:

1. `Core` utilities with no UI and no shared mutable state first.
2. `Core/Networking`, `Core/Auth`, `CacheStore`, `Outbox` — these already lean on `actor` for shared state, so they're often closer to compliant than they look; the main work is making their public API surface `Sendable`-correct for every caller.
3. Feature repositories — depend on the above, so they go once those are clean.
4. View models and views last — already `@MainActor`, usually the smallest diff.

Migrating in the other direction (UI first) means re-doing the same fixes once the layer underneath it changes shape.

## 3. The diagnostics you'll actually see, and the real fix

| Diagnostic shape | What it means | Fix |
|---|---|---|
| "Capture of 'x' with non-sendable type '...' in a '@Sendable' closure" | A closure crossing an isolation boundary (e.g. into `Task { }`, a completion handler, an actor method) captures something that isn't provably safe to share | Make the captured type `Sendable` (value type, or an immutable/final class with only `Sendable` stored properties), or don't capture it — pass a `Sendable` snapshot instead |
| "Property 'x' isolated to actor '...' can not be referenced from a non-isolated context" | Code outside the actor touches actor-isolated state directly | `await` a method on the actor instead of reaching into its state; don't add `nonisolated` to make the error disappear unless that property genuinely doesn't need isolation |
| "Call to main actor-isolated instance method in a synchronous nonisolated context" | A `@MainActor` type's method is being called from code the compiler can't prove is already on the main actor | Mark the caller `async` and `await` the call, or mark the caller `@MainActor` too if it only ever runs on the main actor anyway |
| "Type '...' does not conform to the 'Sendable' protocol" on a protocol requirement | A protocol (often from a dependency) declares a requirement whose isolation doesn't match your conforming type | If the protocol's own module is still Swift 5-only, `@preconcurrency import ThatModule` (see §4) suppresses diagnostics about the *module's* unaudited API — but an isolation mismatch on *your type's conformance* to that protocol needs `@preconcurrency` on the conformance clause itself, not the import: `final class Foo: @preconcurrency SomeProtocol { ... }`. If it's your own protocol, give the requirement the right isolation instead of suppressing the warning either way |
| "Stored property '...' of 'Sendable'-conforming class '...' has non-sendable type" | A class marked (or inferred) `Sendable` holds a mutable or non-`Sendable` property | Make the property `let` and `Sendable`, move the mutable state behind an `actor`, or stop claiming `Sendable` on that class |

## 4. `@preconcurrency` — a bridge, not an escape hatch

`@preconcurrency import Foo` suppresses Swift 6 concurrency diagnostics that originate from `Foo`'s own not-yet-concurrency-safe API, without weakening checking on *your* code. Legitimate use: a third-party dependency hasn't shipped its own Swift 6 audit yet, and you need to keep moving. Not legitimate: using it on your own module's imports to make your own unresolved warnings disappear — that's `ios-dependency-assessment`-territory thinking applied to your own code, which it isn't meant for.

Same discipline applies to `@unchecked Sendable` and the newer `nonisolated(unsafe)` attribute (an escape hatch for a single property rather than a whole type): each one needs a comment saying *why* it's actually safe, not just that it made the error go away. If you can't write that comment honestly, the design is wrong, not the annotation.

## 5. Validate per module, not just "it compiles"

- Build that target/module specifically under its new language mode — don't rely on the whole project building (other still-Swift-5 targets hide nothing).
- Run Thread Sanitizer on the migrated module's test suite; Swift 6 mode catches compile-time issues, not runtime races that were already latent.
- Re-run `ios-concurrency-audit`'s checklist on the module once it compiles under Swift 6 — a clean compile under complete checking doesn't by itself prove re-entrancy or single-flight invariants hold; the compiler enforces isolation, not business logic.

## Verification

- [ ] Migrated module(s) build under Swift 6 language mode (`SWIFT_VERSION = 6` / `swiftLanguageMode(.v6)`), not just under `SWIFT_STRICT_CONCURRENCY = complete` on Swift 5.
- [ ] Every new `@preconcurrency import`, `@unchecked Sendable`, or `nonisolated(unsafe)` introduced during the migration has a comment explaining why it's actually safe.
- [ ] No diagnostic was silenced by adding `@MainActor` or `nonisolated` to code the author didn't actually reason about — each isolation change matches the type's real threading model.
- [ ] Existing tests for the migrated module(s) still pass; concurrency-sensitive tests (single-flight, cancellation) re-run clean.
- [ ] Migration proceeded leaf-modules-first; nothing downstream was migrated before what it depends on.
- [ ] Still-unmigrated modules are listed explicitly in the summary, not silently left for "later."
