---
name: ios-push-and-background-tasks
description: Implement push notifications (remote and local) and BackgroundTasks framework scheduling — registration, payload handling, notification actions, and background refresh/processing task budgets. Use when asked to add push notifications, handle a notification tap or action, schedule background work, debug a background task that never runs, or decide between a silent push and a scheduled background task.
---

# Push notifications and background tasks

Two different systems, often needed together: push notifications tell the app something happened; `BackgroundTasks` gets CPU time to actually do something about it when the app isn't in the foreground. Neither gives the app a guarantee about *when* — both are scheduled at the system's discretion, not the app's.

## 1. Registering for remote notifications

```swift
let center = UNUserNotificationCenter.current()
let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
guard granted else { return }

await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
```

- Request authorization at the point the feature needing it is actually relevant (permission priming at launch, before the user has any reason to want notifications, is a common rejection-adjacent pattern and a bad conversion rate even where it's allowed) — same principle as permission requests in `ios-privacy-compliance`.
- The device token arrives asynchronously via `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` — send it to your backend from there, and handle `didFailToRegisterForRemoteNotificationsWithError:` (no network, not actually entitled, simulator without a real APNs connection) as a real case, not a silently ignored one.
- Re-register and re-send the token on meaningful app state changes (user re-signs-in as a different account, app reinstall) — a token tied to the wrong account silently misdelivers or fails to deliver push, which is much harder to debug after the fact than preventing it.

## 2. Handling the notification

```swift
// Foreground delivery:
func userNotificationCenter(_ center: UNUserNotificationCenter,
                             willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    .banner  // or [] to suppress entirely for a notification the app handles itself
}

// Tap / action:
func userNotificationCenter(_ center: UNUserNotificationCenter,
                             didReceive response: UNNotificationResponse) async {
    let payload = response.notification.request.content.userInfo
    guard let destination = route(fromPushPayload: payload) else { return }
    await navigator.navigate(to: destination)
}
```

- Route a notification tap through the same deep-link resolution as `ios-deep-linking` — a push payload is just another source of "here's where the user should end up," not a separate ad hoc navigation path.
- A **silent push** (`content-available: 1`, no alert) exists to wake the app briefly to fetch/update state in the background — not to show UI. Keep that work bounded and fast; the OS gives silent pushes a short execution window, and iOS will throttle an app that abuses them for anything resembling polling.
- A notification that arrives while the app is already showing the relevant content shouldn't duplicate or re-trigger navigation — check current state before navigating, the same discipline as any other "don't fetch/navigate twice" concern.

## 3. BackgroundTasks framework

```swift
// Register once, early (before applicationDidFinishLaunching returns):
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.widgetapp.refresh", using: nil) { task in
    handleRefresh(task: task as! BGAppRefreshTask)
}

func scheduleRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.example.widgetapp.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
}

func handleRefresh(task: BGAppRefreshTask) {
    task.expirationHandler = { /* cancel in-flight work; task is about to time out */ }

    let operation = Task {
        defer { task.setTaskCompleted(success: true) }
        await performRefresh()
    }
    task.expirationHandler = { operation.cancel() }
}
```

- **`BGAppRefreshTask`** is for short, periodic refreshes; **`BGProcessingTask`** is for longer-running work (can require network/power connected) like a bulk sync or cleanup — pick based on the actual work's shape, not availability-driven habit.
- `earliestBeginDate` is a floor, not a schedule — the system decides the actual run time based on usage patterns, battery, and background activity budget; a background task that "never runs" in testing is very often working as designed (the system hasn't judged this a good moment), not broken. Debug with `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"..."]` in the LLDB console, or the Xcode scheme's background-task debug trigger, rather than waiting on real-world scheduling during development.
- Always **re-submit** the next request from inside the handler (if this is a recurring refresh) — a `BGAppRefreshTaskRequest` is one-shot; forgetting to reschedule after each run is the most common reason "background refresh used to work and now doesn't."
- Respect `task.expirationHandler` — cancel the in-flight work and call `setTaskCompleted(success:)` promptly when it fires, or the system will kill the process entirely rather than iOS politely waiting; an app that gets killed mid-background-task repeatedly is penalized with a worse budget for future background execution.
- Register every background task identifier declared in `Info.plist`'s `BGTaskSchedulerPermittedIdentifiers` — an identifier scheduled but never registered (or vice versa) fails silently at the API level, not with an obvious crash.

## 4. Testing

- Local notifications and their actions can be tested directly via `UNUserNotificationCenter` in a simulator/device without any push infrastructure — use this for the handling/routing logic, reserve real APNs sandbox testing for payload delivery itself.
- Background task handlers are testable as plain async functions once separated from the `BGTaskScheduler` registration glue — test `performRefresh()` directly with the usual stubs, don't try to unit-test actual OS scheduling behavior.
- Cancellation under `expirationHandler` needs an explicit test: start the work, trigger the handler, assert partial work is actually cancelled rather than continuing to completion unobserved.

## Verification

- [ ] Notification authorization is requested at a point tied to an actual feature, not speculatively at launch.
- [ ] Device-token failures and re-registration-on-account-change are both handled, not just the happy path.
- [ ] Notification taps/actions route through the same deep-link resolution as the rest of the app.
- [ ] Silent pushes do bounded, fast work only — nothing resembling continuous polling.
- [ ] Every `BGTaskSchedulerPermittedIdentifiers` entry in `Info.plist` has a matching `register(forTaskWithIdentifier:)` call, and vice versa.
- [ ] A recurring background task re-submits its next request from inside its own handler.
- [ ] `expirationHandler` actually cancels in-flight work and the task reports completion promptly.
