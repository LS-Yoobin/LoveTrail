import SwiftUI

/// Sheet listing every trick, its training level, obedience rate, and unlock progress.
struct PetTrickBookSheet: View {
    @ObservedObject var viewModel: PetViewModel
    var onClose: () -> Void

    /// Near-black body text — the previous `.secondary` was too faint to read.
    private let bodyText = Color(red: 0.13, green: 0.11, blue: 0.13)
    /// Slightly muted dark for captions, still clearly legible on the cream card.
    private let mutedText = Color(red: 0.32, green: 0.29, blue: 0.31)
    /// Soft, lighter red for locked trick icons — clearly legible on the cream
    /// pillow background without the harsh, washed-out look of the deep accent.
    private let lockedIconTint = Color(red: 0.84, green: 0.41, blue: 0.45)
    private let lockedIconBackdrop = Color(red: 0.84, green: 0.41, blue: 0.45).opacity(0.14)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    trainingOverviewCard

                    ForEach(PetTrick.unlockOrder) { trick in
                        trickRow(trick)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(red: 0.99, green: 0.96, blue: 0.94).ignoresSafeArea())
            .navigationTitle("Tricks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var trainingOverviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PetSmartMeterBar(
                level: viewModel.smartMeterLevel,
                progressFraction: viewModel.smartMeterProgressFraction()
            )

            Label("How training works", systemImage: "graduationcap.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(BabyTownTheme.accentDeep)

            Text("Say a trick out loud while the mic is on. Your cat obeys based on training level — it starts low and climbs as you practice. Drop a snack right after a good trick to reinforce it (bonus rep + higher obey rate). Snacks without a successful trick don't train. Unlock new tricks by mastering the previous one.")
                .font(.system(size: 13))
                .foregroundStyle(bodyText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Unlock order")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                Text(PetTrick.unlockOrder.map(\.displayName).joined(separator: " → "))
                    .font(.system(size: 12))
                    .foregroundStyle(mutedText)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Training modes")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                Text("6 voice tricks · drag snack after a good trick to reinforce")
                    .font(.system(size: 12))
                    .foregroundStyle(mutedText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: BabyTownTheme.cardShadow, radius: 6, y: 2)
    }

    private func trickRow(_ trick: PetTrick) -> some View {
        let progress = viewModel.trickProgress(for: trick)
        let unlocked = progress.isUnlocked
        let unlockInfo = viewModel.trickTraining.unlockProgress(for: trick)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                trickIcon(trick, unlocked: unlocked)

                VStack(alignment: .leading, spacing: 2) {
                    Text(trick.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(unlocked ? BabyTownTheme.accentDeep : mutedText)

                    if unlocked {
                        Text("Level \(progress.level) · \(Int(progress.obedienceRate * 100))% obey rate")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(mutedText)
                    } else if let unlockInfo {
                        if let prereq = trick.prerequisite,
                           viewModel.trickProgress(for: prereq).level < trick.prerequisiteMinLevel {
                            Text("Reach \"\(prereq.displayName)\" Level \(trick.prerequisiteMinLevel) first")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                        } else {
                            Text(unlockProgressSubtitle(unlockInfo))
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("Locked")
                            .font(.system(size: 12))
                            .foregroundStyle(mutedText)
                    }
                }

                Spacer()

                if unlocked {
                    levelBadge(progress.level)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }

            if unlocked {
                levelProgressBar(progress: progress)
            } else if let unlockInfo, unlockInfo.required > 0 {
                unlockProgressBar(current: unlockInfo.current, required: unlockInfo.required)
            }

            if unlocked {
                Text("Say: \"\(trick.voicePhrases.first ?? trick.displayName)\"")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
            }
        }
        .padding(14)
        .background(.white.opacity(unlocked ? 0.95 : 0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(unlocked ? BabyTownTheme.accent.opacity(0.2) : Color.clear, lineWidth: 1)
        }
        .shadow(color: BabyTownTheme.cardShadow.opacity(unlocked ? 1 : 0.4), radius: 5, y: 2)
    }

    private func unlockProgressSubtitle(
        _ unlockInfo: (current: Int, required: Int, prerequisiteName: String?)
    ) -> String {
        let remaining = max(0, unlockInfo.required - unlockInfo.current)
        if let name = unlockInfo.prerequisiteName {
            return "\(remaining) more \"\(name)\" reps to unlock"
        }
        return "\(remaining) more tricks to unlock"
    }

    private func trickIcon(_ trick: PetTrick, unlocked: Bool) -> some View {
        ZStack {
            Circle()
                .fill(unlocked ? BabyTownTheme.accent.opacity(0.15) : lockedIconBackdrop)
                .frame(width: 44, height: 44)
            Image(systemName: trick.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(unlocked ? BabyTownTheme.accentDeep : lockedIconTint)
        }
    }

    private func levelBadge(_ level: Int) -> some View {
        Text("Lv \(level)")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(BabyTownTheme.buttonGradient, in: Capsule())
    }

    private func levelProgressBar(progress: PetTrickProgress) -> some View {
        let level = progress.level
        let maxLevel = PetTrickTrainingRules.maxLevel
        let untilNext = PetTrickTrainingRules.successesUntilNextLevel(
            currentSuccesses: progress.successes,
            currentLevel: level
        )

        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule()
                        .fill(BabyTownTheme.buttonGradient)
                        .frame(width: geo.size.width * CGFloat(level) / CGFloat(maxLevel))
                }
            }
            .frame(height: 6)

            if let untilNext, untilNext > 0 {
                Text("\(untilNext) successful reps to Level \(level + 1)")
                    .font(.system(size: 11))
                    .foregroundStyle(mutedText)
            } else if level >= maxLevel {
                Text("Mastered — always obeys!")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
            }
        }
    }

    private func unlockProgressBar(current: Int, required: Int) -> some View {
        let fraction = required > 0 ? min(1, Double(current) / Double(required)) : 0
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.orange.opacity(0.15))
                    Capsule()
                        .fill(Color.orange.opacity(0.7))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
            Text("\(min(current, required)) / \(required) prerequisite reps")
                .font(.system(size: 11))
                .foregroundStyle(mutedText)
        }
    }
}
