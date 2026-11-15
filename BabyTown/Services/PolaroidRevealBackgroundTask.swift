import BackgroundTasks
import Foundation

/// Background app refresh around 9 PM Pacific: reveals today's polaroids and syncs
/// them, so the partner gets them even if this phone's app isn't opened tonight.
///
/// This is the fallback (option 2). The server-side reveal (BAB-143) is the primary
/// path and the in-app reveal in `HomeViewModel` still runs when the app is open.
/// iOS decides when the refresh actually runs, so it can be late or skipped.
///
/// Info.plist (`Covela-Info.plist`): `BGTaskSchedulerPermittedIdentifiers` lists
/// `identifier`, and `UIBackgroundModes` includes `fetch`.
enum PolaroidRevealBackgroundTask {
    static let identifier = "LS.Covela.polaroidReveal"

    /// Must run before `application(_:didFinishLaunchingWithOptions:)` returns.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refresh)
        }
    }

    /// Asks iOS to wake the app shortly after the next 9 PM Pacific. Safe to call often:
    /// a new request replaces the pending one.
    static func scheduleNext(after now: Date = Date()) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = nextRevealTime(after: now).addingTimeInterval(60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[PolaroidRevealBackgroundTask] schedule failed: \(error)")
        }
    }

    static func nextRevealTime(after now: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let today9PM = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now)!
        return today9PM > now ? today9PM : calendar.date(byAdding: .day, value: 1, to: today9PM)!
    }

    private static func handle(_ task: BGAppRefreshTask) {
        // Always line up tomorrow's run first, even if this one is cut short.
        scheduleNext()

        let work = Task { @MainActor in
            PolaroidReveal.revealDueInBackground()
            CoupleSyncBootstrap.registerResources()
            let succeeded = await CoupleSyncEngine.shared.sync(trigger: .backgroundRefresh)
            task.setTaskCompleted(success: succeeded)
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
