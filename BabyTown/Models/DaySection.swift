import Foundation

private struct DayPlaceKey: Hashable {
    let date: Date
    let placeName: String
}

struct DaySection: Identifiable {
    let date: Date
    let placeName: String?
    let moments: [Moment]

    var id: String {
        "\(date.timeIntervalSince1970)_\(placeName ?? "")"
    }

    init(date: Date, placeName: String? = nil, moments: [Moment]) {
        self.date = date
        self.placeName = placeName
        self.moments = moments
    }

    var displayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    var placeDisplay: String {
        if let place = placeName, !place.isEmpty {
            return place
        }
        return moments.compactMap(\.placeName).first ?? "Somewhere with you"
    }

    var timeDisplay: String {
        guard let firstMoment = moments.first else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy • h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: firstMoment.dateTaken)
    }

    static func grouped(from moments: [Moment]) -> [DaySection] {
        guard let laTimeZone = TimeZone(identifier: "America/Los_Angeles") else {
            return []
        }

        var calendar = Calendar.current
        calendar.timeZone = laTimeZone

        let grouped = Dictionary(grouping: moments) { moment in
            DayPlaceKey(
                date: calendar.startOfDay(for: moment.dateTaken),
                placeName: moment.placeName ?? ""
            )
        }

        return grouped.map { key, dayMoments in
            DaySection(
                date: key.date,
                placeName: key.placeName.isEmpty ? nil : key.placeName,
                moments: dayMoments.sorted { $0.dateTaken < $1.dateTaken }
            )
        }
        .sorted { $0.date > $1.date }
    }
}
