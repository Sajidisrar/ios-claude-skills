# Severity levels

Assign severity by actual impact and evidence quality — never by how many
findings would "look right." Accuracy over volume.

## 🔴 BLOCKER — must fix before commit

- Serious, plausible security vulnerability (auth bypass, exposed
  credential/token/secret, insecure storage of sensitive data, disabled TLS
  validation, injection risk with real reachable input)
- Definite crash on a reachable path (unchecked force unwrap/cast on data
  that can plausibly be nil/wrong-type at that call site, out-of-bounds
  access, obvious infinite loop/recursion)
- Data corruption (writes that can leave persisted state inconsistent)
- Severe concurrency bug (data race on shared mutable state, deadlock,
  UI updated off the main thread in a way that will misbehave/crash)
- Definite, significant functional defect (change does not do what it
  claims, or breaks a clearly reachable existing flow)

A **single** serious security or correctness issue is sufficient to be a
BLOCKER — do not require multiple occurrences.

## 🟠 HIGH — strongly recommended before commit

- Significant regression risk (breaks a caller's reasonable expectations,
  but not a definite crash/corruption)
- Important incorrect behavior confined to a narrower or less-common path
- Serious gap in error handling (silently swallowed error on an important
  path, no handling for a likely failure mode)
- Meaningful architecture/coupling problem introduced by the change
- Missing test for critical new/changed behavior (not every change — the
  ones where a regression would be costly and silent)

## 🟡 MEDIUM — fix when practical

- Moderate edge-case risk (uncommon input, not clearly reachable in normal
  use)
- Moderate maintainability issue (avoidable duplication, complexity that
  will slow future changes)
- Meaningful but non-critical test gap

## 🔵 LOW — minor improvement

- Small readability/naming nit in changed code
- Minor inefficiency with no real-world impact
- Small inconsistency with local conventions

## 🟢 INFO — observation / optional suggestion

- Worth mentioning, not a defect (e.g. "consider X for the future", a
  note about something that couldn't be verified)

## Balance rules

- One or two isolated minor inconsistencies in otherwise-consistent changed
  code → LOW/INFO, not HIGH. Do not fail a change over cosmetic nits.
- Do not escalate a finding just because the surrounding file is old/messy —
  judge the change itself.
- Do escalate without hesitation for security and definite-correctness
  issues, even a single instance, even in an otherwise clean change.
- If you are not confident a path is actually reachable, say so and either
  lower the severity or mark it `Requires verification` rather than
  asserting impact you can't support.

## Final decision mapping

- Any 🔴 BLOCKER → **❌ DO NOT COMMIT**
- No BLOCKER, but any 🟠 HIGH or 🟡 MEDIUM → **⚠️ REVIEW RECOMMENDED**
- Only 🔵 LOW / 🟢 INFO (or nothing) → **✅ READY TO COMMIT**

Exactly one decision line appears at the end of every report.
