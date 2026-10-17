---
name: ios-storekit-subscriptions
description: Implement in-app purchases and subscriptions with StoreKit 2 — product fetching, the purchase flow, transaction verification, subscription status and renewal handling, and sandbox-testing pitfalls. Use when asked to add in-app purchases, implement a paywall's purchase logic, handle subscription renewal or expiry, restore purchases, or debug a StoreKit sandbox issue.
---

# Implement StoreKit 2 subscriptions and IAP

StoreKit 2's API is `async`/`await`-native and does its own transaction verification — most of the historical IAP footguns (manually validating receipts, polling `SKPaymentQueue`) don't apply here. The real work is state management: knowing a user's actual entitlement at any moment, and reacting when it changes outside the app.

## 1. Fetch products and purchase

```swift
let products = try await Product.products(for: ["com.example.widgetpro.monthly", "com.example.widgetpro.yearly"])

func purchase(_ product: Product) async throws -> Transaction? {
    let result = try await product.purchase()

    switch result {
    case .success(let verification):
        let transaction = try checkVerified(verification)
        await transaction.finish()
        return transaction
    case .userCancelled:
        return nil
    case .pending:
        // Needs approval (e.g. Ask to Buy) — not a failure. Don't show an error.
        return nil
    @unknown default:
        return nil
    }
}

func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified(_, let error):
        throw error
    case .verified(let safe):
        return safe
    }
}
```

- **Always call `checkVerified`** (or equivalent) before trusting a transaction — `VerificationResult.unverified` means the cryptographic signature didn't check out, and treating it as a success grants an entitlement on nothing. This is the single most important line in the whole integration.
- **Call `transaction.finish()`** once your app has durably recorded the entitlement (written to your own state, not just held in memory) — an unfinished transaction keeps reappearing in `Transaction.updates` on every app launch until finished.
- **`.pending`** is not an error state — it means the purchase needs external approval (Ask to Buy, or a pending payment method). Don't surface an error message for it; the transaction will complete later through `Transaction.updates`.

## 2. Current entitlements and renewal — listen, don't poll

Subscription status changes without the user opening the app (auto-renewal, a refund, a family-sharing change, a billing retry). Two mechanisms, both needed:

```swift
// On every launch: reconcile against the current truth.
for await result in Transaction.currentEntitlements {
    guard let transaction = try? checkVerified(result) else { continue }
    await updateEntitlement(from: transaction)
}

// For the lifetime of the app: react to changes as they happen.
Task.detached {
    for await update in Transaction.updates {
        guard let transaction = try? checkVerified(update) else { continue }
        await updateEntitlement(from: transaction)
        await transaction.finish()
    }
}
```

- `Transaction.currentEntitlements` is the source of truth for "what does this user actually own right now" — reconcile against it on launch rather than trusting whatever you last cached, since cached state can go stale while the app wasn't running.
- `Transaction.updates` needs a listener running for the app's lifetime (started once, early — e.g. in `AppEnvironment.bootstrap()`), not started lazily when the paywall screen appears; a renewal or refund that happens while the user is on an unrelated screen still needs to update their entitlement.
- For a subscription specifically, `Transaction.currentEntitlements` returns the transaction for the *current* subscription period — check `transaction.revocationDate` (refunded) and, for expiration, look at the corresponding `Product.SubscriptionInfo.Status` (via `product.subscription?.status`) rather than assuming "present in currentEntitlements" alone tells you everything about renewal state.

## 3. Restoring purchases

```swift
try await AppStore.sync()
```

This re-syncs the device's transaction history with App Store Connect and re-emits anything missing through the entitlements/updates streams above — it is the entire "Restore Purchases" button's implementation. Don't build a separate manual restore path; `AppStore.sync()` plus the existing entitlement-reconciliation logic from §2 *is* restore.

**Never call `AppStore.sync()` automatically on launch.** It prompts the user for their Apple ID password every time — launch-time reconciliation should rely on `Transaction.currentEntitlements` (§2) alone, which needs no prompt. Gate `AppStore.sync()` behind an explicit "Restore Purchases" button the user taps on purpose.

## 4. Sandbox testing pitfalls

- **Subscription renewal is compressed in sandbox** (minutes instead of months) specifically so renewal/expiry/billing-retry logic can be tested without waiting — if a subscription that should last a month looks like it expired in 5 minutes during testing, that's correct sandbox behavior, not a bug.
- **A sandbox tester account's purchase history can get into a confusing state** after repeated test purchases; when an entitlement doesn't match expectations, check whether you're verifying the actual *current* entitlement (§2) or something stale, before assuming the integration is broken.
- **`StoreKitTest` (`SKTestSession`) lets you test entirely locally** against a `.storekit` configuration file, without hitting sandbox servers at all — use it for unit/integration tests of the purchase flow and entitlement logic; reserve real sandbox testing for validating against App Store Connect's actual product configuration before release.
- A `.storekit` configuration file used for local testing is not the same thing as the product configuration in App Store Connect — keep them in sync manually; StoreKitTest won't catch a product identifier that's correct locally but misconfigured (or not yet approved) in App Store Connect.

## 5. What this feature needs from other skills

- Any purchase/entitlement state this feature persists locally goes through the same durability thinking as `ios-offline-write` — losing a user's entitlement record because it was only ever held in memory is a real support cost.
- Subscription management touches `ios-privacy-compliance` (purchase history is personal data) and `ios-release-prep` (test the full purchase→entitlement→restore flow as part of pre-release checks, not just that the app builds).

## Verification

- [ ] Every transaction goes through verification before the entitlement is granted; `.unverified` is never treated as success.
- [ ] `transaction.finish()` is called only after the entitlement is durably recorded, not before.
- [ ] `.pending` shows no error UI.
- [ ] `Transaction.updates` has a listener running for the app's lifetime, started during bootstrap, not lazily on the paywall screen.
- [ ] Entitlement state is reconciled against `Transaction.currentEntitlements` on launch, not trusted from a stale cache alone.
- [ ] "Restore Purchases" calls `AppStore.sync()` rather than a hand-rolled restore path, gated behind an explicit user tap — never called automatically on launch.
- [ ] Purchase flow has `StoreKitTest`-based automated tests, not only manual sandbox testing.
