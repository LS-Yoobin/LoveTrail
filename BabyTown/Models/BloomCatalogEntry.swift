import GardenCore

struct BloomCatalogEntry: Identifiable {
    let id: String
    let displayName: String
    let subtitle: String
    let unlockCondition: String
    let isEarned: Bool
    let ownedCount: Int
    let chapter: BloomChapter?
    let shape: BloomShape?
    let isLegend: Bool

    var isTree: Bool { chapter == nil && shape == nil }

    var cacheKey: String {
        guard let chapter, let shape else { return "tree" }
        return "\(chapter.rawValue)-\(shape.rawValue)-\(isLegend)"
    }
}

enum BloomCatalogBuilder {
    static func build(from elements: [GardenElement]) -> [BloomCatalogEntry] {
        let hasBloom = { (chapter: BloomChapter, shape: BloomShape, isLegend: Bool) -> Bool in
            elements.contains {
                $0.chapter == chapter && $0.shape == shape && $0.isLegend == isLegend
            }
        }
        let bloomCount = { (chapter: BloomChapter, shape: BloomShape, isLegend: Bool) -> Int in
            elements.filter {
                $0.chapter == chapter && $0.shape == shape && $0.isLegend == isLegend
            }.count
        }
        return [
            BloomCatalogEntry(
                id: "white-daisy12",
                displayName: "First Bouquet",
                subtitle: "10 memories planted together",
                unlockCondition: "Reach 10 moments",
                isEarned: hasBloom(.white, .daisy12, false),
                ownedCount: bloomCount(.white, .daisy12, false),
                chapter: .white, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "yellow-daisy12",
                displayName: "Sunbeam Bouquet",
                subtitle: "20 memories planted together",
                unlockCondition: "Reach 20 moments",
                isEarned: hasBloom(.yellow, .daisy12, false),
                ownedCount: bloomCount(.yellow, .daisy12, false),
                chapter: .yellow, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "red-daisy12",
                displayName: "Ember Bouquet",
                subtitle: "30 memories planted together",
                unlockCondition: "Reach 30 moments",
                isEarned: hasBloom(.red, .daisy12, false),
                ownedCount: bloomCount(.red, .daisy12, false),
                chapter: .red, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "blue-daisy12",
                displayName: "Horizon Bouquet",
                subtitle: "40 memories planted together",
                unlockCondition: "Reach 40 moments",
                isEarned: hasBloom(.blue, .daisy12, false),
                ownedCount: bloomCount(.blue, .daisy12, false),
                chapter: .blue, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "purple-daisy12",
                displayName: "Twilight Bouquet",
                subtitle: "50 memories planted together",
                unlockCondition: "Reach 50 moments",
                isEarned: hasBloom(.purple, .daisy12, false),
                ownedCount: bloomCount(.purple, .daisy12, false),
                chapter: .purple, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "purple-tulip3-true",
                displayName: "Twilight Shrine",
                subtitle: "Fifty memories in — your garden is truly thriving",
                unlockCondition: "50 memories together",
                isEarned: hasBloom(.purple, .tulip3, true),
                ownedCount: bloomCount(.purple, .tulip3, true),
                chapter: .purple, shape: .tulip3, isLegend: true
            ),
            BloomCatalogEntry(
                id: "black-lotus8-true",
                displayName: "Eclipse Shrine",
                subtitle: "One hundred blooms of us. Legendary",
                unlockCondition: "100 memories together",
                isEarned: hasBloom(.black, .lotus8, true),
                ownedCount: bloomCount(.black, .lotus8, true),
                chapter: .black, shape: .lotus8, isLegend: true
            ),
            BloomCatalogEntry(
                id: "birthday-daisy12",
                displayName: "Birthday Bloom",
                subtitle: "Another candle, another flower",
                unlockCondition: "Add a birthday",
                isEarned: elements.contains { $0.kind == .birthdayFlower },
                ownedCount: elements.filter { $0.kind == .birthdayFlower }.count,
                chapter: .birthday, shape: .daisy12, isLegend: false
            ),
            BloomCatalogEntry(
                id: "anniversary-lotus8",
                displayName: "Anniversary Bloom",
                subtitle: "Another year of us, planted in the garden",
                unlockCondition: "Add your anniversary",
                isEarned: elements.contains { $0.kind == .anniversaryFlower },
                ownedCount: elements.filter { $0.kind == .anniversaryFlower }.count,
                chapter: .anniversary, shape: .lotus8, isLegend: false
            ),
            BloomCatalogEntry(
                id: "tree",
                displayName: "Love Tree",
                subtitle: "A love letter, rooted forever",
                unlockCondition: "Write a love letter",
                isEarned: elements.contains { $0.kind == .tree },
                ownedCount: elements.filter { $0.kind == .tree }.count,
                chapter: nil, shape: nil, isLegend: false
            ),
        ]
    }
}
