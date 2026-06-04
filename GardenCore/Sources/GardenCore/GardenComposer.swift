import Foundation

/// Turns loving acts into renderable garden elements. Pure and deterministic:
/// the same acts always produce the same elements, including stable positions
/// seeded by each act's UUID (so the garden never reshuffles across launches).
public struct GardenComposer {
    public init() {}

    public func compose(
        acts: [GardenActInput],
        momentOrdinalByActID: [UUID: Int] = [:],
        totalMomentCount: Int = 0
    ) -> [GardenElement] {
        var elements = acts.map { act in
            element(for: act, momentOrdinalByActID: momentOrdinalByActID)
        }
        elements.append(contentsOf: Self.legendElements(totalMomentCount: totalMomentCount))
        return elements
    }

    private func element(
        for act: GardenActInput,
        momentOrdinalByActID: [UUID: Int]
    ) -> GardenElement {
        let kind = Self.elementKind(for: act.kind)
        let ordinal = momentOrdinalByActID[act.id] ?? 1
        let chapter = BloomChapterResolver.chapter(forMomentOrdinal: ordinal)
        let cycle = BloomChapterResolver.cycle(forMomentOrdinal: ordinal)
        let shape = BloomChapterResolver.shape(for: act.kind, isLegend: false, milestone: nil)
        return GardenElement(
            sourceID: act.id,
            kind: kind,
            date: act.date,
            position: Self.position(for: act.id),
            chapter: kind == .tree ? .white : chapter,
            shape: kind == .placeFlower ? .place5 : shape,
            isLegend: false,
            cycle: cycle
        )
    }

    static func legendElements(totalMomentCount: Int) -> [GardenElement] {
        BloomChapterResolver.legendMilestones.compactMap { milestone in
            guard totalMomentCount >= milestone else { return nil }
            return GardenElement(
                sourceID: BloomChapterResolver.legendID(milestone: milestone),
                kind: .flower,
                date: .distantPast,
                position: BloomChapterResolver.legendPosition(milestone: milestone),
                chapter: BloomChapterResolver.legendChapter(milestone: milestone),
                shape: BloomChapterResolver.shape(for: .moment, isLegend: true, milestone: milestone),
                isLegend: true,
                cycle: 0
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

    /// Deterministic position in the planting band, seeded by the act's UUID.
    /// x spans 0.05...0.95, y is constrained to a low ground band 0.08...0.42.
    static func position(for id: UUID) -> GardenPoint {
        let h = fnv1a(id)
        let xBits = UInt32(truncatingIfNeeded: h)
        let yBits = UInt32(truncatingIfNeeded: h >> 32)
        let xUnit = Double(xBits) / Double(UInt32.max)
        let yUnit = Double(yBits) / Double(UInt32.max)
        let x = 0.05 + xUnit * 0.90
        let y = 0.08 + yUnit * 0.34
        return GardenPoint(x: x, y: y)
    }

    /// Fixed FNV-1a over the UUID's 16 raw bytes (NOT Swift's randomized Hasher),
    /// so the value is identical across processes and launches.
    static func fnv1a(_ id: UUID) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        let b = id.uuid
        let bytes = [b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7,
                     b.8, b.9, b.10, b.11, b.12, b.13, b.14, b.15]
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }
}
