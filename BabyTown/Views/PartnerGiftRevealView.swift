import SwiftUI

struct PartnerGiftRevealView: View {
    let captures: [GiftRevealCapture]
    let revealerName: String
    var onContinue: () -> Void

    @State private var firstCardScrolledPast = false

    private let backgroundGradient = LinearGradient(
        colors: [Color(hex: "4a1942"), Color(hex: "8b3d5c")],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(captures.enumerated()), id: \.element.id) { index, capture in
                            CaptureRevealCard(capture: capture)
                                .padding(.horizontal, 24)
                                .onAppear {
                                    if index == 0 { firstCardScrolledPast = true }
                                }
                        }
                    }
                    .padding(.bottom, 120)
                }
            }

            continueButton
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("\(revealerName)'s Prelude")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("This is how they felt before you were ever official.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(firstCardScrolledPast ? Color(hex: "4a1942") : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(firstCardScrolledPast ? .white : .white.opacity(0.15))
                )
        }
        .disabled(!firstCardScrolledPast)
        .animation(.easeInOut(duration: 0.3), value: firstCardScrolledPast)
    }
}

private struct CaptureRevealCard: View {
    let capture: GiftRevealCapture

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: capture.typeIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(capture.type.typeLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text(capture.displayText)
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.12))
        )
    }
}

private extension PreludeCapture.CaptureType {
    var typeLabel: String {
        switch self {
        case .note: return "Note"
        case .first: return "First"
        case .voiceMemo: return "Voice"
        case .reason: return "Reason"
        }
    }
}

// Color(hex:) helper — add only if not already defined project-wide
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    PartnerGiftRevealView(
        captures: [
            GiftRevealCapture(id: UUID(), type: .note, displayText: "I keep thinking about you.", typeIcon: "pencil.and.scribble"),
            GiftRevealCapture(id: UUID(), type: .reason, displayText: "The way you always laugh first.", typeIcon: "heart.fill"),
            GiftRevealCapture(id: UUID(), type: .first, displayText: "First time we danced.", typeIcon: "star.fill")
        ],
        revealerName: "Sarah",
        onContinue: {}
    )
}
