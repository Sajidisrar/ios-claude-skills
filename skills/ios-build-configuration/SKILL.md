---
name: ios-build-configuration
description: Set up and debug an iOS app's build configuration — build configurations (Debug/Staging/Release), schemes, `.xcconfig` files and build variables, per-environment API URLs, bundle IDs, app names, icons and signing — and investigate configuration-caused breakage (wrong environment in a build, settings not applied, signing or entitlement errors, Info.plist values not substituted, CI building something different from local). Use when adding an environment, adding or changing a build variable, creating a scheme, or when a build, archive or launch fails for configuration reasons.
---

# Build configuration: set it up, then debug it

The goal is one obvious place for every environment-specific value, and a build whose
environment you can prove rather than assume. Most configuration bugs are a value set in
two places, with the one you didn't edit winning.

## The model

| Piece | What it decides | Where it lives |
|---|---|---|
| **Build configuration** (Debug, Staging, Release…) | Compiler flags, optimisation, which `.xcconfig` applies | Project → Info → Configurations |
| **`.xcconfig` file** | Build settings and your own variables, as text in git | `Config/*.xcconfig`, one per configuration |
| **Scheme** | Which configuration each action (Run, Test, Archive) uses, launch arguments and environment variables | `.xcscheme` — mark it **Shared** so it's in git and CI sees it |
| **Info.plist** | Runtime values, read from build settings via `$(VARIABLE)` | Target's `Info.plist` or generated Info.plist keys |
| **Code** | Reads the runtime values once, validates them, exposes a typed config | One `AppConfiguration`-style type |

Precedence, highest first: target build settings → target `.xcconfig` → project build
settings → project `.xcconfig` → SDK defaults. A value typed into the target's Build
Settings editor silently overrides the `.xcconfig`. Keep the editor empty (bold entries
are overrides) and put everything in `.xcconfig` files.

## Setting it up

1. **Files.** A shared base plus one file per environment:
   ```
   // Config/Base.xcconfig
   PRODUCT_BUNDLE_IDENTIFIER = com.example.app$(BUNDLE_ID_SUFFIX)
   APP_DISPLAY_NAME = Example$(APP_NAME_SUFFIX)

   // Config/Environment-Staging.xcconfig
   #include "Base.xcconfig"
   BUNDLE_ID_SUFFIX = .staging
   APP_NAME_SUFFIX = β
   API_HOST = staging-api.example.com
   ENVIRONMENT_NAME = staging
   ```
   In `.xcconfig`, `//` starts a comment, so a URL like `https://host` is cut off. Store the
   host (as above) and add the scheme in code, or use the `$()` trick:
   `API_BASE_URL = https:/$()/api.example.com`.
2. **Configurations.** Duplicate Release to make Staging (Release-like optimisation, so you
   test what ships). Set each configuration's *Based on Configuration File* at project or
   target level, not both.
3. **Info.plist.** Expose only what the app needs at runtime: `API_HOST` → `$(API_HOST)`,
   `ENVIRONMENT_NAME` → `$(ENVIRONMENT_NAME)`.
4. **Code.** Read the values once at launch into a typed configuration; fail fast with a
   clear message if one is missing, unsubstituted (still contains `$(`), or insecure
   (non-https host in a release build).
5. **Schemes.** One shared scheme per environment (`App-Staging`, `App-Production`), each
   using that environment's configuration for Run *and* Archive. The Archive action's
   configuration is what ships.
6. **Per-environment assets.** App icon via `ASSETCATALOG_COMPILER_APPICON_NAME`,
   entitlements via `CODE_SIGN_ENTITLEMENTS`, compile-time switches via
   `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) STAGING`.
7. **Secrets.** No secret values in `.xcconfig` files committed to git. Inject them in CI,
   or `#include?` an untracked `Secrets.xcconfig` (the `?` makes it optional). Anything in
   the app bundle can be extracted, so a client-side "secret" is never truly secret.

Record the setup in the project's knowledge base (`ios-knowledge-base`) — which file owns
which variable, and which scheme ships.

## Investigating a configuration problem

Prove what the build actually used instead of reading the editor:

```bash
xcodebuild -list -project App.xcodeproj               # configurations and shared schemes
xcodebuild -showBuildSettings -scheme App-Staging -configuration Staging \
  | grep -E 'API_HOST|PRODUCT_BUNDLE_IDENTIFIER|SWIFT_ACTIVE_COMPILATION|CODE_SIGN'
plutil -p "$(find ~/Library/Developer/Xcode/DerivedData -path '*Staging-iphonesimulator/App.app/Info.plist' | head -1)"
```

| Symptom | Usual cause | Check |
|---|---|---|
| App talks to the wrong environment | Scheme's Run or Archive uses another configuration; or a stale value from an old build | Scheme → Edit Scheme, each action; clean build folder; `plutil -p` the built Info.plist |
| A variable is empty at runtime | Not in the active configuration's `.xcconfig`, or Info.plist key not mapped to `$(VAR)` | `-showBuildSettings` for that configuration |
| `$(VAR)` appears literally at runtime | Info.plist processing not substituting, or the key is in a file that isn't the target's Info.plist | `INFOPLIST_FILE` setting; generated vs file-based Info.plist |
| URL truncated to `https:` | `//` treated as a comment in `.xcconfig` | Use `https:/$()/` or store the host only |
| Setting change has no effect | Target-level override (bold in the editor) beats the `.xcconfig` | Build Settings → Levels view |
| Works locally, wrong on CI | Scheme not shared, so CI uses an auto-generated one; or CI passes `-configuration` explicitly | `xcodebuild -list` on CI; the CI build command |
| Signing or provisioning error | Bundle ID suffix doesn't match a profile, entitlements file differs per configuration, wrong team | `-showBuildSettings` for `PRODUCT_BUNDLE_IDENTIFIER`, `CODE_SIGN_*`, `DEVELOPMENT_TEAM` |
| Capability works in Debug only | Entitlement in one configuration's entitlements file only | `CODE_SIGN_ENTITLEMENTS` per configuration |
| `#if STAGING` code never compiles in | Condition missing `$(inherited)` or set at the wrong level | `SWIFT_ACTIVE_COMPILATION_CONDITIONS` per configuration |
| SwiftPM package or extension uses different settings | Packages and app extensions have their own targets and settings | Configuration names must match across the project; extensions need their own `.xcconfig` |

Fix the cause in one place, then re-run `-showBuildSettings` to prove it. Write down any
non-obvious cause in the knowledge base so the next person doesn't rediscover it.

## Verification

- [ ] Every environment-specific value is defined in exactly one `.xcconfig` file; the
      target Build Settings editor has no stray overrides.
- [ ] Each environment has a shared scheme, and its Archive action uses the right
      configuration.
- [ ] `xcodebuild -showBuildSettings` output for each configuration was checked, not
      assumed from the editor.
- [ ] The built app's Info.plist shows substituted values (no literal `$(`).
- [ ] The app validates its configuration at launch and refuses an insecure release setup.
- [ ] No secret values committed; secrets come from CI or an untracked optional include.
- [ ] For an investigation: the root cause is named with evidence (command output), the
      fix is in one place, and the same command now shows the expected value.
