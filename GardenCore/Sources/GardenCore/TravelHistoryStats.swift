import Foundation

/// UI-free snapshot of one memory location for travel stats.
public struct TravelMemoryInput: Equatable, Sendable {
    public let dateTaken: Date
    public let placeName: String?
    public let country: String?
    public let latitude: Double?
    public let longitude: Double?
    public let isPlaceNameUserSet: Bool

    public init(dateTaken: Date,
                placeName: String?,
                country: String?,
                latitude: Double?,
                longitude: Double?,
                isPlaceNameUserSet: Bool) {
        self.dateTaken = dateTaken
        self.placeName = placeName
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.isPlaceNameUserSet = isPlaceNameUserSet
    }
}

public struct TravelHistoryStats: Equatable, Sendable {
    public let countries: Int
    public let cities: Int
    public let places: Int

    public init(countries: Int, cities: Int, places: Int) {
        self.countries = countries
        self.cities = cities
        self.places = places
    }
}

/// Computes countries, cities, and unique place clusters from memory inputs.
public struct TravelHistoryStatsComposer {
    public init() {}

    public func compose(moments: [TravelMemoryInput],
                        prompts: [TravelMemoryInput]) -> TravelHistoryStats {
        let all = moments + prompts
        let countries: Set<String> = Set(
            all.compactMap { entry -> String? in
                guard let raw = entry.country?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !raw.isEmpty else { return nil }
                return raw.lowercased()
            }
        )

        var placeKeys = Set<String>()
        for entry in all {
            guard entry.latitude != nil, entry.longitude != nil else { continue }
            let day = Calendar.current.startOfDay(for: entry.dateTaken).timeIntervalSince1970
            let place = entry.placeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            placeKeys.insert("\(day)|\(place)")
        }

        var cities = Set<String>()
        for entry in all {
            guard !entry.isPlaceNameUserSet,
                  let city = Self.city(from: entry.placeName) else { continue }
            cities.insert(city.lowercased())
        }

        return TravelHistoryStats(
            countries: countries.count,
            cities: cities.count,
            places: placeKeys.count
        )
    }

    /// Extracts a city token from `"City, ST"` or `"City, State"` style place names.
    static func city(from placeName: String?) -> String? {
        guard let raw = placeName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }

        let parts = raw.split(separator: ",", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return parts[0]
    }
}
