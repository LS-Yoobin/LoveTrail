import SwiftUI

/// Tappable name tag shown in the Visit Pet navigation bar.
struct PetNameTagLabel: View {
    let name: String

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .stroke(BabyTownTheme.accent.opacity(0.4), lineWidth: 1.5)
                .background(Circle().fill(Color.white.opacity(0.9)))
                .frame(width: 10, height: 10)
                .offset(y: 5)
                .zIndex(1)

            HStack(spacing: 6) {
                Text(name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(BabyTownTheme.accent.opacity(0.75))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    BabyTownTheme.cardTintLight,
                                    BabyTownTheme.cardTintDeep
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(BabyTownTheme.accent.opacity(0.35), lineWidth: 1)
                }
            }
            .shadow(color: BabyTownTheme.cardShadow, radius: 4, y: 2)
        }
        .rotationEffect(.degrees(-1.2))
    }
}

/// Profile popover for the active kitty on the Visit Pet screen.
struct PetProfileCard: View {
    let skin: CatSkin
    let displayName: String
    let birthDate: Date
    let smartnessLevel: Int
    let knownTricks: [PetTrick]
    var showsBirthDate: Bool = true
    var showsTrainingDetails: Bool = true
    var onClose: () -> Void
    var onRenameName: (() -> Void)? = nil
    var onLevelLongPress: (() -> Void)? = nil

    private static let birthDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private let ink = Color(red: 0.11, green: 0.11, blue: 0.13)
    private let inkMuted = Color(red: 0.38, green: 0.36, blue: 0.40)
    private let panelFill = Color(red: 0.98, green: 0.96, blue: 0.97)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection
                detailsSection
            }
        }
        .frame(maxHeight: 520)
        .background(cardChrome)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            BabyTownTheme.accent.opacity(0.35),
                            BabyTownTheme.accentDeep.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .shadow(color: .black.opacity(0.14), radius: 28, y: 14)
        .padding(.horizontal, 24)
    }

    private var levelPill: some View {
        Text("Lvl \(smartnessLevel)")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(BabyTownTheme.accentDeep)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.8), in: Capsule())
            .onLongPressGesture(minimumDuration: 1.2) {
                onLevelLongPress?()
            }
    }

    private var cardChrome: some View {
        ZStack {
            Color.white
            LinearGradient(
                colors: [
                    BabyTownTheme.cardTintLight,
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    BabyTownTheme.cardTintLight,
                    BabyTownTheme.cardTintDeep,
                    BabyTownTheme.cardTintDeep
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 4) {
                Image(skin.profileSitAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 168)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)

                Text(displayName)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)

                Text(skin.breedName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.72), in: Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
            .padding(.bottom, 20)
            .padding(.horizontal, 16)

            HStack {
                levelPill
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ink.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(14)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pet Profile")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(BabyTownTheme.accentDeep)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)

            if onRenameName != nil {
                Button(action: { onRenameName?() }) {
                    profileField(
                        icon: "tag.fill",
                        label: "Name",
                        value: displayName,
                        showsEditHint: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Name, \(displayName)")
                .accessibilityHint("Opens rename sheet")
            } else {
                profileField(
                    icon: "tag.fill",
                    label: "Name",
                    value: displayName
                )
            }

            if showsBirthDate {
                profileField(
                    icon: "gift.fill",
                    label: "Birth Date",
                    value: Self.birthDateFormatter.string(from: birthDate),
                    footnote: "The day they joined your town"
                )
            }

            profileField(
                icon: "pawprint.fill",
                label: "Breed",
                value: skin.breedName
            )

            originStoryBlock
            if showsTrainingDetails {
                tricksBlock
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 22)
    }

    private func profileField(
        icon: String,
        label: String,
        value: String,
        footnote: String? = nil,
        showsEditHint: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accentDeep)
                .frame(width: 32, height: 32)
                .background(BabyTownTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(inkMuted)
                    .textCase(.uppercase)

                HStack(spacing: 6) {
                    Text(value)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ink)
                    if showsEditHint {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.accentDeep)
                    }
                }

                if let footnote {
                    Text(footnote)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(inkMuted)
                        .padding(.top, 1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private var originStoryBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                Text("Origin Story")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(inkMuted)
                    .textCase(.uppercase)
            }

            Text(skin.originStory)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private var tricksBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                Text("Tricks")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(inkMuted)
                    .textCase(.uppercase)
            }

            HStack(spacing: 8) {
                Text("Smartness")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(inkMuted)
                Text("Lv \(smartnessLevel)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(BabyTownTheme.accent.opacity(0.14), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Known Tricks")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(inkMuted)

                if knownTricks.isEmpty {
                    Text("Not trained yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ink)
                } else {
                    tricksWrap
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private var tricksWrap: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 104), spacing: 8, alignment: .leading)
            ],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(knownTricks) { trick in
                HStack(spacing: 6) {
                    Image(systemName: trick.symbolName)
                        .font(.system(size: 11, weight: .bold))
                    Text(trick.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(BabyTownTheme.accentDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(BabyTownTheme.accent.opacity(0.12), in: Capsule())
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.25).ignoresSafeArea()
        PetProfileCard(
            skin: .calico,
            displayName: "Artemis",
            birthDate: Date(),
            smartnessLevel: 4,
            knownTricks: [.paw, .highFive, .up],
            onClose: {}
        )
    }
}
