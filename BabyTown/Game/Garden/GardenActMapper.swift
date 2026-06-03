import Foundation
import GardenCore

/// Converts saved timeline moments and love letters into garden acts. At most one
/// flower per calendar day when moments are saved; each letter grows a tree.
enum GardenActMapper {
    static func acts(moments: [Moment], letters: [UserLetter]) -> [GardenActInput] {
        var result = GardenMomentBloomComposer().acts(
            from: bloomEligibleMoments(moments).map(momentInput)
        )
        for letter in letters {
            result.append(GardenActInput(
                id: letter.id,
                date: letter.sortDate,
                kind: .letter
            ))
        }
        return result
    }

    static func bloomActIDs(moments: [Moment], letters: [UserLetter]) -> [UUID] {
        acts(moments: moments, letters: letters).map(\.id)
    }

    private static func bloomEligibleMoments(_ moments: [Moment]) -> [Moment] {
        moments.filter { !$0.isLocked }
    }

    private static func momentInput(_ moment: Moment) -> GardenMomentInput {
        let trimmed = moment.placeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return GardenMomentInput(
            id: moment.id,
            dateTaken: moment.dateTaken,
            hasDistinctPlace: !trimmed.isEmpty
        )
    }
}
