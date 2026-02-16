import Foundation

enum NotificationType {
    case valentinesCard
}

struct AppNotification: Identifiable {
    let id: UUID
    let title: String
    let bodyPreview: String
    let date: Date
    let type: NotificationType
    let icon: String

    static let seededNotifications: [AppNotification] = [
        AppNotification(
            id: UUID(),
            title: "Valentines Day Card",
            bodyPreview: "For Jinky",
            date: Date(),
            type: .valentinesCard,
            icon: "heart.fill"
        )
    ]
}
