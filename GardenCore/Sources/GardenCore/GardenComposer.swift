import Foundation

/// Turns loving acts into renderable garden elements. Pure and deterministic:
/// the same acts always produce the same elements (positioning added in Task 3).
public struct GardenComposer {
    public init() {}

    public func compose(acts: [GardenActInput]) -> [GardenElement] {
        acts.map { act in
            GardenElement(
                sourceID: act.id,
                kind: Self.elementKind(for: act.kind),
                date: act.date,
                position: GardenPoint(x: 0, y: 0)
            )
        }
    }

    static func elementKind(for actKind: GardenActKind) -> GardenElementKind {
        switch actKind {
        case .moment: return .flower
        case .place:  return .placeFlower
        case .letter: return .tree
        }
    }
}
