---
name: ios-design-fix
description: Compare an iOS/iPadOS app's screens against its design source (a prototype, Figma export or screenshots), fix the differences in SwiftUI, and verify each fix on the iPhone and iPad simulators. Use when asked to match screens to the design, fix design-comparison issues, or fix-and-verify UI bugs from a ticket tracker. Give it ticket ids, a list of screens, or a role/device scope.
---

# Compare to the design, fix, verify

One loop per item: **compare → fix → verify → record**. Finish an item before starting the
next. Never batch fixes and verify them all at the end — a failed check is cheaper to fix
while the screen is still in your head.

## Before the first run: fill in the project facts

Look for these in the project's `CLAUDE.md`, README or docs. Anything missing, ask the user
once and suggest they add it to `CLAUDE.md` so the next run doesn't need to ask.

| Fact | Example |
|---|---|
| Design source and its date | `design/prototype-2026-10-28.html`, a Figma export folder, a screenshot set |
| Superseded design sources to ignore | an older prototype or export |
| Xcode project/workspace and scheme | `App.xcodeproj`, scheme `AppDev` |
| Simulators to use | one iPhone, one iPad |
| Test accounts per role, and how the app can be launched signed in (env vars, launch args) | `TEST_EMAIL` / `TEST_PASSWORD` |
| Ticket tracker and how to read a ticket | `az boards work-item show --id N`, `gh issue view N`, Jira CLI |
| API spec URL, if screens are server-driven | `https://…/openapi.json` |
| Where evidence goes | `~/Desktop/design-verification/<date>/` |

## 0. Scope the run

- Read each ticket first. The repro steps usually name the account and data that show the
  bug — verify signed in as that account.
- **Ticket date vs design date.** A ticket raised against an older design may ask for
  something the current design dropped. Then the app is right: record it as **ready to
  resolve, by design**, quoting the current design. Don't rebuild the old behaviour.
- Group items by role × device (e.g. user/iPhone, user/iPad, admin/iPhone, admin/iPad) and
  work one group at a time, ordered by screen, so you sign in and navigate once per group.
- Work on a feature/test branch, not the main branch.

## 1. Read the design — look at it, and grep it

Record what the design says (copy, measurements, colours, states) **before** touching code.

**HTML/JS prototype:**
- Serve it, don't open it as `file://` (assets often fail to load). Add a static-server
  entry to `.claude/launch.json`, e.g.
  `{"name":"design","runtimeExecutable":"python3","runtimeArgs":["-m","http.server","8741","--directory","<design dir>"],"port":8741}`,
  then `preview_start` it in the browser pane.
- Size the window large (~1600×1200), use `find` to locate the prototype's own switches
  (role, device, orientation, dark mode), and screenshot the screen. Zoom on regions to
  read sizes.
- A built prototype is one minified bundle, so exact copy and CSS are greppable:
  ```
  D=<path>/prototype.html
  grep -oE ".{300}Exact visible copy.{900}" $D | head -2          # copy + nearby JSX
  grep -o "\._cardTitle_[a-z0-9]*_[0-9]*[^{]*{[^}]*}" $D          # one CSS-module rule
  ```
  Find the class name in the JSX (`className:X.cardTitle`), then grep its rule for padding,
  radius, font and colour. Template literals use backticks. For long matches, use a short
  `python3 -I` script with `re.finditer` and slice around the match.

**Figma export or screenshots:** open the image for the screen, device and theme in
question. Read text and measurements from the spec or annotations, not by eye, when they
exist.

If the design has no answer (no empty state, no offline label, no error copy), say so and
mark it as a design question. Don't invent one.

## 2. See the app's current state

Launch through Xcode so the user can watch and so the binary is the one you just built:
`XcodeOpenWorkspace` → `XcodeSwitchScheme` → `XcodeSwitchRunDestination` →
`DeviceInteractionStartWorkspaceSession` → `DeviceInteractionInstallAndRun` with the
sign-in env vars. Switching destination is what picks and boots the device, so don't boot
simulators by hand. To change account, also pass whatever resets the stored session;
credentials alone usually keep the old one.

Drive it with the simulator control tool (tap, swipe, type, rotate, set_keyboard,
screenshot; coordinates are in **points**, not pixels). Capture state instead of sleeping.
Then screenshot the same screen, orientation and theme as the design and list every
difference: copy, order, spacing, size, colour, missing element, wrong state.

## 3. Fix

- Follow the project's architecture and conventions from `CLAUDE.md`.
- **Fix every copy of the view.** Phone and iPad often have separate files, and shared
  components have several call sites. Grep for the screen's copy and accessibility
  identifiers and fix all of them in the same change. The most common regression is a fix
  that landed in two of four copies.
- SwiftUI checks on anything you touch:
  - A `Button` with `.buttonStyle(.plain)` and a composite label (stack with spacing,
    `.frame(maxWidth: .infinity)`, a border overlay) needs `.contentShape(Rectangle())`,
    or the empty space doesn't take taps.
  - Keep screen-owned modifiers (`.toolbar`, `.alert`, `.sheet`, `.navigationTitle`) out of
    reusable views. Each instance adds its own copy.
  - An `ObservableObject` held in `@State` isn't observed, and iOS 16 has no `@Observable`.
    Use `@StateObject`, or `.onReceive(vm.$prop)`.
  - The keyboard shrinks `GeometryReader`. Measure orientation under
    `.ignoresSafeArea(.keyboard)`. On iPad split panes the pane may not shrink at all, so
    add keyboard-height scroll room and `scrollTo(id, anchor: .top)`.
- If the screen is wrong because the **API** is wrong or missing a field, check the API
  spec and report it as a backend item. Never fake data to make the design appear.
- Build until green. Don't run the whole test suite unless the user asks.

## 4. Verify on the simulator

Reinstall, reach the screen again, screenshot it next to the design. **iPhone and iPad are
separate verdicts.** A verdict reached on one device doesn't cover the other. Check dark
mode if colours changed.

If the screen needs data the test accounts don't have (an empty state, an overdue item,
many records), look for a qualifying account with read-only API calls first. Anything that
creates server data needs the user's go-ahead, and gets undone or listed as a leftover.

Save `<item>-design.png`, `<item>-before.png`, `<item>-after.png` in the evidence folder.

## 5. Commit and record

One commit per ticket or screen, with a short imperative summary that names the ticket id.
Commit only when the user has asked for commits. Update the project's change log if it
keeps one.

## 6. Report

Per item, one of:

- **Fixed and verified**: what changed, on which device(s), screenshot paths.
- **Fixed, not verified**: why it couldn't be reached (data, offline device, keyboard).
- **Ready to resolve, by design**: the ticket predates the current design. Quote the
  design.
- **Blocked**: backend (endpoint and missing field), a design decision, or test data. Say
  exactly what's needed.

For a shareable report, build one self-contained HTML file (screenshots embedded as `data:`
URIs) with design / before / after per item. It can then be sent as a single file. Write a
suggested tracker comment per ticket. Change ticket states, hours or comments only when the
user asks.

## When a run looks stuck

- **Session refused as "not supported for Device Interaction":** the active destination
  is a physical device, or the scheme switch reset it. Switch the destination again and
  read back the active destination title.
- **App vanished from one simulator when the other launched:** relaunch it from the home
  screen icon, or reinstall.
- **Typed text didn't stick or reset the form:** that may be a real app bug. Note it, and
  use env-var sign-in to get past it.
- **Waiting on something:** poll the screen in one blocking call. Ending the turn with
  "I'll wait" stops the run.

## Verification

- [ ] The design was read and recorded (copy, measurements, colours, states) before any
      code changed, and design questions are marked as questions rather than invented.
- [ ] Every copy of each fixed view was found and changed, not just the first one.
- [ ] No data was faked to make the design appear. API gaps are reported as backend items.
- [ ] Each item has separate iPhone and iPad verdicts, from a fresh build of the fix.
- [ ] Dark mode was checked wherever colours changed.
- [ ] Design, before and after screenshots are saved for every fixed item.
- [ ] Any server data created for testing had the user's go-ahead, and was either undone
      or listed as a leftover.
- [ ] Every item is reported as one of: fixed and verified, fixed but not verified, ready to
      resolve by design, or blocked.
