import Foundation

/// All tunable constants for the pet care economy live here so balance can be
/// adjusted in one place. Coins are earned-only for now (no real-money packs).
enum PetEconomy {

    // MARK: Starting values

    static let startingCoins = 50
    static let startingFoodServings = 5

    // MARK: Care tasks

    enum CareTask {
        case pet, fillWater, feed, play, cleanLitter, waterPlant

        /// Coins awarded when the task is performed while it's "needed"/off cooldown.
        var coinReward: Int {
            switch self {
            case .pet:         return petCoinReward
            case .fillWater:   return 3
            case .feed:        return 5
            case .play:        return playCoinReward
            case .cleanLitter: return 6
            case .waterPlant:  return plantWaterCoinReward
            }
        }
    }

    // MARK: Need decay (points lost per hour) — see `Need.current(...)`

    /// Hunger falls from full→empty in ~24h.
    static let hungerDecayPerHour: Double = 100.0 / 24.0
    /// Thirst falls in ~12h (cats drink more often than they're fed).
    static let thirstDecayPerHour: Double = 100.0 / 12.0
    /// Litter "cleanliness" falls in ~33h.
    static let litterDecayPerHour: Double = 100.0 / 33.0
    /// Happiness drifts down slowly in ~50h when uncared for (never punishing).
    static let happinessDecayPerHour: Double = 100.0 / 50.0

    // MARK: Gates — a refill task only rewards when the need is actually low

    /// Feeding / watering only allowed (and rewarded) when the level is below this.
    static let feedThirstGate: Double = 50
    /// Litter is considered "dirty" (cleanable) below this.
    static let litterCleanGate: Double = 60

    // MARK: Cooldowns (seconds) for tasks not tied to a depleting need

    /// Coins for petting; only granted once per `petCooldown`.
    static let petCoinReward = 2
    static let petCooldown: TimeInterval = 3600   // 1h

    static let playCooldown: TimeInterval = 2 * 3600   // 2h

    /// Seconds of active laser play required before coins are awarded.
    static let playDurationRequired: TimeInterval = 8
    static let playCoinReward = 8

    /// Watering rewards by plant size.
    static let smallPlantWaterCoinReward = 4
    static let bigPlantWaterCoinReward = 6
    /// Back-compat/default reward for generic plant-water task contexts.
    static let plantWaterCoinReward = bigPlantWaterCoinReward
    static let plantWaterCooldown: TimeInterval = 3 * 3600   // 3h
    /// Seconds to hold/drag during food, litter, and plant care mini-games.
    static let careTaskDurationRequired: TimeInterval = 3
    /// Seconds the watering can must stay over the plant before coins are awarded.
    static let plantWaterDurationRequired: TimeInterval = careTaskDurationRequired

    // MARK: Happiness boosts from interactions

    static let happinessFromPet: Double = 15
    static let happinessFromPlay: Double = 25
    static let happinessFromFeed: Double = 5
    static let happinessFromWater: Double = 10

    // MARK: Daily check-in streak

    static let checkIn7DayReward = 100
    static let checkInDailyReward = 14

    static func checkInReward(forDay day: Int) -> Int {
        day == 7 ? checkIn7DayReward : checkInDailyReward
    }

    // MARK: Shop catalog

    /// One-time cosmetic rename — priced between basic cat food (8) and wall color (18).
    static let renameCost = 15
    static let secondPetUnlockLevel = 20

    // MARK: Smart XP rewards (ELO-style progression across all interactions)

    enum ExperienceSource {
        case pet, fillWater, feed, play, cleanLitter, rename, adopt

        var smartXP: Int {
            switch self {
            case .pet: return 1
            case .fillWater: return 2
            case .feed: return 3
            case .play: return 5
            case .cleanLitter: return 4
            case .rename: return 2
            case .adopt: return 10
            }
        }
    }

    /// Friendly copy when petting is still on the coin cooldown.
    static func petCooldownMessage(remaining: TimeInterval) -> String {
        let totalMinutes = max(1, Int(ceil(remaining / 60)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "Petting points available again in \(hours)h \(minutes)m"
        }
        return "Petting points available again in \(minutes)m"
    }

    static func playCooldownMessage(remaining: TimeInterval) -> String {
        let totalMinutes = max(1, Int(ceil(remaining / 60)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "Play points available again in \(hours)h \(minutes)m"
        }
        return "Play points available again in \(minutes)m"
    }

    static func plantWaterCooldownMessage(remaining: TimeInterval) -> String {
        let totalMinutes = max(1, Int(ceil(remaining / 60)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "Watering points available again in \(hours)h \(minutes)m"
        }
        return "Watering points available again in \(minutes)m"
    }

    static func plantWaterCoinReward(for key: String) -> Int {
        switch key {
        case "furniture_small_plant":
            return smallPlantWaterCoinReward
        case "furniture_big_plant":
            return bigPlantWaterCoinReward
        default:
            return plantWaterCoinReward
        }
    }
}
