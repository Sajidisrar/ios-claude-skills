---
name: ios-api-contract-migration
description: Adapt this iOS app to a changed backend contract — renamed or removed fields, changed types, new required parameters, a new error shape, a version bump or a breaking response change. Use when told the API has changed, when given an OpenAPI or Swagger diff, when decoding starts failing after a backend release, or when the app must support both an old and a new response shape during a rollout.
---

# Migrate an API contract change

The failure mode to avoid: patching one decode error, shipping, and discovering
the next three in production. Work from the contract, not from the crash.

## 1. Establish the change precisely

For each affected endpoint, write down: field name before and after, type before
and after, whether it is now optional or required, and whether the change is
already live in each environment.

Then classify it, because the handling differs:

| Change | Handling |
| --- | --- |
| Field renamed | Update the model property; check `snake_case` conversion still lines up |
| Field now optional | Property becomes `Optional`; find every use and decide what absence means |
| Field removed | Remove it and every use — do not keep a dead property "for safety" |
| Type changed | Update and check every call site; add a decoding test with a real payload |
| New required request field | Add to the draft or request model; decide the default and whether the user must supply it |
| New enum case | Enums decoded from the wire need a fallback, or a new case ships a crash on old builds |
| Error shape changed | Update `APIErrorPayload` and check `AppError.from` still produces sensible copy |

## 2. Beware the key-conversion trap

`JSONDecoder.api` uses `.convertFromSnakeCase` and the encoder uses
`.convertToSnakeCase`. This round-trips cleanly for ordinary camelCase, but **not
for trailing acronyms**: `localID` encodes to `local_id` and decodes back to
`localId`, which does not match. If a property must carry an acronym, either name
it `localIdentifier` or declare explicit `CodingKeys`. Queued outbox payloads
avoid the issue entirely by using the `.cache` coders.

Enum raw values are *values*, not keys, so they are never converted: they must
match the wire exactly (`case inProgress = "in_progress"`).

## 3. Handle a staged rollout

If old and new shapes are both live, do not fork the model. Prefer, in order:

1. Make the new field `Optional` and treat absence as the old behaviour. Simple,
   and it deletes cleanly later.
2. If both shapes must be understood, write a custom `init(from:)` that tries the
   new key then the old one, with a comment naming the date or release when the
   fallback can be deleted.

Never version the model by duplicating the type. Two nearly identical models
diverge within a sprint.

## 4. Update in this order

1. Wire models and domain models.
2. Endpoints — new parameters, changed paths.
3. Repository — anything that read a removed field.
4. **Cache compatibility.** Cached JSON was written with the old shape.
   `FileCacheStore` and `KeychainTokenStorage` both drop unreadable data rather
   than failing, so a shape change is survivable — but confirm the new model
   really does fail to decode the old payload rather than decoding it wrongly. If
   a stale cache could decode into something misleading, bump the cache directory
   name or clear it on upgrade.
5. **Outbox compatibility.** A queued payload written by the previous app version
   must still replay, or the user silently loses work. If a queued payload shape
   changes, keep the old decode path for one release.
6. View models and views.

## 5. Test with real payloads

Take actual response bodies from the new API (with any personal data replaced by
invented values) and use them as test fixtures. A hand-written fixture that
matches your assumption proves nothing.

Cover: the new shape decodes; the old shape either decodes correctly during
rollout or fails cleanly; a stale cache does not produce wrong data; a queued
write from the previous version still replays.

## Verification

- [ ] Every changed endpoint has a decoding test against a realistic payload.
- [ ] No property kept alive "just in case".
- [ ] Key-conversion checked for any property with an acronym.
- [ ] New enum cases have a decoding fallback, or the change is confirmed safe.
- [ ] Cache and outbox compatibility considered explicitly, and the conclusion
      written in the summary.
- [ ] Fixtures contain no real client, production or personal data.
- [ ] Any temporary dual-shape support carries a comment saying when to remove it.
