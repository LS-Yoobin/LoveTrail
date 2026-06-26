import Foundation
import SwiftUI

enum PlannerStopBadgeStyle {
    case start
    case middle
    case end

    static func forStop(_ stop: ItineraryStop, in stops: [ItineraryStop]) -> PlannerStopBadgeStyle {
        let orders = stops.map(\.order)
        guard let minOrder = orders.min(), let maxOrder = orders.max() else { return .middle }
        if stop.order == minOrder { return .start }
        if stop.order == maxOrder { return .end }
        return .middle
    }

    var fill: AnyShapeStyle {
        switch self {
        case .start: AnyShapeStyle(BabyTownTheme.plannerStopStartGradient)
        case .middle: AnyShapeStyle(BabyTownTheme.accentGradient)
        case .end: AnyShapeStyle(BabyTownTheme.plannerStopEndGradient)
        }
    }

    var color: Color {
        switch self {
        case .start: BabyTownTheme.plannerStopStart
        case .middle: BabyTownTheme.accent
        case .end: BabyTownTheme.plannerStopEnd
        }
    }
}

struct ItineraryStop: Identifiable, Codable {
    let id: UUID
    var order: Int
    var day: Int
    var placeName: String
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var momentID: UUID?
    var photoData: Data?
    var note: String?

    init(
        id: UUID,
        order: Int,
        day: Int = 1,
        placeName: String,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        momentID: UUID? = nil,
        photoData: Data? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.order = order
        self.day = day
        self.placeName = placeName
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.momentID = momentID
        self.photoData = photoData
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        order = try container.decode(Int.self, forKey: .order)
        day = try container.decodeIfPresent(Int.self, forKey: .day) ?? 1
        placeName = try container.decode(String.self, forKey: .placeName)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        momentID = try container.decodeIfPresent(UUID.self, forKey: .momentID)
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}

struct DatePlan: Identifiable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var numberOfDays: Int
    var time: Date?
    var notes: String?
    var coverPhotoData: Data?
    var itinerary: [ItineraryStop]
    let createdByUserID: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        title: String,
        date: Date,
        numberOfDays: Int = 1,
        time: Date? = nil,
        notes: String? = nil,
        coverPhotoData: Data? = nil,
        itinerary: [ItineraryStop] = [],
        createdByUserID: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.numberOfDays = max(1, numberOfDays)
        self.time = time
        self.notes = notes
        self.coverPhotoData = coverPhotoData
        self.itinerary = itinerary
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        numberOfDays = max(1, try container.decodeIfPresent(Int.self, forKey: .numberOfDays) ?? 1)
        time = try container.decodeIfPresent(Date.self, forKey: .time)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        coverPhotoData = try container.decodeIfPresent(Data.self, forKey: .coverPhotoData)
        itinerary = try container.decode([ItineraryStop].self, forKey: .itinerary)
        createdByUserID = try container.decode(String.self, forKey: .createdByUserID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    var isVaulted: Bool {
        !StoreManager.shared.isForeverUnlocked
            && Date().timeIntervalSince(createdAt) > 30 * 24 * 60 * 60
    }

    var endDate: Date {
        let start = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: .day, value: numberOfDays - 1, to: start) ?? start
    }

    var isPast: Bool {
        Calendar.current.startOfDay(for: endDate) < Calendar.current.startOfDay(for: Date())
    }

    var dateRangeLabel: String {
        let start = Calendar.current.startOfDay(for: date)
        if numberOfDays <= 1 {
            return start.formatted(Date.FormatStyle().month(.wide).day().year())
        }
        let startFmt = Date.FormatStyle().month(.abbreviated).day()
        let endFmt = Date.FormatStyle().month(.abbreviated).day().year()
        return "\(start.formatted(startFmt)) – \(endDate.formatted(endFmt))"
    }

    var dateRangeDetailLabel: String {
        let start = Calendar.current.startOfDay(for: date)
        if numberOfDays <= 1 {
            return start.formatted(Date.FormatStyle().weekday(.wide).month(.wide).day())
        }
        let startFmt = Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()
        let endFmt = Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()
        return "\(start.formatted(startFmt)) – \(endDate.formatted(endFmt))"
    }
}

enum PlannerDateRange {
    static let maxDays = 14

    static func dateComponents(for plan: DatePlan) -> Set<DateComponents> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.date)
        var components = Set<DateComponents>()
        for offset in 0..<min(plan.numberOfDays, maxDays) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            components.insert(calendar.dateComponents([.calendar, .year, .month, .day], from: day))
        }
        return components
    }

    static func dateComponents(for day: Date, calendar: Calendar = .current) -> DateComponents {
        calendar.dateComponents([.calendar, .year, .month, .day], from: calendar.startOfDay(for: day))
    }

    static func dateComponents(from start: Date, through end: Date, calendar: Calendar = .current) -> Set<DateComponents> {
        let rangeStart = calendar.startOfDay(for: min(start, end))
        let rangeEnd = calendar.startOfDay(for: max(start, end))
        var dayCount = (calendar.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 0) + 1
        dayCount = min(max(dayCount, 1), maxDays)

        var result = Set<DateComponents>()
        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: rangeStart) else { continue }
            result.insert(dateComponents(for: day, calendar: calendar))
        }
        return result
    }

    /// Google Calendar style: one anchor day, then a second tap fills every day between.
    /// A third tap starts a new single-day selection.
    static func selectionAfterTapping(_ day: Date, currentSelection: Set<DateComponents>) -> Set<DateComponents> {
        let calendar = Calendar.current
        let tapped = calendar.startOfDay(for: day)
        let currentDates = currentSelection
            .compactMap { calendar.date(from: $0) }
            .map { calendar.startOfDay(for: $0) }
            .sorted()

        if currentDates.count <= 1 {
            let anchor = currentDates.first ?? tapped
            if tapped == anchor {
                return Set([dateComponents(for: tapped, calendar: calendar)])
            }
            return dateComponents(from: anchor, through: tapped, calendar: calendar)
        }

        return Set([dateComponents(for: tapped, calendar: calendar)])
    }

    static func normalizedDates(from selection: Set<DateComponents>) -> Set<DateComponents> {
        let calendar = Calendar.current
        let sortedDates = selection
            .compactMap { calendar.date(from: $0) }
            .map { calendar.startOfDay(for: $0) }
            .sorted()

        guard let first = sortedDates.first else { return selection }
        let last = sortedDates.last ?? first
        return dateComponents(from: first, through: last, calendar: calendar)
    }

    static func span(from selection: Set<DateComponents>) -> (start: Date, numberOfDays: Int)? {
        let normalized = normalizedDates(from: selection)
        let calendar = Calendar.current
        let sortedDates = normalized
            .compactMap { calendar.date(from: $0) }
            .map { calendar.startOfDay(for: $0) }
            .sorted()

        guard let start = sortedDates.first else { return nil }
        let dayCount = min(max(sortedDates.count, 1), maxDays)
        return (start, dayCount)
    }

    static func rangeLabel(for selection: Set<DateComponents>) -> String? {
        guard let span = span(from: selection), span.numberOfDays > 1 else { return nil }
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: span.numberOfDays - 1, to: span.start) ?? span.start
        let startFmt = Date.FormatStyle().month(.abbreviated).day()
        let endFmt = Date.FormatStyle().month(.abbreviated).day().year()
        return "\(span.start.formatted(startFmt)) – \(end.formatted(endFmt))"
    }
}
