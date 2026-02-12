import Foundation

struct DaySection: Identifiable {
    let date: Date
    let moments: [Moment]

    var id: Date { date }

    var displayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    var placeDisplay: String {
        moments.compactMap(\.placeName).first ?? "Somewhere with you"
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
            calendar.startOfDay(for: moment.dateTaken)
        }

        return grouped.map { date, dayMoments in
            DaySection(
                date: date,
                moments: dayMoments.sorted { $0.dateTaken < $1.dateTaken }
            )
        }
        .sorted { $0.date > $1.date }
    }
}
