import Foundation
import GardenCore

/// Converts relationship activity into sparse, milestone-based garden acts.
enum GardenActMapper {
    struct Context {
        var moments: [Moment] = []
        var promptMemories: [PromptMemory] = []
        var letters: [UserLetter] = []
        var specialDates: [SpecialDate] = []
        var officialDate: Date?
        var firstMetDate: Date?
        var now: Date = Date()
    }

    static func acts(context: Context) -> [GardenActInput] {
        var result = GardenMilestoneBloomComposer().acts(from: bloomSchedule(from: context))
        for letter in context.letters {
            result.append(
                GardenActInput(
                    id: letter.id,
                    date: letter.sortDate,
                    kind: .letter
                )
            )
        }
        return result
    }

    static func acts(moments: [Moment], letters: [UserLetter]) -> [GardenActInput] {
        acts(context: Context(moments: moments, letters: letters))
    }

    static func bloomActIDs(context: Context) -> [UUID] {
        acts(context: context).map(\.id)
    }

    static func bloomActIDs(moments: [Moment], letters: [UserLetter]) -> [UUID] {
        bloomActIDs(context: Context(moments: moments, letters: letters))
    }

    static func composeElements(context: Context) -> [GardenElement] {
        GardenComposer().compose(acts: acts(context: context))
    }

    static func composeElements(moments: [Moment], letters: [UserLetter]) -> [GardenElement] {
        composeElements(context: Context(moments: moments, letters: letters))
    }

    static func composeElements(
        moments: [Moment],
        letters: [UserLetter],
        specialDates: [SpecialDate],
        officialDate: Date?,
        firstMetDate: Date?,
        now: Date = Date()
    ) -> [GardenElement] {
        composeElements(
            context: Context(
                moments: moments,
                letters: letters,
                specialDates: specialDates,
                officialDate: officialDate,
                firstMetDate: firstMetDate,
                now: now
            )
        )
    }

    /// Matches the Couple Profile "Places" stat — not raw photo count.
    static func gardenMilestoneCount(from context: Context) -> Int {
        GardenMemoryClusterCounter().count(
            moments: travelInputs(from: context.moments.filter { !isFoundingMoment($0) }),
            prompts: promptTravelInputs(from: context.promptMemories)
        )
    }

    static func gardenMilestoneCount(from moments: [Moment]) -> Int {
        gardenMilestoneCount(from: Context(moments: moments))
    }

    private static func bloomSchedule(from context: Context) -> GardenBloomScheduleInput {
        GardenBloomScheduleInput(
            unlockedMomentCount: gardenMilestoneCount(from: context),
            birthdays: birthdayInputs(from: context.specialDates),
            anniversaryDate: anniversaryDate(
                specialDates: context.specialDates,
                officialDate: context.officialDate
            ),
            relationshipAnchor: relationshipAnchor(from: context),
            now: context.now
        )
    }

    private static func bloomEligibleMoments(_ moments: [Moment]) -> [Moment] {
        moments.filter { !$0.isLocked }
    }

    private static func isFoundingMoment(_ moment: Moment) -> Bool {
        moment.promptText == "When we first met"
            || moment.promptText == "When we became official"
    }

    private static func relationshipAnchor(from context: Context) -> Date? {
        if let officialDate = context.officialDate {
            return officialDate
        }
        if let firstMetDate = context.firstMetDate {
            return firstMetDate
        }
        return bloomEligibleMoments(context.moments)
            .map(\.dateTaken)
            .min()
    }

    private static func birthdayInputs(from specialDates: [SpecialDate]) -> [GardenBirthdayInput] {
        specialDates
            .filter(\.isBirthday)
            .map {
                GardenBirthdayInput(
                    personID: $0.id,
                    date: $0.date,
                    title: $0.title
                )
            }
    }

    private static func anniversaryDate(specialDates: [SpecialDate], officialDate: Date?) -> Date? {
        if let titled = specialDates.first(where: isAnniversaryTitle)?.date {
            return titled
        }
        return officialDate
    }

    private static func isAnniversaryTitle(_ specialDate: SpecialDate) -> Bool {
        guard !specialDate.isBirthday else { return false }
        let normalized = SpecialDate.normalizedTitleForMatching(specialDate.title)
        return normalized.contains("anniversary")
    }

    static func persistedContext(
        moments: [Moment],
        promptMemories: [PromptMemory] = [],
        dpm: DataPersistenceManager = .shared,
        now: Date = Date()
    ) -> Context {
        Context(
            moments: moments,
            promptMemories: promptMemories.isEmpty ? dpm.loadPromptMemories() : promptMemories,
            letters: dpm.loadUserLetters(),
            specialDates: dpm.loadCoupleProfile().specialDates,
            officialDate: dpm.loadFoundingPhotoDate(promptText: "When we became official"),
            firstMetDate: dpm.loadFoundingPhotoDate(promptText: "When we first met"),
            now: now
        )
    }

    private static func travelInputs(from moments: [Moment]) -> [TravelMemoryInput] {
        moments.map {
            TravelMemoryInput(
                dateTaken: $0.dateTaken,
                placeName: $0.placeName,
                country: $0.country,
                latitude: $0.latitude,
                longitude: $0.longitude,
                isPlaceNameUserSet: $0.isPlaceNameUserSet
            )
        }
    }

    private static func promptTravelInputs(from memories: [PromptMemory]) -> [TravelMemoryInput] {
        memories.map {
            TravelMemoryInput(
                dateTaken: $0.date,
                placeName: $0.placeName,
                country: nil,
                latitude: $0.latitude,
                longitude: $0.longitude,
                isPlaceNameUserSet: $0.isPlaceNameUserSet
            )
        }
    }
}
