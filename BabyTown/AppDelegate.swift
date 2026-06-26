import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    static let openScrapbookNotificationName = Notification.Name("OpenScrapbookNotification")
    private static let appIconRefreshKey = "covela_app_icon_refresh_v1"

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationManager.shared.currentMask
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set delegate to handle notification actions
        UNUserNotificationCenter.current().delegate = self
        
        // Request permission on launch
        NotificationManager.shared.requestAuthorization()
        refreshNotificationsAfterAppIconUpdateIfNeeded()

        return true
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            NotificationManager.shared.acknowledgeNotification(identifier: notification.request.identifier)
        }
        completionHandler([.banner, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        Task { @MainActor in
            NotificationManager.shared.acknowledgeNotification(identifier: identifier)
        }
        if identifier == "daily_morning_notification" {
            NotificationCenter.default.post(name: NotificationManager.openCameraNotificationName, object: nil)
        } else if identifier == "archive_7_day" || identifier == "archive_3_day" {
            NotificationCenter.default.post(name: AppDelegate.openScrapbookNotificationName, object: nil)
        } else if identifier == "archive_expired" {
            Task { @MainActor in
                var profile = DataPersistenceManager.shared.loadCoupleProfile()
                if profile.relationshipStage == .archivedCouple {
                    profile.relationshipStage = .prelude
                    profile.breakupDate = nil
                    profile.archiveExpiryDate = nil
                    DataPersistenceManager.shared.saveCoupleProfile(profile)
                    DataPersistenceManager.shared.deleteArchiveBundle()
                }
            }
        } else if identifier.hasPrefix("watch_together_invite_") {
            let userInfo = response.notification.request.content.userInfo
            if let sessionIDString = userInfo["sessionID"] as? String,
               let sessionID = UUID(uuidString: sessionIDString),
               let videoURL = userInfo["videoURL"] as? String {
                let hostName = userInfo["hostName"] as? String ?? "Your partner"
                NotificationCenter.default.post(
                    name: .watchTogetherInviteReceived,
                    object: nil,
                    userInfo: [
                        "sessionID": sessionID,
                        "videoURL": videoURL,
                        "hostName": hostName
                    ]
                )
            }
        }

        completionHandler()
    }

    /// Re-schedules local notifications once after the Covela book app icon ships so
    /// pending requests are rebuilt against the updated bundle icon.
    private func refreshNotificationsAfterAppIconUpdateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.appIconRefreshKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.appIconRefreshKey)
        Task { @MainActor in
            NotificationManager.shared.scheduleDailyNotification()
            NotificationManager.shared.refresh()
        }
    }
}
