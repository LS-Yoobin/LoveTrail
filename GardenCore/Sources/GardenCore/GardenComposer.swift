import Foundation

/// Turns loving acts into renderable garden elements. Pure and deterministic:
/// the same acts always produce the same elements, including stable positions
/// seeded by each act's UUID (so the garden never reshuffles across launches).
public struct GardenComposer {
    public init() {}

    public func compose(acts: [GardenActInput]) -> [GardenElement] {
        acts.map { element(for: $0) }
    }

    private func element(for act: GardenActInput) -> GardenElement {
        switch act.kind {
        case .basicMilestone:
            let threshold = GardenMilestoneBloomComposer.basicMilestoneThreshold(for: act.id)
                ?? GardenMilestoneBloomComposer.basicMomentInterval
            return GardenElement(
                sourceID: act.id,
                kind: .flower,
                date: act.date,
                position: Self.positionForBasicMilestone(threshold: threshold),
                chapter: BloomChapterResolver.chapter(forBasicMilestone: threshold),
                shape: .daisy12,
                isLegend: false,
                cycle: 0
            )

        case .milestone50:
            return shrineElement(for: act, milestone: GardenMilestoneBloomComposer.milestone50Count)

        case .milestone100:
            return shrineElement(for: act, milestone: GardenMilestoneBloomComposer.milestone100Count)

        case .birthday:
            return GardenElement(
                sourceID: act.id,
                kind: .birthdayFlower,
                date: act.date,
                position: Self.position(for: act.id),
                chapter: .birthday,
                shape: .daisy12,
                isLegend: false,
                cycle: 0
            )

        case .anniversary:
            return GardenElement(
                sourceID: act.id,
                kind: .anniversaryFlower,
                date: act.date,
                position: Self.position(for: act.id),
                chapter: .anniversary,
                shape: .lotus8,
                isLegend: false,
                cycle: 0
            )

        case .letter:
            return GardenElement(
                sourceID: act.id,
                kind: .tree,
                date: act.date,
                position: Self.position(for: act.id),
                chapter: .white,
                shape: .classic6,
                isLegend: false,
                cycle: 0
            )

        case .moment, .place:
            return GardenElement(
                sourceID: act.id,
                kind: act.kind == .place ? .placeFlower : .flower,
                date: act.date,
                position: Self.position(for: act.id),
                chapter: .white,
                shape: act.kind == .place ? .place5 : .classic6,
                isLegend: false,
                cycle: 0
            )
        }
    }

    private func shrineElement(for act: GardenActInput, milestone: Int) -> GardenElement {
        GardenElement(
            sourceID: act.id,
            kind: .flower,
            date: act.date,
            position: BloomChapterResolver.legendPosition(milestone: milestone),
            chapter: BloomChapterResolver.legendChapter(milestone: milestone),
            shape: BloomChapterResolver.shape(for: act.kind, isLegend: true, milestone: milestone),
            isLegend: true,
            cycle: 0
        )
    }

    static func elementKind(for actKind: GardenActKind) -> GardenElementKind {
        switch actKind {
        case .basicMilestone, .milestone50, .milestone100, .moment:
            return .flower
        case .birthday:
            return .birthdayFlower
        case .anniversary:
            return .anniversaryFlower
        case .place:
            return .placeFlower
        case .letter:
            return .tree
        }
    }

    /// Scattered naturally across the full green hill — not clustered on one side.
    static func positionForBasicMilestone(threshold: Int) -> GardenPoint {
        let slot = threshold / GardenMilestoneBloomComposer.basicMomentInterval
        let seed = scatteredSeed(forBasicMilestone: threshold)
        let phi = 0.6180339887498949

        // Golden-ratio slots spread evenly in x/y; jitter keeps it organic, not gridded.
        let jitterX = (jitterUnit(seed: seed, salt: 1) - 0.5) * 0.14
        let jitterY = (jitterUnit(seed: seed, salt: 2) - 0.5) * 0.12
        let xUnit = wrappedUnit(Double(slot) * phi + jitterX)
        let yUnit = wrappedUnit(Double(slot) * phi * 1.713 + jitterY)

        return GardenPoint(
            x: 0.06 + xUnit * 0.88,
            y: 0.10 + yUnit * 0.30
        )
    }

    private static func scatteredSeed(forBasicMilestone threshold: Int) -> UInt64 {
        var hash = fnv1a(GardenMilestoneBloomComposer.basicMilestoneID(threshold: threshold))
        hash ^= UInt64(threshold) &* 0x9E3779B97F4A7C15
        hash = hash &* 0x100000001b3
        hash ^= hash >> 33
        hash = hash &* 0xFF51AFD7ED558CCD
        hash ^= hash >> 33
        return hash
    }

    private static func jitterUnit(seed: UInt64, salt: UInt64) -> Double {
        var h = seed ^ (salt &* 0x9E3779B97F4A7C15)
        h = h &* 0x100000001b3
        h ^= h >> 33
        return Double(UInt32(truncatingIfNeeded: h)) / Double(UInt32.max)
    }

    private static func wrappedUnit(_ value: Double) -> Double {
        var unit = value.truncatingRemainder(dividingBy: 1.0)
        if unit < 0 { unit += 1.0 }
        return unit
    }

    /// Deterministic position in the planting band, seeded by the act's UUID.
    /// x spans 0.05...0.95, y is constrained to a low ground band 0.08...0.42.
    static func position(for id: UUID) -> GardenPoint {
        position(fromSeed: fnv1a(id))
    }

    private static func position(fromSeed seed: UInt64) -> GardenPoint {
        let xBits = UInt32(truncatingIfNeeded: seed)
        let yBits = UInt32(truncatingIfNeeded: seed >> 32)
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
