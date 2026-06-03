import Foundation

/// Keeps computed notification fire-times inside a friendly daytime window so
/// nothing buzzes overnight. Fixed-time scheduled notifications (e.g. 8 AM
/// morning) are not routed through this.
public enum NotificationQuietHours {
    public static let startHour = 9   // 9:00 AM inclusive
    public static let endHour = 21    // 9:00 PM exclusive

    /// Returns `date` if it lands inside [9:00, 21:00); otherwise the next
    /// 9:00 AM (same day if before the window, next day if at/after it).
    public static func clamp(_ date: Date, calendar: Calendar) -> Date {
        let hour = calendar.component(.hour, from: date)
        if hour >= startHour && hour < endHour { return date }
        let base = hour < startHour
            ? date
            : (calendar.date(byAdding: .day, value: 1, to: date) ?? date)
        return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: base) ?? date
    }
}
