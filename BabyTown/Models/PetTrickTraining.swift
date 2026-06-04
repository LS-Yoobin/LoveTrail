import Foundation

/// Voice-command tricks the cat can learn, in unlock order (easiest → hardest).
enum PetTrick: String, Codable, CaseIterable, Identifiable {
    case paw
    case highFive
    case up
    case spin
    case down
    case sayHi

    var id: String { rawValue }

    /// Display name shown in the Trick Book.
    var displayName: String {
        switch self {
        case .paw:       return "Paw"
        case .highFive:  return "High-Five"
        case .up:        return "Up"
        case .spin:      return "Spin"
        case .down:      return "Down"
        case .sayHi:     return "Speak"
        }
    }

    /// SpriteKit atlas frame prefix(es). Spin uses two frames.
    var atlasPrefix: String {
        switch self {
        case .paw:       return "paw_"
        case .highFive:  return "highFive_"
        case .up:        return "up_"
        case .spin:      return "spin_"
        case .down:      return "down_"
        case .sayHi:     return "sayHi_"
        }
    }

    /// Phrases the speech recognizer listens for (lowercased).
    var voicePhrases: [String] {
        switch self {
        case .paw:       return ["paw", "paul", "poor", "give paw", "shake"]
        case .highFive:  return [
            "high five", "high-five", "highfive", "high 5", "high5",
            "gh five", "gh 5", "gh5", "hive five", "hai five",
        ]
        case .up:        return ["up", "stand up", "stand"]
        case .spin:      return ["spin", "turn around", "turn"]
        case .down:      return ["down", "lay down", "lie down"]
        case .sayHi:     return ["speak", "say speak", "say hi", "say hello", "hello", "hi"]
        }
    }

    /// Fixed unlock sequence.
    static let unlockOrder: [PetTrick] = [.paw, .highFive, .up, .spin, .down, .sayHi]

    /// The trick that must be practiced before this one unlocks.
    var prerequisite: PetTrick? {
        guard let idx = Self.unlockOrder.firstIndex(of: self), idx > 0 else { return nil }
        return Self.unlockOrder[idx - 1]
    }

    /// Successful performances on the prerequisite trick required to unlock this trick.
    var unlockSuccessesRequired: Int {
        switch self {
        case .paw:       return 0
        case .highFive:  return 15
        case .up:        return 15
        case .spin:      return 12
        case .down:      return 10
        case .sayHi:     return 10
        }
    }

    /// Minimum level on the prerequisite trick before unlock progress counts.
    var prerequisiteMinLevel: Int {
        switch self {
        case .paw: return 0
        default:   return 2
        }
    }

    /// Asset-catalog icon for the Trick Book (calico art as reference sheet).
    var bookIconAsset: String { "trick_icon_\(rawValue)" }

    /// SF Symbol shown in the Trick Book and progress alerts.
    var symbolName: String {
        switch self {
        case .paw:       return "hand.point.up.left.fill"
        case .highFive:  return "hands.clap.fill"
        case .up:        return "arrow.up.circle.fill"
        case .spin:      return "arrow.triangle.2.circlepath"
        case .down:      return "arrow.down.circle.fill"
        case .sayHi:     return "bubble.left.fill"
        }
    }
}

/// Training constants — unlock gates, level thresholds, and obedience rates.
enum PetTrickTrainingRules {
    static let maxLevel = 10

    /// Cumulative successful performances needed to reach each level (index = level − 1).
    /// Level 1 starts at 0 successes; level 10 requires 110 total successes on that trick.
    static let levelSuccessThresholds: [Int] = [0, 5, 12, 20, 30, 42, 56, 72, 90, 110]

    /// Probability the cat obeys a voice command at the given training level.
    /// Level 1 ≈ 28%, level 10 = 100%.
    static func obedienceRate(level: Int) -> Double {
        let clamped = min(maxLevel, max(1, level))
        return min(1.0, 0.28 + Double(clamped - 1) * (0.72 / Double(maxLevel - 1)))
    }

    /// Extra obey chance from treats given right after a successful trick (persisted per trick).
    static let snackReinforcementObediencePerTreat: Double = 0.03
    static let maxSnackReinforcementObedienceBonus: Double = 0.18
    static let maxSnackReinforcementsStored = 6

    /// Window after a successful trick during which a snack counts as reinforcement.
    static let snackReinforcementWindow: TimeInterval = 50

    /// Bonus rep and Smart XP when a snack reinforces a trick that was just performed.
    static let snackReinforcementBonusSuccesses = 1
    static let snackReinforcementSmartXP = 6

    static func effectiveObedienceRate(level: Int, snackReinforcements: Int) -> Double {
        let bonus = min(
            maxSnackReinforcementObedienceBonus,
            Double(snackReinforcements) * snackReinforcementObediencePerTreat
        )
        return min(1.0, obedienceRate(level: level) + bonus)
    }

    /// Derives the training level from total successful performances.
    static func level(forSuccesses successes: Int) -> Int {
        var level = 1
        for (idx, threshold) in levelSuccessThresholds.enumerated() where idx > 0 {
            if successes >= threshold { level = idx + 1 }
        }
        return min(maxLevel, level)
    }

    /// Successes still needed to reach the next level (nil if already max).
    static func successesUntilNextLevel(currentSuccesses: Int, currentLevel: Int) -> Int? {
        guard currentLevel < maxLevel else { return nil }
        let nextThreshold = levelSuccessThresholds[currentLevel]
        return max(0, nextThreshold - currentSuccesses)
    }
}

/// Smart Meter — overall training mastery across all tricks (voice reps, level-ups, unlocks).
/// Max level 15 is calibrated so reaching it means every trick has been mastered at Lv 10.
enum PetSmartMeterRules {
    static let maxLevel = 15

    /// XP for one successful voice-command rep; harder tricks pay slightly more.
    static func successXP(for trick: PetTrick) -> Int {
        let index = PetTrick.unlockOrder.firstIndex(of: trick) ?? 0
        return 8 + index   // Paw 8 … Speak 13
    }

    static let levelUpXP = 35
    static let unlockXP = 80

    /// Bonus coins when a new trick unlocks (Paw starts unlocked — no bonus).
    static func unlockBonusCoins(for trick: PetTrick) -> Int {
        switch trick {
        case .paw:       return 0
        case .highFive:  return 10
        case .up:        return 12
        case .spin:      return 15
        case .down:      return 18
        case .sayHi:     return 25
        }
    }

    /// Total XP from mastering all six tricks (110 reps × 6, all level-ups, all unlocks).
    static var totalMaxXP: Int {
        var total = 0
        let maxSuccesses = PetTrickTrainingRules.levelSuccessThresholds.last ?? 110
        for trick in PetTrick.allCases {
            total += successXP(for: trick) * maxSuccesses
            total += (PetTrickTrainingRules.maxLevel - 1) * levelUpXP
            if trick != .paw { total += unlockXP }
        }
        return total
    }

    /// Cumulative XP needed for each Smart Meter level (index = level − 1).
    static let levelXPThresholds: [Int] = {
        let total = totalMaxXP
        let levels = maxLevel
        let weightSum = (levels - 1) * levels / 2
        var thresholds = [0]
        var accumulated = 0
        for step in 1..<levels {
            accumulated += (total * step) / max(1, weightSum)
            thresholds.append(accumulated)
        }
        if thresholds.count == levels {
            thresholds[levels - 1] = total
        }
        return thresholds
    }()

    static func level(forXP xp: Int) -> Int {
        var level = 1
        for (idx, threshold) in levelXPThresholds.enumerated() where idx > 0 {
            if xp >= threshold { level = idx + 1 }
        }
        return min(maxLevel, level)
    }

    static func xpUntilNextLevel(currentXP: Int, currentLevel: Int) -> Int? {
        guard currentLevel < maxLevel else { return nil }
        let nextThreshold = levelXPThresholds[currentLevel]
        return max(0, nextThreshold - currentXP)
    }

    /// 0…1 progress within the current Smart Meter level.
    static func progressFraction(currentXP: Int, currentLevel: Int) -> Double {
        guard currentLevel < maxLevel else { return 1 }
        let levelStart = levelXPThresholds[currentLevel - 1]
        let levelEnd = levelXPThresholds[currentLevel]
        let span = max(1, levelEnd - levelStart)
        return min(1, max(0, Double(currentXP - levelStart) / Double(span)))
    }

    /// Back-fills Smart Meter XP for saves that predate this field.
    static func estimatedXP(from state: PetTrickTrainingState) -> Int {
        var xp = 0
        for trick in PetTrick.allCases {
            let progress = state.progress(for: trick)
            xp += successXP(for: trick) * progress.successes
            if progress.level > 1 {
                xp += (progress.level - 1) * levelUpXP
            }
            if trick != .paw, state.isUnlocked(trick) {
                xp += unlockXP
            }
        }
        return xp
    }
}

/// Rewards surfaced to the UI after a trick training action.
struct TrickTrainingRewards: Equatable {
    var smartMeterXP: Int = 0
    var coins: Int = 0
}

/// Per-trick progress persisted on `PetState`.
struct PetTrickProgress: Codable, Equatable {
    var isUnlocked: Bool
    var successes: Int
    /// Treats given right after a successful performance — raises obey rate for this trick.
    var snackReinforcements: Int

    init(isUnlocked: Bool = false, successes: Int = 0, snackReinforcements: Int = 0) {
        self.isUnlocked = isUnlocked
        self.successes = successes
        self.snackReinforcements = snackReinforcements
    }

    var level: Int {
        PetTrickTrainingRules.level(forSuccesses: successes)
    }

    var obedienceRate: Double {
        PetTrickTrainingRules.effectiveObedienceRate(
            level: level,
            snackReinforcements: snackReinforcements
        )
    }

    enum CodingKeys: String, CodingKey {
        case isUnlocked, successes, snackReinforcements
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isUnlocked = try c.decode(Bool.self, forKey: .isUnlocked)
        successes = try c.decode(Int.self, forKey: .successes)
        snackReinforcements = try c.decodeIfPresent(Int.self, forKey: .snackReinforcements) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(isUnlocked, forKey: .isUnlocked)
        try c.encode(successes, forKey: .successes)
        try c.encode(snackReinforcements, forKey: .snackReinforcements)
    }
}

/// All trick training progress for the adopted pet.
struct PetTrickTrainingState: Codable, Equatable {
    var progress: [String: PetTrickProgress]
    /// Cumulative Smart Meter XP from tricks and snack reinforcement.
    var smartMeterXP: Int

    init() {
        var p: [String: PetTrickProgress] = [:]
        for trick in PetTrick.allCases {
            p[trick.rawValue] = PetTrickProgress(isUnlocked: trick == .paw)
        }
        self.progress = p
        self.smartMeterXP = 0
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        progress = try c.decodeIfPresent([String: PetTrickProgress].self, forKey: .progress) ?? PetTrickTrainingState().progress
        smartMeterXP = try c.decodeIfPresent(Int.self, forKey: .smartMeterXP) ?? 0
        if progress[PetTrick.paw.rawValue]?.isUnlocked != true {
            progress[PetTrick.paw.rawValue] = PetTrickProgress(isUnlocked: true, successes: progress[PetTrick.paw.rawValue]?.successes ?? 0)
        }
        migrateSmartMeterXPIfNeeded()
    }

    private mutating func migrateSmartMeterXPIfNeeded() {
        guard smartMeterXP == 0 else { return }
        let hasProgress = progress.values.contains { $0.successes > 0 }
            || PetTrick.unlockOrder.dropFirst().contains { progress[$0.rawValue]?.isUnlocked == true }
        guard hasProgress else { return }
        smartMeterXP = PetSmartMeterRules.estimatedXP(from: self)
    }

    var smartMeterLevel: Int {
        PetSmartMeterRules.level(forXP: smartMeterXP)
    }

    mutating func addSmartMeterXP(_ amount: Int) {
        guard amount > 0 else { return }
        smartMeterXP += amount
    }

    func progress(for trick: PetTrick) -> PetTrickProgress {
        progress[trick.rawValue] ?? PetTrickProgress(isUnlocked: trick == .paw)
    }

    mutating func setProgress(_ value: PetTrickProgress, for trick: PetTrick) {
        progress[trick.rawValue] = value
    }

    /// Whether the trick is unlocked and available to practice.
    func isUnlocked(_ trick: PetTrick) -> Bool {
        progress(for: trick).isUnlocked
    }

    /// Checks if a locked trick meets its unlock requirements.
    func unlockProgress(for trick: PetTrick) -> (current: Int, required: Int, prerequisiteName: String?)? {
        guard !isUnlocked(trick), trick != .paw else { return nil }
        guard let prereq = trick.prerequisite else { return nil }
        let prereqProgress = progress(for: prereq)
        guard prereqProgress.level >= trick.prerequisiteMinLevel else {
            return (prereqProgress.successes, trick.unlockSuccessesRequired, prereq.displayName)
        }
        return (prereqProgress.successes, trick.unlockSuccessesRequired, prereq.displayName)
    }

    /// Attempts to unlock tricks whose prerequisites are satisfied.
    mutating func refreshUnlocks() {
        for trick in PetTrick.unlockOrder where !isUnlocked(trick) {
            guard let prereq = trick.prerequisite else { continue }
            let prereqProgress = progress(for: prereq)
            guard prereqProgress.level >= trick.prerequisiteMinLevel,
                  prereqProgress.successes >= trick.unlockSuccessesRequired else { continue }
            var unlocked = progress(for: trick)
            unlocked.isUnlocked = true
            setProgress(unlocked, for: trick)
        }
    }

    /// Maps common speech-recognition mishears to the command the user likely said.
    static func displayTranscript(_ transcript: String) -> String {
        var text = transcript
        let corrections: [(pattern: String, replacement: String)] = [
            (#"\b(?:gh|hive|hai)\s+five\b"#, "High Five"),
            (#"\bgh5\b"#, "High Five"),
            (#"\bgh\s+5\b"#, "High Five"),
            (#"\bhigh\s*[-]?\s*5\b"#, "High Five"),
            (#"\bhighfive\b"#, "High Five"),
            (#"\bpaul\b"#, "Paw"),
            (#"\bpoor\b"#, "Paw"),
        ]
        for (pattern, replacement) in corrections {
            text = text.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return text
    }

    /// Maps recognized speech text to a trick, if any phrase matches.
    /// Longer phrases win (e.g. "high five" over "hi") and short tokens use word boundaries
    /// so "hi" does not match inside "high five".
    /// Pass `isFinal: false` while streaming partial ASR — bare `"hi"` waits for finalize
    /// so an in-progress "high five" doesn't accidentally trigger Speak.
    static func trick(matching transcript: String, isFinal: Bool = true) -> PetTrick? {
        guard let match = bestPhraseMatch(in: transcript) else { return nil }
        if !isFinal && match.phrase == "hi" { return nil }
        return match.trick
    }

    private static func bestPhraseMatch(in transcript: String) -> (trick: PetTrick, phrase: String)? {
        let normalized = normalizedTranscript(transcript)
        guard !normalized.isEmpty else { return nil }

        var best: (trick: PetTrick, phrase: String)?
        for trick in PetTrick.allCases {
            for phrase in trick.voicePhrases {
                guard phraseRange(phrase, in: normalized) != nil else { continue }
                if best == nil || phrase.count > best!.phrase.count {
                    best = (trick, phrase)
                }
            }
        }
        return best
    }

    private static func phraseRange(_ phrase: String, in normalized: String) -> Range<String.Index>? {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern: String
        if phrase.contains(" ") {
            pattern = "(?:^|\\s)\(escaped)(?:\\s|$)"
        } else {
            pattern = "\\b\(escaped)\\b"
        }
        return normalized.range(of: pattern, options: .regularExpression)
    }

    private static func normalizedTranscript(_ transcript: String) -> String {
        var text = transcript.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let mishearToCanonical: [(pattern: String, replacement: String)] = [
            (#"\b(?:gh|hive|hai)\s+five\b"#, "high five"),
            (#"\bgh5\b"#, "high five"),
            (#"\bgh\s+5\b"#, "high five"),
            (#"\bhigh\s*5\b"#, "high five"),
            (#"\bhighfive\b"#, "high five"),
            (#"\bhigh5\b"#, "high five"),
        ]
        for (pattern, replacement) in mishearToCanonical {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return text
    }
}
