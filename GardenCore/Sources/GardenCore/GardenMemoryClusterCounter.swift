import Foundation

/// Counts memories the same way the Couple Profile "Places" stat does:
/// unique day + place clusters with coordinates, plus offline timeline clusters.
public struct GardenMemoryClusterCounter {
    public init() {}

    public func count(
        moments: [TravelMemoryInput],
        prompts: [TravelMemoryInput] = []
    ) -> Int {
        let places = TravelHistoryStatsComposer().compose(moments: moments, prompts: prompts).places

        let offlineMoments = moments.filter { !hasCoordinates($0) }
        let offlinePrompts = prompts.filter { !hasCoordinates($0) }
        let offlineClusters = offlineTimelineClusters(moments: offlineMoments, prompts: offlinePrompts)

        return places + offlineClusters
    }

    private func hasCoordinates(_ memory: TravelMemoryInput) -> Bool {
        memory.latitude != nil && memory.longitude != nil
    }

    /// Groups non-geotagged memories by calendar day (LA) for a single cluster each.
    private func offlineTimelineClusters(
        moments: [TravelMemoryInput],
        prompts: [TravelMemoryInput]
    ) -> Int {
        guard let laTimeZone = TimeZone(identifier: "America/Los_Angeles") else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = laTimeZone

        var days = Set<Date>()
        for memory in moments + prompts {
            days.insert(calendar.startOfDay(for: memory.dateTaken))
        }
        return days.count
    }
}
