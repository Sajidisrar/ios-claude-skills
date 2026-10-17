---
name: ios-refactor
description: Refactor Swift code in this iOS codebase without changing behaviour — extracting types, splitting oversized files, moving logic to the right layer, removing duplication, or migrating a pattern across features. Use when asked to clean up, tidy, restructure, extract, split, simplify or modernise existing code, or when a file has grown past the point of being readable.
---

# Refactor safely

A refactor that changes behaviour is not a refactor, it is an undocumented
change. The discipline below is what keeps them apart.

## Before touching anything

1. **Name the goal in one sentence.** "Move date formatting out of the view into
   the view model." If you cannot, the change is not a refactor — it is a
   redesign, and needs discussion first.
2. **Check the tests that cover the code.** If there are none, write them
   *first*, against current behaviour, and confirm they pass. Those tests are the
   only proof the refactor was safe.
3. **Check `docs/DECISIONS.md`.** If the structure you dislike is a recorded
   decision, argue with the decision rather than quietly reversing it.

## Where things belong

Most refactors in this codebase are one of these five moves:

| Smell | Move |
| --- | --- |
| Formatting, string building or derived flags in a view | Into the view model as a computed property |
| Business rules or validation in a view model | Onto the model (`validationMessages`) or the repository |
| `Endpoint` construction or cache keys in a view model | Into the feature's `Data` folder |
| The same helper in two features | Down into `Core` — never sideways between features |
| A repository over ~350 lines | Split by concern: reads, writes, replay — same type, `// MARK:` sections, or an extension per concern in separate files |

Things that must **not** move: `URLSession` out of `Core/Networking`, tokens out
of `Core/Auth`, cache and outbox access out of repositories.

## Method

- One kind of change per commit. Renaming *and* extracting *and* re-ordering in
  one diff is unreviewable.
- Extract by copying, redirecting call sites, then deleting the original — never
  by editing in place and hoping.
- Keep the public shape of a type stable while you move its internals, then
  change the shape in a separate step.
- Run the tests after each step, not at the end.
- Leave the comments that explain *why* attached to the code they explain. Losing
  the "why the actor is here" comment costs more than the refactor gains.

## What counts as done

The diff should read as obviously equivalent. If a reviewer has to reason about
whether behaviour changed, split the change up further.

## Verification

- [ ] Tests existed before, still exist, and still pass unchanged. Changing a test
      to match the refactor means behaviour changed — stop and say so.
- [ ] No new dependency across the layer boundaries.
- [ ] No feature now imports another feature.
- [ ] Public behaviour identical: same states, same error copy, same requests.
- [ ] Comments explaining non-obvious decisions were carried across.
- [ ] `project.pbxproj` is untouched. The source folders are synchronised, so a
      file or folder move needs no project-file change; if one appears in the
      diff, explain why.
- [ ] The summary says explicitly what did *not* change.
