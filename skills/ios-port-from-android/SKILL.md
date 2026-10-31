---
name: ios-port-from-android
description: Port an existing Android app (Kotlin/Jetpack Compose/Views) to a native iOS app (Swift/SwiftUI) — inventory the Android app, map each feature and Google/Android service to its iOS equivalent, flag what has no direct equivalent or is restricted by App Review, and rebuild in vertical slices with a parity checklist. Use when asked to bring an Android app to iOS, estimate an iOS port, or find the iOS equivalent of an Android API or pattern.
---

# Port an Android app to iOS

A port is a **re-implementation of behaviour**, not a translation of code. Match what the
user can do and what the app guarantees (offline behaviour, security, data model); let
the UI follow Apple's Human Interface Guidelines rather than copying Material layouts.

Direction matters: the mirror skill `ios-port-to-android` covers iOS → Android.

## 0. Decide the approach first

Ask, and record the answer in the project's decision log:
- **Native Swift/SwiftUI rewrite** (this skill's default).
- **Share code** — e.g. Kotlin Multiplatform for domain/data layers consumed from Swift. If
  the team wants this, the port plan changes (shared modules first); confirm before starting.
- iOS deployment target, devices (iPhone only? iPad?), and whether the Android app keeps
  evolving during the port (if so, freeze a reference commit).

Then apply the project's other skills as normal: `ios-feature-module` for each feature,
`ios-swiftui-screen` for screens, `ios-unit-tests` for tests.

## 1. Inventory the Android app

Produce a table before writing any Swift. One row per item:

- **Screens and flows** — every screen/destination, its states, how you reach it
  (bottom nav, navigation graph, dialog, deep link), and what the system back button does.
- **Platform services** — every permission in `AndroidManifest.xml`, services, broadcast
  receivers, WorkManager jobs, widgets, intent filters, content providers.
- **Third-party SDKs** — and whether each has an iOS SDK (Swift Package preferred).
- **Backend contract** — endpoints, auth flow, push payloads. Keep the API the same;
  differences found here are backend items, not iOS workarounds.
- **Data at rest** — Room, DataStore/SharedPreferences, files, Keystore-protected data.

## 2. Map each item

Use this as the starting point and **check each row against Apple's documentation**
(developer.apple.com) before relying on it.

| Android | iOS | Watch out for |
|---|---|---|
| Jetpack Compose / Views | SwiftUI / UIKit | Respect the project's deployment target when picking APIs |
| Navigation Compose, bottom nav, dialogs | `NavigationStack`, `TabView`, sheets/alerts | No system back button: every pushed screen needs swipe-back and a visible way out |
| `ViewModel` + `StateFlow` | `@Observable` (iOS 17+) or `ObservableObject` view model | Pick the observation model the deployment target allows |
| Coroutines, `viewModelScope`, dispatchers | async/await, `Task`, actors, `@MainActor` | Cancel work in `.task {}` rather than tying it to a scope object |
| Kotlin `Flow` | `AsyncSequence` / `AsyncStream`, or Combine where the project uses it | — |
| Retrofit/OkHttp/Ktor + serialization | `URLSession` + `Codable` | Keep the same JSON field names and error shapes |
| Room | SwiftData (iOS 17+) or Core Data | Plan schema versioning from v1 |
| DataStore / SharedPreferences | `UserDefaults` (non-sensitive only) | — |
| Keystore / encrypted storage | Keychain | Choose the accessibility class deliberately |
| WorkManager | `BackgroundTasks` (`BGAppRefreshTask`, `BGProcessingTask`) | iOS schedules at its discretion; **long-running background services are not allowed** — redesign them |
| Foreground services | No general equivalent | Only specific background modes exist (audio, location, VoIP…); each needs justification at review |
| FCM | APNs (FCM can relay to APNs) | Request notification permission in context |
| Google Play Billing | StoreKit 2 | Digital goods generally must use In-App Purchase — check App Review guideline 3.1 |
| Android App Links / `assetlinks.json` | Universal Links / `apple-app-site-association` | Needs the Associated Domains entitlement |
| App Widgets / Glance | WidgetKit | Widgets are timeline-based and not interactive beyond App Intents buttons/toggles |
| Ongoing/progress notifications | Live Activities (ActivityKit) | — |
| Intents to other apps, share sheet | `ShareLink` / `UIActivityViewController`, URL schemes | Much less inter-app access than Android; check each case |
| Google Sign-In / Credential Manager | Sign in with Apple, AuthenticationServices | Third-party login may require offering Sign in with Apple or an equivalent — check guideline 4.8 |
| Manifest permissions + runtime requests | `Info.plist` usage strings + system prompts | Missing usage string = crash on access |
| Play Data safety form | Privacy manifest + App Privacy labels | See `ios-privacy-compliance` |
| `strings.xml`, `plurals` | String Catalogs | — |
| `sp` scaling, TalkBack, `semantics` | Dynamic Type, VoiceOver, accessibility modifiers | See `ios-accessibility-audit` |
| JUnit, Compose UI tests | Swift Testing / XCTest, XCUITest | Port the test *cases*, not the test code |
| Gradle | Swift Package Manager / Xcode project | — |
| Material Symbols, Roboto | SF Symbols, system font | Use the platform's own; don't ship Material's look as-is |

Anything without a clear equivalent — or that App Review would reject — goes on a **gap
list** with a proposed alternative and an owner (design, product or backend). Don't
silently drop a feature.

## 3. Build in vertical slices

1. Foundation: project setup, composition root, networking client, auth/session, error
   model, design tokens.
2. Then one feature at a time, end to end (data → view model → screen → tests), in the
   order users need them — usually sign-in, then the main list/detail.
3. For each slice, port the Android tests' **cases** as Swift tests first, so behaviour
   parity is checked, not assumed.
4. Keep the backend contract unchanged. If iOS needs something the API lacks, raise it.

## 4. Parity check

Per feature, compare against the Android reference build: same data, same states, same
errors, same offline behaviour, same analytics events (if any). Record each as **matches**,
**differs by design** (iOS convention — say which), or **gap**.

## Verification

- [ ] The approach (native vs shared code), deployment target and Android reference commit
      are recorded.
- [ ] Inventory covers every screen, manifest permission, service, receiver, widget and SDK.
- [ ] Every mapping used was checked against Apple's documentation.
- [ ] Background work and foreground services were redesigned for iOS limits, not ported
      literally.
- [ ] Payment and sign-in choices were checked against the current App Review Guidelines.
- [ ] Every item without an equivalent is on the gap list with an owner; none was dropped.
- [ ] Every pushed screen can be dismissed without a system back button.
- [ ] Each feature has a parity verdict, and the Android test cases exist as Swift tests.
