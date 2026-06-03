import Foundation
import UserNotifications
import Combine
import UIKit
import GardenCore

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
                    self?.refresh()
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
    
    private let planner = NotificationPlanner()

    private var pacificCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return c
    }

    /// Identifiers this manager owns and re-creates on every refresh. The two
    /// fixed daily notifications are intentionally excluded.
    private var refreshOwnedPrefixes: [String] {
        ["pet_misses_you", "litter_box_noon", "pet_needs", "special_date_"]
    }

    /// Rebuilds all state-conditional notifications from persisted state.
    @MainActor
    func refresh(now: Date = Date()) {
        let snapshot = Self.buildSnapshot(now: now)
        let planned = planner.plan(snapshot: snapshot, now: now, calendar: pacificCalendar)
        let center = UNUserNotificationCenter.current()
        // Capture the prefixes on the main actor; the completion below runs on an
        // arbitrary UNS queue, so it must not touch @MainActor-isolated `self`.
        let ownedPrefixes = refreshOwnedPrefixes
        center.getPendingNotificationRequests { pending in
            let toRemove = pending
                .map(\.identifier)
                .filter { id in ownedPrefixes.contains { id.hasPrefix($0) } }
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
            for item in planned {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                content.sound = .default
                let trigger = Self.makeTrigger(item.trigger)
                center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }

    private static func makeTrigger(_ trigger: PlannedTrigger) -> UNNotificationTrigger {
        switch trigger {
        case let .interval(seconds):
            return UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        case let .calendarDaily(hour, minute):
            var comps = DateComponents(); comps.hour = hour; comps.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        case let .calendarAnnual(month, day, hour, minute):
            var comps = DateComponents()
            comps.month = month; comps.day = day; comps.hour = hour; comps.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        }
    }

    /// Assembles a `NotificationSnapshot` purely from persisted state so it can
    /// run with no live view models (e.g. on `scenePhase` background).
    @MainActor
    static func buildSnapshot(now: Date) -> NotificationSnapshot {
        let dp = DataPersistenceManager.shared
        let state = dp.loadPetState()
        let isAdopted = state.adoptedSkin != nil

        let petName: String? = state.adoptedSkin.map { skin in
            state.customPetNames[skin.rawValue] ?? skin.petName
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        var litterDirty = false
        if let skin = state.adoptedSkin {
            let equipped = state.roomLayout(for: skin).equippedItemID(for: .litterBox)
            let isAuto = PetShopCatalog.isAutoLitter(equippedItemID: equipped)
            let events = LitterSchedule.useEventsSinceLastClean(
                cleanedAt: state.litter.asOf, now: now, calendar: calendar)
            litterDirty = !isAuto && events > 0
        }

        let hunger = isAdopted ? PetNeedSnapshot(
            level: state.hunger.current(decayPerHour: PetEconomy.hungerDecayPerHour, now: now),
            decayPerHour: PetEconomy.hungerDecayPerHour, gate: PetEconomy.feedThirstGate) : nil
        let thirst = isAdopted ? PetNeedSnapshot(
            level: state.thirst.current(decayPerHour: PetEconomy.thirstDecayPerHour, now: now),
            decayPerHour: PetEconomy.thirstDecayPerHour, gate: PetEconomy.feedThirstGate) : nil

        let specialDates = dp.loadCoupleProfile().specialDates.map {
            PlannerSpecialDate(id: $0.id.uuidString, title: $0.title, date: $0.date)
        }

        return NotificationSnapshot(
            isPetAdopted: isAdopted,
            petName: petName,
            userNickname: dp.loadUserNickname(),
            lastPetInteractionAt: state.lastPetInteractionAt,
            litterIsDirty: litterDirty,
            hunger: hunger,
            thirst: thirst,
            specialDates: specialDates
        )
    }

    /// Fires an immediate local banner for a freshly-crossed moment milestone.
    func fireMilestone(_ count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Milestone unlocked! 🎉"
        content.body = "You've saved \(count) moments together. Here's to many more 💞"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "milestone_\(count)", content: content, trigger: trigger))
    }

    /// Partner-driven events. DORMANT: no backend exists to drive these yet.
    /// This is the single hook a future server/APNs delivery path will call,
    /// and the debug actions in SettingsSheet call it for local verification.
    enum PartnerEvent {
        case joined(partnerName: String?)
        case loveLetterReceived(title: String, sentAt: Date)
        case partnerAddedMoment
        case partnerAddedSpecialDate
    }

    func handlePartnerEvent(_ event: PartnerEvent) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        let id: String
        switch event {
        case let .joined(partnerName):
            id = "partner_joined"
            content.title = "BabyTown"
            content.body = "\(partnerName ?? "Your partner") just joined your BabyTown 💞"
        case let .loveLetterReceived(title, sentAt):
            id = "partner_love_letter"
            let f = DateFormatter()
            f.doesRelativeDateFormatting = true
            f.dateStyle = .medium; f.timeStyle = .short
            content.title = title
            content.body = "Sent \(f.string(from: sentAt))"
        case .partnerAddedMoment:
            id = "partner_added_moment"
            content.title = "BabyTown"
            content.body = "A new moment was saved — check it out!"
        case .partnerAddedSpecialDate:
            id = "partner_added_date"
            content.title = "BabyTown"
            content.body = "A new important date was added — take a look!"
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger))
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
