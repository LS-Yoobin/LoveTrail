import SwiftUI
import Photos

struct PhotoAccessView: View {

    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var iconScale: Double = 0.7
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()

                iconSection
                    .padding(.bottom, 36)

                titleSection
                    .padding(.bottom, 40)

                accessLevelCards
                    .padding(.bottom, 32)

                Spacer()

                VStack(spacing: 14) {
                    buttonSection
                    OnboardingLegalLinks()
                }
            }
            .opacity(contentOpacity)
        }
        .onboardingBackButton(action: onBack)
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.72).delay(0.1)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                contentOpacity = 1.0
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [.white, BabyTownTheme.blushSoft, BabyTownTheme.accent.opacity(0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Icon

    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [BabyTownTheme.accent.opacity(0.15), BabyTownTheme.accentDeep.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 110, height: 110)

            Image(systemName: "photo.stack.fill")
                .font(.system(size: 46))
                .foregroundStyle(
                    LinearGradient(
                        colors: [BabyTownTheme.accent, BabyTownTheme.accentDeep.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .scaleEffect(iconScale)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 10) {
            Text("06  MOMENTS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(BabyTownTheme.accentDeep)

            Text("Save your\nmoments")
                .font(.system(size: 31, weight: .semibold, design: .rounded))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("Fill your timeline with memories you've\nalready made—or capture new ones together.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.66))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Access Level Cards

    private var accessLevelCards: some View {
        VStack(spacing: 12) {
            AccessLevelCard(
                icon: "clock.arrow.circlepath",
                title: "Moments from your past",
                description: "Save photos from your camera roll anytime."
            )
            AccessLevelCard(
                icon: "camera.fill",
                title: "Use our camera",
                description: "Take new photos right in the app.\nThey appear on your map and timeline."
            )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        Button {
            requestPhotoAccess()
        } label: {
            Group {
                if isRequesting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [BabyTownTheme.accent, BabyTownTheme.accentDeep.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 14, y: 6)
            )
        }
        .disabled(isRequesting)
        .padding(.horizontal, 40)
        .padding(.bottom, 8)
    }

    // MARK: - Permission Request

    private func requestPhotoAccess() {
        guard !isRequesting else { return }
        isRequesting = true

        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if current == .notDetermined {
            Task {
                _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                await MainActor.run {
                    isRequesting = false
                    onContinue()
                }
            }
        } else {
            isRequesting = false
            onContinue()
        }
    }
}

// MARK: - Access Level Card

private struct AccessLevelCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [BabyTownTheme.accent.opacity(0.15), BabyTownTheme.accentDeep.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(BabyTownTheme.accentIconGradient)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text(description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.64))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
    }
}

#Preview {
    PhotoAccessView(onBack: {}, onContinue: {
        print("Continuing to home")
    })
}
