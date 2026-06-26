import SwiftUI

struct HomeGardenPatchView: View {
    let hasPetAdopted: Bool
    let unreadLetterCount: Int
    var mapIsPresented: Bool = false
    let onPetHouseTap: () -> Void
    let onMailboxTap: () -> Void
    let onMapTap: () -> Void

    private static let grassAspect: CGFloat = 416.0 / 357.0
    /// Bleeds past the Home feed's standard 20pt inset so the oval grass isn't clipped.
    private static let grassHorizontalBleed: CGFloat = 20

    private var hasUnreadMail: Bool { unreadLetterCount > 0 }

    private var petHouseLabel: String {
        hasPetAdopted ? "Visit Pet" : "Adopt Pet"
    }

    private var mailboxLabel: String {
        if unreadLetterCount == 0 {
            return "No Letters"
        }
        if unreadLetterCount == 1 {
            return "1 New Letter"
        }
        return "\(unreadLetterCount) New Letters"
    }

    private var petHousePillStyle: GardenLabelPillStyle {
        hasPetAdopted ? .black : .accent
    }

    private var mailboxPillStyle: GardenLabelPillStyle {
        hasUnreadMail ? .accent : .black
    }

    private enum GardenLabelPillStyle {
        case accent
        case black

        var fill: Color {
            switch self {
            case .accent: BabyTownTheme.accent
            case .black: .black
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("home_grass_patch")
                .resizable()
                .aspectRatio(Self.grassAspect, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

            grassProps
        }
        .padding(.horizontal, -Self.grassHorizontalBleed)
    }

    private var grassProps: some View {
        GeometryReader { geo in
            let sceneHeight = geo.size.height
            let verticalLift = sceneHeight * 0.03

            ZStack {
                HStack(alignment: .bottom, spacing: 0) {
                    propColumn(
                        imageName: BabyTownTheme.homePetHouseImage,
                        imageHeight: sceneHeight * 0.48,
                        label: petHouseLabel,
                        pillStyle: petHousePillStyle,
                        labelSpacing: 1,
                        leadingPadding: geo.size.width * 0.03,
                        trailingPadding: 0,
                        verticalOffset: sceneHeight * 0.05,
                        action: onPetHouseTap
                    )

                    Spacer()

                    propColumn(
                        imageName: hasUnreadMail ? "home_mailbox_full" : "home_mailbox_empty",
                        imageHeight: sceneHeight * 0.37,
                        label: mailboxLabel,
                        pillStyle: mailboxPillStyle,
                        leadingPadding: 0,
                        trailingPadding: geo.size.width * 0.01,
                        verticalOffset: sceneHeight * 0.01,
                        action: onMailboxTap
                    )
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                .offset(y: -verticalLift)

                HomeMapScrollButton(
                    imageHeight: sceneHeight * 0.21,
                    mapIsPresented: mapIsPresented,
                    onUnfoldComplete: onMapTap
                )
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                .offset(x: geo.size.width * 0.06, y: -sceneHeight * 0.11)
                .animation(nil, value: mapIsPresented)
            }
        }
        .aspectRatio(Self.grassAspect, contentMode: .fit)
    }

    private func propColumn(
        imageName: String,
        imageHeight: CGFloat,
        label: String,
        pillStyle: GardenLabelPillStyle,
        labelSpacing: CGFloat = 4,
        leadingPadding: CGFloat,
        trailingPadding: CGFloat,
        verticalOffset: CGFloat = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: labelSpacing) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: imageHeight)

                labelPill(label, style: pillStyle)
            }
        }
        .buttonStyle(.plain)
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .offset(y: verticalOffset)
    }

    private func labelPill(_ text: String, style: GardenLabelPillStyle) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(style.fill, in: Capsule())
            .shadow(color: BabyTownTheme.cardShadow, radius: 2, y: 1)
    }
}

#Preview {
    VStack(spacing: 24) {
        HomeGardenPatchView(
            hasPetAdopted: false,
            unreadLetterCount: 0,
            onPetHouseTap: {},
            onMailboxTap: {},
            onMapTap: {}
        )
        HomeGardenPatchView(
            hasPetAdopted: true,
            unreadLetterCount: 2,
            onPetHouseTap: {},
            onMailboxTap: {},
            onMapTap: {}
        )
    }
    .padding()
    .background(BabyTownTheme.backgroundGradient)
}
