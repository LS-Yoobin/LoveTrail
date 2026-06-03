import Foundation
import GardenCore

/// Converts the app's real relationship data (`Moment`, `UserLetter`) into the
/// UI-free `GardenActInput` values GardenCore understands. A moment with a
/// non-empty place becomes a `.place` act; a plain moment becomes `.moment`;
/// every letter becomes `.letter`.
enum GardenActMapper {
    static func acts(moments: [Moment], letters: [UserLetter]) -> [GardenActInput] {
        var result: [GardenActInput] = []

        for moment in moments {
            let hasPlace = (moment.placeName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            result.append(GardenActInput(
                id: moment.id,
                date: moment.dateTaken,
                kind: hasPlace ? .place : .moment
            ))
        }

        for letter in letters {
            result.append(GardenActInput(
                id: letter.id,
                date: letter.sortDate,
                kind: .letter
            ))
        }

        return result
    }
}
