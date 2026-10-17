---
name: ios-accessibility-audit
description: Audit or fix accessibility in this iOS app — VoiceOver labels and grouping, Dynamic Type, contrast, hit targets, motion and focus order. Use when asked to check or improve accessibility, support VoiceOver or larger text, meet WCAG or public-sector requirements, or review a screen before release. Also use when adding any screen that will be used in the field.
---

# Audit accessibility

Treat this as a functional requirement, not a polish pass. For public-sector and
regulated clients it is contractual, and it is far cheaper to get right while the
screen is being written.

## VoiceOver

- Every icon-only control has `.accessibilityLabel` — a verb phrase, not the icon
  name: "Add job", not "plus".
- Composite rows use `.accessibilityElement(children: .combine)` so a row is one
  swipe, not five. Check the combined announcement reads as a sentence and puts
  the important part first.
- Decorative images are hidden: `.accessibilityHidden(true)`.
- Status conveyed by a chip or colour also has text in the announcement — a
  `StatusChip` with "In progress" is fine, a coloured dot is not.
- Custom controls declare `.accessibilityAddTraits(.isButton)` and respond to
  activation.
- Swipe actions are unreachable by VoiceOver alone: anything destructive or
  important available only as a swipe needs an equivalent in a menu or the detail
  screen.
- Loading and error states announce themselves. `ProgressView` has a label;
  a newly shown `ErrorBanner` should be announced rather than appearing silently.

## Dynamic Type

- No fixed `frame(height:)` on anything containing text; constrain width, let
  height grow.
- `lineLimit` used deliberately, with `.minimumScaleFactor` only where truncation
  would lose meaning.
- Test at the largest accessibility size. Rows that hold a title, a chip and a
  date on one line will need to reflow — use `ViewThatFits` or check
  `@Environment(\.dynamicTypeSize)` and stack vertically above
  `.accessibility1`.
- Never disable Dynamic Type with `.font(.system(size:))` and a hard number.

## Colour and contrast

- 4.5:1 for body text, 3:1 for large text and meaningful icons. Check both light
  and dark appearance.
- Never encode meaning in colour alone — pair it with text or a shape.
- Use semantic colours (`.primary`, `.secondary`, `Color(.systemBackground)`) so
  Increase Contrast and dark mode are handled for free.
- Check with Differentiate Without Colour and Increase Contrast enabled.

## Interaction

- Hit targets at least 44×44 points. A `Button` wrapping a small `Image` needs
  padding, not a smaller icon.
- Nothing depends on a gesture with no alternative (long press, drag, shake).
- `.accessibilityReduceMotion` respected for anything that moves more than a
  fade.
- Focus order follows reading order; `@FocusState` moves sensibly through forms,
  and `submitLabel` matches what the field actually does.

## Content

- Sentence case, British English, no jargon in error messages.
- Field labels are visible, not placeholder-only — a placeholder disappears the
  moment someone types.
- Error text says what to do next, not just what went wrong.

## How to check

1. Enable VoiceOver on a device and traverse the screen with swipes only. If you
   cannot complete the primary task, it fails.
2. Set the largest accessibility text size in Settings → Accessibility → Display &
   Text Size and look for clipping and overlap.
3. Turn on Increase Contrast, Reduce Motion, Differentiate Without Colour.
4. Xcode's Accessibility Inspector audit on each screen — it catches unlabelled
   elements and contrast failures quickly, but it does not catch a nonsensical
   announcement, so do step 1 as well.

## Verification

- [ ] Every icon-only control labelled.
- [ ] Rows combine and read sensibly.
- [ ] Primary task completable with VoiceOver alone.
- [ ] Layout intact at the largest accessibility text size.
- [ ] No meaning carried by colour alone; contrast checked in both appearances.
- [ ] Hit targets 44×44 or larger.
- [ ] Loading, empty, error and offline states all accessible — they are easy to
      forget because they are rarely on screen while you work.
- [ ] Findings listed with file, the specific control, and the fix.
