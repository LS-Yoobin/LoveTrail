import SwiftUI

/// Centered popup shown when a trick levels up or a new trick unlocks during training.
struct PetTrickProgressAlertView: View {
    enum Kind {
        case levelUp(level: Int, smartMeterXP: Int)
        case unlocked(bonusCoins: Int, smartMeterXP: Int)
    }

    let trick: PetTrick
    let kind: Kind

    private var title: String {
        switch kind {
        case .levelUp(let level, _):
            return "\(trick.displayName) — Level \(level)!"
        case .unlocked:
            return "New trick unlocked!"
        }
    }

    private var subtitle: String {
        switch kind {
        case .levelUp(let level, let xp):
            let rate = Int(PetTrickTrainingRules.obedienceRate(level: level) * 100)
            let mastery = level >= PetTrickTrainingRules.maxLevel
            let base = mastery
                ? "Mastered — always obeys!"
                : "\(rate)% obey rate — keep practicing!"
            return xp > 0 ? "\(base) +\(xp) Smart XP" : base
        case .unlocked(let coins, let xp):
            var parts = ["Try saying \"\(trick.voicePhrases.first ?? trick.displayName)\""]
            if coins > 0 { parts.append("+\(coins) bonus coins") }
            if xp > 0 { parts.append("+\(xp) Smart XP") }
            return parts.joined(separator: " · ")
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BabyTownTheme.accent.opacity(0.22))
                    .frame(width: 48, height: 48)
                Image(systemName: trick.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}
