import Foundation
import UserNotifications
import Combine
import UIKit

class NotificationManager: NSObject, ObservableObject {
    @MainActor static let shared = NotificationManager()
    
    @MainActor @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    static let openCameraNotificationName = Notification.Name("OpenCameraNotification")
    
    private override init() {
        super.init()
        Task { @MainActor in
            await checkPermissionStatus()
        }
    }
    
    @MainActor
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] success, error in
            Task { @MainActor [weak self] in
                await self?.checkPermissionStatus()
                if success {
                    print("Notification permission granted")
                    self?.scheduleDailyNotification()
                } else if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor
    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.permissionStatus = settings.authorizationStatus
    }
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func scheduleDailyNotification() {
        // Remove existing notifications to avoid duplicates or old schedules
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Schedule morning notification
        scheduleMorningNotification()
        
        // Schedule evening notification for 9PM
        scheduleEveningNotification()
    }
    
    private func scheduleMorningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "BabyTown"
        content.body = "Good morning! Lets capture 5 photos today and add to our BabyTown!"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "daily_morning_notification",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling morning notification: \(error.localizedDescription)")
            } else {
                print("Morning notification scheduled for 8:00 AM")
            }
        }
    }
    
    private func scheduleEveningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Polaroids Available!"
        content.body = "Your Daily Polaroids are now available to view in BabyTown!"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 21 // 9 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "daily_evening_polaroids",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling evening notification: \(error.localizedDescription)")
            } else {
                print("Evening notification scheduled for 9:00 PM")
            }
        }
    }
}
