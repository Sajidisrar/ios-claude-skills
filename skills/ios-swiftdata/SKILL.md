---
name: ios-swiftdata
description: Design and evolve a SwiftData model layer — @Model schema design, relationships, migrations with VersionedSchema, and where SwiftData fits next to (or instead of) a hand-rolled cache/outbox layer. Use when asked to add local persistence with SwiftData, design a @Model, migrate a SwiftData schema, or evaluate SwiftData as a replacement for an existing CacheStore/Outbox implementation.
---

# Work with SwiftData

SwiftData is Apple's persistence framework (iOS 17+) built on top of Core Data's underlying storage — not a different thing from Core Data so much as a Swift-native modeling layer in front of it. Decide deliberately whether a feature belongs in SwiftData at all before modeling anything.

## 1. SwiftData vs. this codebase's existing persistence

This repo's other skills (`ios-offline-write`, `ios-api-endpoint`) assume a hand-rolled `CacheStore`/`Outbox` pair: a response cache keyed by endpoint, and a separate durable queue for offline writes. SwiftData is a different tool solving a related but distinct problem — a real local *database* with relationships and queries, not a cache of server responses.

| Need | Reach for |
|---|---|
| Cache the last-known server response, evictable, cleared at sign-out | The existing `CacheStore` — SwiftData is the wrong tool for something explicitly disposable |
| Queue a pending write until connectivity returns | The existing `Outbox` pattern — SwiftData has no built-in notion of "pending sync state," you'd build that yourself on top of it anyway |
| A genuinely local-first dataset with relationships, queries, and sorting the user interacts with directly (notes, a local project list, draft content) | SwiftData is a reasonable fit |
| Replacing the whole `CacheStore`/`Outbox` layer with SwiftData everywhere | Treat as an architecture decision, not a per-feature one — see `ios-dependency-assessment`'s framing: what does it buy, what does it cost, how would you back out if it's wrong |

Don't introduce SwiftData for one screen's local cache when the existing `CacheStore` already does that job; introduce it when the feature actually needs persistent, queryable, relational local state.

## 2. Model design

```swift
@Model
final class Widget {
    @Attribute(.unique) var id: String
    var title: String
    var createdAt: Date
    var status: WidgetStatus

    @Relationship(deleteRule: .cascade, inverse: \WidgetNote.widget)
    var notes: [WidgetNote] = []

    init(id: String, title: String, createdAt: Date, status: WidgetStatus) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.status = status
    }
}
```

- `@Attribute(.unique)` is how you get an upsert-safe primary key — without it, inserting a model with a duplicate logical ID creates a second row rather than raising a conflict.
- `@Relationship(deleteRule:)` matters for correctness, not just convenience: `.cascade` deletes children with the parent, `.nullify` (the default) leaves orphaned children with a nil reference, `.deny` blocks the delete if children exist. Pick deliberately — the default silently orphaning rows is rarely what you actually want for an owned child collection.
- Enums used as a `@Model` property need to be `Codable` and have a stable raw representation if you'll ever migrate the schema; a `String`-backed enum with explicit raw values survives a migration far more predictably than relying on case order.
- `@Model` classes are reference types with observation built in for SwiftUI (`@Query`, `@Bindable`) — there's no separate "draft" struct the way this codebase's other models use `<Name>Draft`; mutate the model directly inside a transaction, or hold a lightweight plain-struct draft in the view model until save if you want cancel-without-saving behavior.

## 3. Migrations

Any schema change — a new property, a changed relationship, a renamed field — needs a `VersionedSchema` plan once the app has shipped with a prior schema. Skipping this means an existing user's local store either fails to open or silently drops data on upgrade.

```swift
enum WidgetSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Widget.self] }
}

enum WidgetSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Widget.self] }
    // Widget.self here is the *current* definition with the new property —
    // the migration plan below is what tells SwiftData how to get existing
    // rows from V1's shape to V2's.
}

enum WidgetMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [WidgetSchemaV1.self, WidgetSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.custom(
            fromVersion: WidgetSchemaV1.self,
            toVersion: WidgetSchemaV2.self,
            willMigrate: nil,
            didMigrate: { context in
                // Backfill the new property for existing rows here, then
                // try context.save() — this closure runs inside the migration.
            }
        )]
    }
}
```

- A **lightweight migration** (adding an optional property, widening a type) can often happen without a custom stage — SwiftData infers it. The moment a change needs *data transformation* (backfilling a new required field, splitting one property into two), it needs an explicit `.custom` stage with `didMigrate`.
- Test migrations against a real populated store from the previous version, not an empty one — an empty store migrating cleanly proves nothing about whether existing users' data survives.
- `ModelContainer(for: Widget.self, migrationPlan: WidgetMigrationPlan.self)` is where the plan actually gets wired in; forgetting to pass it means the container falls back to default (often destructive) migration behavior.

## 4. Queries and performance

- `@Query` in a SwiftUI view re-runs its fetch on relevant changes automatically — but a `@Query` with a large, unfiltered result set in a list view is the SwiftData equivalent of this codebase's "whole-list invalidation" problem (`ios-performance-tuning`): add a `predicate` and `sortBy` instead of fetching everything and filtering in the view.
- Reading/writing from a background context (`ModelActor`, or a secondary `ModelContext`) for anything heavier than a quick UI-driven edit — blocking the main context for a large import or batch update produces the same "janky scrolling" symptom as any other main-thread-blocking work.
- `FetchDescriptor` with `#Predicate` macros are type-checked at compile time against the model — a predicate referencing a property that doesn't exist is a compile error, not a runtime crash; still worth sanity-checking that the predicate expresses what you think it does, since the macro won't catch a *logically* wrong condition.

## Verification

- [ ] The decision to use SwiftData (vs. the existing `CacheStore`/`Outbox`) for this feature is stated explicitly, not assumed.
- [ ] Every `@Relationship` has a deliberately chosen `deleteRule` — not left at the default without checking what that means for this relationship.
- [ ] A schema change that isn't purely additive has a `VersionedSchema` + `SchemaMigrationPlan`, tested against a populated store from the prior version.
- [ ] List-driving `@Query`s have a `predicate`/`sortBy` rather than fetching unbounded data and filtering client-side.
- [ ] Heavy writes (import, batch update) run off the main context.
- [ ] No test or fixture uses real personal data to exercise the model.
