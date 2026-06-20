import Foundation

enum NotificationType: String {
    case welcomeCard
    case valentinesCard
}

struct AppNotification: Identifiable {
    let id: String
    let title: String
    let bodyPreview: String
    let date: Date
    let type: NotificationType
    let icon: String

    static func seededNotifications(userNickname: String? = nil) -> [AppNotification] {
        let trimmed = userNickname?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let preview: String
        if let trimmed, !trimmed.isEmpty {
            preview = "For \(trimmed)"
        } else {
            preview = "For you"
        }

        return [
            AppNotification(
                id: NotificationType.welcomeCard.rawValue,
                title: "Welcome to Covela",
                bodyPreview: preview,
                date: Date(),
                type: .welcomeCard,
                icon: "sparkles"
            )
        ]
    }

    static func hasUnread(userNickname: String? = nil) -> Bool {
        let readIDs = DataPersistenceManager.shared.readInAppNotificationIDs()
        return seededNotifications(userNickname: userNickname).contains { !readIDs.contains($0.id) }
    }
}
