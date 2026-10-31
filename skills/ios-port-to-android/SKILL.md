---
name: ios-port-to-android
description: Port an existing iOS app (Swift/SwiftUI/UIKit) to a native Android app (Kotlin/Jetpack Compose) — inventory the iOS app, map each feature and Apple service to its Android equivalent, flag what has no direct equivalent, and rebuild in vertical slices with a parity checklist. Use when asked to bring an iOS app to Android, estimate an Android port, or find the Android equivalent of an iOS API or pattern.
---

# Port an iOS app to Android

A port is a **re-implementation of behaviour**, not a translation of code. Match what the
user can do and what the app guarantees (offline behaviour, security, data model); let
the UI follow Material Design and Android conventions rather than copying iOS pixels.

Direction matters: the mirror skill `ios-port-from-android` covers Android → iOS.

## 0. Decide the approach first

Ask, and record the answer in the project's decision log:
- **Native Kotlin/Compose rewrite** (this skill's default).
- **Share code** — e.g. Kotlin Multiplatform for domain/data layers. If the team wants
  this, the port plan changes (shared modules first); confirm before starting.
- Minimum Android API level, target devices (phones only? tablets, foldables?), and
  whether the iOS app keeps evolving during the port (if so, freeze a reference commit).

## 1. Inventory the iOS app

Produce a table before writing any Kotlin. One row per item:

- **Screens and flows** — every screen, its states (loading/empty/error/offline), and how
  you reach it (tab, push, sheet, deep link).
- **Platform services** — every Apple framework the app uses (grep `import`), entitlements,
  `Info.plist` usage strings and URL types, background modes, App Groups, extensions
  (widgets, notification service, share extension).
- **Third-party SDKs** — and whether each has an Android SDK.
- **Backend contract** — endpoints, auth flow, push payloads. The API should stay the same;
  differences found here are backend items, not Android workarounds.
- **Data at rest** — what's in SwiftData/Core Data, files, `UserDefaults`, Keychain, and any
  migration the Android app must never need (it starts fresh).

## 2. Map each item

Use this as the starting point and **check each row against current Android documentation**
(developer.android.com) before relying on it — versions and recommended libraries move.

| iOS | Android | Watch out for |
|---|---|---|
| SwiftUI / UIKit | Jetpack Compose / Views | Compose recomposition ≠ SwiftUI invalidation; keep state hoisted |
| `NavigationStack`, sheets, tabs | Navigation Compose, bottom sheets, `NavigationBar` | **System back** and predictive back must work on every screen |
| `@Observable` / `ObservableObject` view model | `ViewModel` + `StateFlow` | `ViewModel` survives rotation; the screen does not |
| async/await, `Task`, actors, `@MainActor` | coroutines, `suspend`, `viewModelScope`, `Dispatchers.Main` | Structured cancellation maps well; actors have no direct twin — use a `Mutex` or a single-threaded dispatcher |
| Combine | Kotlin `Flow` | Hot vs cold: `StateFlow`/`SharedFlow` vs `flow {}` |
| `URLSession` + `Codable` | OkHttp/Retrofit or Ktor + kotlinx.serialization | Keep the same JSON field names and error shapes |
| SwiftData / Core Data | Room | Write migrations from v1; Room enforces schema at compile time |
| `UserDefaults` | DataStore | DataStore is async — no synchronous reads at launch |
| Keychain | Android Keystore–backed encryption | Keystore keys can be invalidated (e.g. biometric enrolment change); handle it |
| `BackgroundTasks` | WorkManager | Android doesn't guarantee timing either; design for "eventually" |
| APNs | Firebase Cloud Messaging | Notification channels are required; runtime notification permission on newer API levels |
| StoreKit 2 | Google Play Billing Library | Server-side verification and acknowledgement rules differ — re-read Play's docs |
| Universal Links / `apple-app-site-association` | Android App Links / `assetlinks.json` | Verified links need the signing-certificate fingerprint |
| WidgetKit | Jetpack Glance / App Widgets | Update budgets and sizes differ |
| Live Activities | Ongoing notifications (newer Android versions add progress-style live updates) | No 1:1 equivalent — agree the design |
| Privacy manifest, App Privacy labels | Play **Data safety** form, manifest permissions | Same facts, different form |
| `Info.plist` usage strings | Runtime permission requests + rationale UI | Ask in context; handle "don't ask again" |
| `scenePhase` | Activity/`Lifecycle`, `SavedStateHandle` | **Process death**: restore state the user would lose |
| String Catalogs | `strings.xml`, `plurals` | Plural categories are per-language on both |
| Dynamic Type, VoiceOver | `sp` font scaling, TalkBack, Compose `semantics` | Test at the largest font scale |
| XCTest / Swift Testing | JUnit, Compose UI tests | Port the test *cases*, not the test code |
| Swift Package Manager | Gradle (version catalogs) | — |

**Licensing:** SF Symbols and the SF Pro fonts are licensed for Apple platforms only. Replace
them (e.g. Material Symbols, a licensed or open-source font) — don't bundle them on Android.

Anything without a clear equivalent goes on a **gap list** with a proposed alternative and
an owner (design, product or backend). Don't silently drop a feature.

## 3. Build in vertical slices

1. Foundation: project setup, DI, networking client, auth/session, error model, theme.
2. Then one feature at a time, end to end (data → view model → screen → tests), in the
   order users need them — usually sign-in, then the main list/detail.
3. For each slice, port the iOS tests' **cases** as Android tests first, so behaviour parity
   is checked, not assumed.
4. Keep the backend contract unchanged. If Android needs something the API lacks, raise it.

## 4. Parity check

Per feature, compare against the iOS reference build: same data, same states, same errors,
same offline behaviour, same analytics events (if any). Record each as **matches**,
**differs by design** (Android convention — say which), or **gap**.

## Verification

- [ ] The approach (native vs shared code), minimum API level and iOS reference commit are
      recorded.
- [ ] Inventory covers every screen, Apple framework, entitlement, extension and SDK.
- [ ] Every mapping used was checked against current Android documentation.
- [ ] Every item without an equivalent is on the gap list with an owner; none was dropped.
- [ ] System back, rotation and process death work on every ported screen.
- [ ] No SF Symbols or SF fonts bundled in the Android app.
- [ ] Backend contract unchanged, or differences raised as backend items.
- [ ] Each feature has a parity verdict, and the iOS test cases exist as Android tests.
