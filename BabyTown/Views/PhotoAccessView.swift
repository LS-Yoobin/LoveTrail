import SwiftUI
import Photos

struct PhotoAccessView: View {

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

                buttonSection
            }
            .opacity(contentOpacity)
        }
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
            colors: [.white, Color.pink.opacity(0.06)],
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
                        colors: [Color.pink.opacity(0.15), Color.red.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 110, height: 110)

            Image(systemName: "photo.stack.fill")
                .font(.system(size: 46))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .red.opacity(0.8)],
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
            Text("Save your\nmoments")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("Fill your timeline with memories you've\nalready made—or capture new ones together.")
                .font(.system(size: 15))
                .foregroundStyle(.black.opacity(0.6))
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
                description: "Save the photos you already love—we'll place them on your map and timeline.",
                isRecommended: true
            )
            AccessLevelCard(
                icon: "camera.fill",
                title: "Use our camera",
                description: "For what's happening now—snap together in Baby Town and the moment is yours.",
                isRecommended: false
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
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.pink, .red.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .pink.opacity(0.35), radius: 14, y: 6)
            )
        }
        .disabled(isRequesting)
        .padding(.horizontal, 40)
        .padding(.bottom, 50)
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
    let isRecommended: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.pink.opacity(0.15), .red.opacity(0.08)],
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
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)

                    if isRecommended {
                        Text("Recommended")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [.pink, .red.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                    }
                }

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.black.opacity(0.6))
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
    PhotoAccessView {
        print("Continuing to home")
    }
}
