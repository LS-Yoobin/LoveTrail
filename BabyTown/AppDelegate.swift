import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set delegate to handle notification actions
        UNUserNotificationCenter.current().delegate = self
        
        // Request permission on launch
        NotificationManager.shared.requestAuthorization()
        
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
            // Post notification to let the app know to open the camera
            NotificationCenter.default.post(name: NotificationManager.openCameraNotificationName, object: nil)
        }
        
        completionHandler()
    }
}
