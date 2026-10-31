---
name: ios-knowledge-base
description: Build and maintain a compact, git-tracked knowledge base of an iOS app's structure — modules, features, data flow, key types, conventions and decisions — so agents read one short map instead of re-exploring the codebase every session, saving tokens. Refreshes incrementally from `git diff` since the last recorded commit, so the map stays close to the current app state. Use when starting work on an unfamiliar iOS codebase, when asked to document or map the app, when the knowledge base is stale after merges, or to answer "where is X / why is it built like this".
---

# iOS knowledge base

**Goal:** an agent starting cold should understand the app's structure by reading a few
hundred lines, not by opening fifty files. Every session that skips re-exploration saves
tokens and time. The map only pays off if it is *current*, so it records the commit it
describes and is refreshed from `git diff`, never rewritten from scratch.

## Layout

All under `docs/kb/`, committed to the repo so every device, branch and teammate gets it.

| File | Holds | Budget |
|---|---|---|
| `INDEX.md` | What the app is (2–3 lines), target list, the `kb-commit` marker, one line per KB file, and "read this first" pointers | ≤ 60 lines |
| `STRUCTURE.md` | Module/folder map: each top-level folder or target → one line on what it owns. Allowed dependency directions | ≤ 150 lines |
| `FEATURES.md` | One block per feature: entry view, view model, repository, endpoints, persistence, tests — as paths | ≤ 8 lines per feature |
| `FLOWS.md` | Data flow for 1–3 representative paths (launch → first screen; a fetch; a write/offline write), where state lives, threading model | ≤ 100 lines |
| `CONVENTIONS.md` | Only rules a linter doesn't enforce: naming, error handling, logging, test style | ≤ 80 lines |
| `DECISIONS.md` | Numbered log (`D1`, `D2`…): context, decision, rejected alternatives, date. Supersede, never renumber or rewrite | grows; keep each ≤ 10 lines |
| `SECURITY.md` | What is stored where (Keychain, files, defaults, caches), what leaves the device, auth/session handling — never secret values | ≤ 80 lines |

Other skills in this collection look for `docs/DECISIONS.md` and `docs/SECURITY.md`. If the
project already has those, keep them where they are and link to them from `INDEX.md` instead
of duplicating.

Add one line to the project's `CLAUDE.md`/`AGENTS.md`:
`Read docs/kb/INDEX.md before exploring the code; open source files only for the area you're changing.`

## Writing for low token cost

- **Paths and type names, not prose.** `Features/Orders/ → OrdersView, OrdersViewModel,
  OrdersRepository (Core/Data), GET /orders` beats a paragraph.
- **No line numbers** (they drift) and **no code excerpts** unless a pattern can't be named.
- **One fact, one place.** Link between KB files instead of repeating.
- **State the why only where code can't**: in `DECISIONS.md`, not scattered everywhere.
- Stay inside the budgets above. If a file outgrows its budget, the map is too detailed —
  summarise, don't split into more files.
- Mark anything inferred rather than read as **Unconfirmed**, and ask about it.
- No secrets, tokens, real user/customer data, internal hostnames or personal details.

## Mode A — first build

1. Check for an existing `docs/kb/INDEX.md`. If it exists, use Mode B instead.
2. Map cheaply, widest first: the Xcode project / `Package.swift` targets, `git ls-files`
   grouped by top-level folder, the app entry point and composition root (where
   dependencies are wired), the networking and persistence layers. Then trace **one**
   feature end to end. Don't read every file — read enough to name each folder's job.
3. Write the files above, within budget.
4. Record the commit the map describes at the top of `INDEX.md`:
   `kb-commit: <full SHA from git rev-parse HEAD>` and `kb-updated: <YYYY-MM-DD>`.
   Commit the KB on its own, or with the change that prompted it.

## Mode B — incremental refresh (the normal case)

Run at the start of a session on a known codebase, after pulling or merging, or before a
release.

1. Read `kb-commit` from `INDEX.md`. If that commit isn't reachable (`git cat-file -e <sha>`
   fails — e.g. history was rewritten), fall back to Mode A for the affected areas.
2. See what moved since then:
   ```bash
   git diff --name-status <kb-commit>..HEAD
   git log --oneline <kb-commit>..HEAD
   ```
3. If nothing under source folders, project files or `Package.swift` changed, only bump
   `kb-commit` — done. This is the cheap path; most refreshes end here.
4. Otherwise, map each changed path to the KB entries that mention it (`grep` the KB for the
   folder, type or feature name) and update **only those**:
   - added folder/target/feature → add its line or block
   - deleted or renamed (`D`/`R` status) → remove or rename every mention
   - changed dependency, storage, auth or networking code → re-check `FLOWS.md` and
     `SECURITY.md`
   - a commit message that describes a trade-off → consider a `DECISIONS.md` entry
5. Set `kb-commit` to the new `HEAD` and `kb-updated` to today. Commit the KB update.

## Keeping it near the app state

- **Same change, same commit.** When your own change adds, removes or moves a feature,
  module, dependency, storage location or convention, update the KB in that commit. A KB
  updated "later" is wrong by the next release.
- **Staleness check** — when reading the KB, compare `kb-commit` with `HEAD`:
  `git rev-list --count <kb-commit>..HEAD`. If source has changed since, run Mode B before
  trusting the map for the changed areas.
- **Optional automation**, only if the user wants it: a CI job or git hook that fails or
  warns when source changed but `docs/kb/` didn't. Propose it; don't install it unasked.

## Answering from it

For "where is X" or "why is it like this", answer from the KB first and cite the file (and
`Dn` for decisions). Open source only to confirm or to go deeper. If the KB has no answer,
say so, answer from code, and add the missing fact to the KB.

## Verification

- [ ] `INDEX.md` has a `kb-commit` that equals the commit the map was last checked against,
      and a `kb-updated` date.
- [ ] Every path and type name in the KB exists at that commit.
- [ ] Every file is within its line budget; no code excerpts or line numbers.
- [ ] In Mode B, every added, deleted and renamed path from `git diff --name-status` is
      reflected (or confirmed irrelevant).
- [ ] Inferences are marked **Unconfirmed**; nothing is presented as recorded intent unless
      it is in `DECISIONS.md`.
- [ ] `DECISIONS.md` entries were only added or superseded, never renumbered or rewritten.
- [ ] No secrets, real personal or customer data, or internal hostnames anywhere in the KB.
- [ ] `CLAUDE.md`/`AGENTS.md` tells agents to read `docs/kb/INDEX.md` first.
