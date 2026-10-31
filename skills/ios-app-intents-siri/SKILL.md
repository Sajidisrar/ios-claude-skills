---
name: ios-app-intents-siri
description: Expose an iOS app's content and actions to Siri, Spotlight, Shortcuts, widgets and Apple Intelligence through the App Intents framework — app entities, intents, assistant/semantic schemas, on-screen content (View Annotations), and testing with AppIntentsTesting. Use when adding Siri or Shortcuts support, making app content findable in Spotlight or usable by Apple Intelligence, migrating from SiriKit intents, or when an intent or entity stops compiling after an SDK update.
---

# App Intents: Siri, Spotlight and Apple Intelligence

App Intents is the one integration point the system uses to find your app's content and
perform its actions — Siri, Spotlight, Shortcuts, widgets, controls and Apple Intelligence
all read the same intents and entities. Model them once, well.

API names below are from Apple's WWDC26 iOS guide and the iOS 27 release notes. Check the
App Intents documentation for exact signatures and availability before writing code; this
area changes every release.

## 1. Decide what to expose

List the app's **nouns** (entities: an order, a note, a contact) and **verbs** (intents:
create, open, mark done). Expose what people would ask for by voice or search, not every
screen. For each, note: the identifier that stays stable, the display representation, and
which data must never leave the app (sensitive fields stay out of entities).

## 2. Model entities and intents

- **`AppEntity`** for each noun, with a stable `id`, a display representation, and an
  entity query so the system can resolve references ("my last order").
- **`AppIntent`** for each verb: parameters, a `perform()` that calls the same
  repository/use-case layer the UI uses (never duplicate business logic in an intent), and
  dialog/result values.
- **Schemas.** Where Apple defines a schema for your domain (assistant schemas; in iOS 27,
  *entity schemas* and *intent schemas*), conform to it — it lets Siri and Apple
  Intelligence understand your content without you defining phrases, and lets entities be
  added to the Spotlight semantic index with attribution. Schemas gain properties between
  releases: in iOS 27 an entity conforming to the photos asset schema stopped compiling
  until the new properties were adopted behind an availability check. Re-check schema
  conformances on every SDK upgrade (`ios-sdk-upgrade`).
- **On-screen content.** iOS 27 adds a *View Annotations* API that maps views to entities,
  so people can act on what's on screen conversationally. Annotate the screens where
  "this one" is a natural request (a detail view), not every list row.
- **SiriKit.** If the app still uses SiriKit intents, plan the move to App Intents; new
  Siri and Apple Intelligence features are built on App Intents.

## 3. Shortcuts, Spotlight and widgets

- Provide App Shortcuts for the two or three most common actions so they work with no setup.
- Index entities with Core Spotlight only for content the user would search for; update or
  delete index entries when data changes or the user signs out.
- Reuse intents for widget configuration and interactive widget/control buttons
  (`ios-widgetkit-live-activities`) rather than writing parallel logic.

## 4. Privacy and authentication

- An intent can run while the device is locked or the app isn't in the foreground. Decide
  per intent whether it needs authentication or an unlocked device, and enforce it.
- Entities you donate or index are visible to system features. Never include data the user
  would be surprised to see in Spotlight or a Siri answer. Update `ios-privacy-compliance`
  answers if new data is surfaced.

## 5. Test

- Unit-test `perform()` through the same test doubles as the rest of the app
  (`ios-unit-tests`).
- iOS 27 adds an **AppIntentsTesting** framework for validating integrations through
  system pathways without UI automation — use it for entity resolution and intent
  execution where available.
- Try each intent by voice, in Shortcuts and in Spotlight on a device, signed in and signed
  out, and with the device locked.

## Verification

- [ ] Exposed entities and intents match what users would actually ask for; sensitive data
      excluded.
- [ ] Every intent calls the app's existing use-case layer; no duplicated business logic.
- [ ] Schema conformances used where Apple defines one, and re-checked against the current
      SDK.
- [ ] Each intent's authentication/locked-device behaviour is decided and enforced.
- [ ] Spotlight index entries are updated and removed when data changes or on sign-out.
- [ ] Intents are unit-tested, and checked by voice, in Shortcuts and in Spotlight on a
      device.
- [ ] Exact API names and availability were checked against Apple's current documentation.
