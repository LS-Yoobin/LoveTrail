import Foundation

enum MapPlacesFiltering {

    static func sections(
        from viewModel: HomeViewModel,
        selectedYear: Int,
        selectedCountry: String?,
        searchText: String
    ) -> [DaySection] {
        let base: [DaySection]
        if selectedYear == 0 {
            base = viewModel.memoriesWithLocation()
        } else {
            base = viewModel.memories(forYear: selectedYear)
        }

        return base.filter { section in
            matchesCountry(section, selectedCountry: selectedCountry)
                && matchesSearch(section, query: searchText)
        }
    }

    static func matchesCountry(_ section: DaySection, selectedCountry: String?) -> Bool {
        guard let selectedCountry else { return true }
        return section.moments.contains { $0.country == selectedCountry }
    }

    static func matchesSearch(_ section: DaySection, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return true }
        let place = section.placeDisplay.lowercased()
        let country = section.moments.compactMap(\.country).joined(separator: " ").lowercased()
        let date = section.timeDisplay.lowercased()
        return place.contains(trimmed) || country.contains(trimmed) || date.contains(trimmed)
    }
}

