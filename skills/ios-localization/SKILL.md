---
name: ios-localization
description: Localize an iOS app with String Catalogs — making strings localizable in SwiftUI and UIKit, plurals and variations, formatting dates/numbers/units, right-to-left layout, adding a language, agent or machine translation with human review, XLIFF export, and checking translation coverage. Use when adding a language, making new UI text translatable, fixing untranslated or truncated strings, supporting RTL, or reviewing a change for hard-coded copy.
---

# Localization with String Catalogs

Localization is mostly done while writing code, not at the end: every user-facing string,
number and date must go through the localization system the first time it's written.

## 1. Make strings localizable

- **SwiftUI:** string literals passed to `Text`, `Button`, `Label` and similar are
  `LocalizedStringKey`s and are extracted automatically. A `String` *variable* passed to
  `Text` is **not** localized — pass a `LocalizedStringResource` or use
  `String(localized:)` where the value is built.
- **UIKit / non-view code:** `String(localized: "Order shipped", comment: "Banner after checkout")`.
- **Always add a comment** describing where the string appears. Translators (human or
  agent) see only the string and the comment.
- **Never build sentences by concatenation** (`"You have " + n + " items"`). Use
  interpolation in a single key so translators can reorder words.
- Mark strings that must stay as-is (brand names, codes) as *Don't Translate*. Since Xcode
  27, a localization comment of "do not translate" marks them automatically.

## 2. String Catalogs (`.xcstrings`)

- One `Localizable.xcstrings` per target (plus `InfoPlist.xcstrings` for permission
  strings and the app name). Xcode extracts keys from code at build time.
- **Plurals and device variations** are set per key in the catalog — never `if count == 1`
  in code. Plural categories differ by language (some have zero/one/two/few/many/other).
- **Stale keys** (no longer in code) are flagged; delete them rather than letting them pile up.

## 3. Format data, don't hard-code it

- Dates, numbers, currency, measurements, lists and names: use `FormatStyle`
  (`.formatted()`), `Measurement`, `PersonNameComponents`, and let the user's locale
  decide. Never hard-code date patterns, decimal separators or currency symbols.
- Store and send data in locale-independent form (ISO 8601, plain numbers); format only
  for display.

## 4. Layout and right-to-left

- Use leading/trailing, never left/right. SwiftUI mirrors automatically; check custom
  drawing and directional icons (use SF Symbols' RTL variants).
- Allow for text 30–50% longer than English; no fixed widths on text.
- Test with the scheme's *App Language* set to a pseudolanguage (double-length, right-to-left)
  before real translations exist.

## 5. Translate

- **Agent translation in Xcode 27:** agents can translate String Catalog strings (a feature
  or the whole project), and the catalog editor has a *Generate Translations* button.
  Xcode adds the languages and missing catalogs as needed.
- **Machine or agent translations need review** by a fluent speaker before release, at
  least for core flows, legal text, payments and error messages. Exported XLIFFs mark
  machine translations with `state-qualifier="leveraged-mt"`, so reviewers can find them.
- For external translators, export with *Product → Export Localizations* (XLIFF in an
  `.xcloc`) and import the result; don't hand-edit translations in two places.

## 6. Check coverage

- The catalog shows a completion percentage per language — every shipped language should
  be at 100% for the release.
- Run the app in each language on the smallest supported device at a large Dynamic Type
  size; look for truncation, clipped buttons and untranslated strings.
- In review (`ios-precommit`), flag any user-facing string literal that bypasses the
  localization system.

## Verification

- [ ] Every new user-facing string goes through `LocalizedStringKey`, `LocalizedStringResource`
      or `String(localized:)`, with a comment.
- [ ] No sentence concatenation; plurals handled in the catalog, not in code.
- [ ] Dates, numbers, currency and units use format styles, not hard-coded patterns.
- [ ] Layout uses leading/trailing and survives a double-length pseudolanguage and RTL.
- [ ] Machine/agent translations were reviewed by a fluent speaker for core flows.
- [ ] Every shipped language is at 100% in the catalog; stale keys removed.
- [ ] Checked in each language on a small device at a large text size.
