import Foundation

enum MemorySearchMatcher {

    static func matches(moment: Moment, query: String) -> Bool {
        matches(strings: searchableStrings(for: moment), query: query)
    }

    static func matches(promptMemory: PromptMemory, query: String) -> Bool {
        matches(strings: searchableStrings(for: promptMemory), query: query)
    }

    private static func matches(strings: [String], query: String) -> Bool {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return false }

        let haystack = strings
            .map { $0.lowercased() }
            .joined(separator: " ")

        return haystack.contains(normalizedQuery)
    }

    static func searchableStrings(for moment: Moment) -> [String] {
        var strings = dateSearchStrings(for: moment.dateTaken)

        if let placeName = moment.placeName, !placeName.isEmpty {
            strings.append(placeName)
            if let display = PlaceNameFormatting.displayName(raw: placeName, isUserSet: moment.isPlaceNameUserSet) {
                strings.append(display)
            }
        }

        if let caption = moment.caption, !caption.isEmpty {
            strings.append(caption)
        }

        if let promptText = moment.promptText, !promptText.isEmpty {
            strings.append(promptText)
        }

        let section = DaySection(date: moment.dateTaken, placeName: moment.placeName, moments: [moment])
        strings.append(section.displayTitle)
        strings.append(section.placeDisplay)
        strings.append(section.timeDisplay)

        return strings
    }

    static func searchableStrings(for promptMemory: PromptMemory) -> [String] {
        var strings = dateSearchStrings(for: promptMemory.date)
        strings.append(promptMemory.promptText)

        if let placeName = promptMemory.placeName, !placeName.isEmpty {
            strings.append(placeName)
        }

        if !promptMemory.loveNote.isEmpty {
            strings.append(promptMemory.loveNote)
        }

        return strings
    }

    private static func dateSearchStrings(for date: Date) -> [String] {
        var strings: [String] = []
        let calendar = Calendar.current

        let year = calendar.component(.year, from: date)
        let day = calendar.component(.day, from: date)

        strings.append(String(year))
        strings.append(String(day))
        strings.append("\(day)th")
        strings.append("\(day)st")
        strings.append("\(day)nd")
        strings.append("\(day)rd")

        strings.append(date.formatted(.dateTime.month(.wide)))
        strings.append(date.formatted(.dateTime.month(.abbreviated)))
        strings.append(date.formatted(.dateTime.weekday(.wide)))
        strings.append(date.formatted(.dateTime.weekday(.abbreviated)))
        strings.append(date.formatted(.dateTime.month().day().year()))

        let formatter = DateFormatter()
        formatter.locale = Locale.current

        formatter.dateFormat = "EEEE, MMM d"
        strings.append(formatter.string(from: date))

        formatter.dateFormat = "MMM d, yyyy"
        strings.append(formatter.string(from: date))

        formatter.dateFormat = "MMMM d, yyyy"
        strings.append(formatter.string(from: date))

        formatter.dateFormat = "MMM d, yyyy • h:mm a"
        if let laTimeZone = TimeZone(identifier: "America/Los_Angeles") {
            formatter.timeZone = laTimeZone
        }
        strings.append(formatter.string(from: date))

        return strings
    }
}
