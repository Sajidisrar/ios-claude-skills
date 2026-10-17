---
name: ios-offline-write
description: Make a create, update or delete work while the device is offline in this iOS codebase — outbox queueing, optimistic local records, replay on reconnect, and the tests that prove it. Use when asked to support offline working, queue changes made without signal, let users keep working somewhere with no signal, add optimistic UI for a mutation, or when a save must not be lost when connectivity drops.
---

# Make a mutation work offline

Reads and writes are separate mechanisms here. This skill covers writes. For
offline *reads*, the repository only needs a `ReadPolicy` — no outbox.

## Decide first

- **Does this write need to survive offline at all?** A settings toggle usually
  does not; a completed work record does. Do not add a queue speculatively.
- **What does the user see while it is queued?** This template shows the record
  immediately with a "Waiting to upload" badge.
- **What happens if the server ultimately rejects it?** After five attempts the
  item is held for attention. Decide who sees that and where.
- **Can two devices edit the same record?** If yes, this needs conflict handling
  the template does not provide (see `docs/DECISIONS.md` D12) — raise it rather
  than assuming last-write-wins is acceptable.

## Steps

1. **Add sync state to the model** if it is not there.

   ```swift
   var syncState: SyncState   // .synced, .pendingCreate, .pendingUpdate, .pendingDelete
   ```

   Custom `init(from:)` with `decodeIfPresent(... ) ?? .synced` so server payloads
   still decode. Add `localIDPrefix` / `localID()` and `isLocalOnly` for creates.

2. **Declare outbox kinds and the pending cache key.**

   ```swift
   enum WidgetOutboxKind {
       static let create = "widget.create"
       static let update = "widget.update"
       static let delete = "widget.delete"
       static let all = [create, update, delete]
   }
   ```

3. **Define private queued payload types** (`QueuedCreate`, `QueuedUpdate`,
   `QueuedDelete`). Encode them with the **`.cache`** coders, never `.api` —
   queued payloads are a private on-device format, and coupling them to the API's
   key convention means a backend rename can make a user's pending work
   undecodable.

4. **Fall back in the write path.**

   ```swift
   do {
       let widget: Widget = try await client.send(try WidgetEndpoints.create(draft))
       await cache.store(widget, for: WidgetCacheKeys.detail(id: widget.id))
       await invalidateLists()
       return widget
   } catch let error as APIError where error.isConnectivityFailure {
       let local = draft.localWidget()
       _ = try await outbox.enqueue(kind: WidgetOutboxKind.create,
                                    value: QueuedCreate(localID: local.id, draft: draft),
                                    encoder: outboxEncoder)
       await upsertPending(local)
       return local
   }
   ```

   Only `isConnectivityFailure` queues. A 422 is a real rejection and must reach
   the user now, not in an hour.

5. **Store the optimistic rows durably.** They go in `pendingStore` — a
   `FileCacheStore(location: .applicationSupport)` — not in the response cache.
   The response cache is evictable by the system and is cleared at sign-out; a
   row representing queued work must survive both, or the user watches their work
   disappear while the outbox still holds it. Implement `LocalDataPurging` so the
   session boundary clears cached server data and nothing else.

6. **Merge queued work into reads.** `mergingPendingWork(into:page:search:)`:
   apply updates and deletions on *every* page — a queued change to a record on
   page three must still show — but insert locally created records on the first
   page only, or the same new row appears on every page.

7. **Handle the awkward cases explicitly** — they are the difference between a
   demo and a field app:
   - Editing a record still queued for creation → rewrite the queued create, do
     not enqueue an update for an id the server has never seen.
   - Deleting a record still queued for creation → drop the queued create; send
     nothing.
   - Replaying a delete for a record already gone → treat `404` as success.

8. **Conform to `OutboxHandler`.** `kinds` returns all three; `replay(_:)`
   switches on `item.kind`, sends, then clears the pending record and invalidates
   the list cache. Rethrow `APIError` untouched — the coordinator decides between
   retry and failure.

9. **Register** the repository with `syncCoordinator.register(...)` in
   `AppEnvironment`.

10. **Surface it in the UI.** `OfflineBanner` with `sync.pendingCount`, and
   `widget.syncState.displayName` on the row.

## Verification

- [ ] Test: write while offline is queued, returns a local record, and is visible
      in the next list read.
- [ ] Test: the local record is *not* duplicated on page two.
- [ ] Test: editing a queued create leaves exactly one queued operation.
- [ ] Test: deleting a queued create leaves nothing queued and sends no request.
- [ ] Test: replay replaces the local record with the server one, without
      duplication.
- [ ] Test: a validation failure is surfaced immediately and never queued.
- [ ] Test: purging cached data at sign-out leaves the queued work and its
      optimistic rows intact.
- [ ] Queued payloads use the `.cache` coders.
- [ ] Queued payloads contain no more personal data than strictly necessary, and
      `docs/SECURITY.md` still describes what is stored — update it if this
      changes.
