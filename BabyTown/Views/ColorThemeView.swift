import SwiftUI
import UIKit

struct ColorThemeView: View {

    var onBack: () -> Void
    var onContinue: (ColorTheme) -> Void

    @State private var selected: ColorTheme = .pink
    @State private var contentOpacity: Double = 0
    @Namespace private var selectionNamespace

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 48)
                        .padding(.horizontal, 32)

                    livePreview
                        .padding(.top, 28)
                        .padding(.horizontal, 36)

                    themeOptions
                        .padding(.top, 26)
                        .padding(.horizontal, 28)

                    VStack(spacing: 14) {
                        continueButton
                        OnboardingLegalLinks()
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
            .opacity(contentOpacity)
        }
        .onboardingBackButton(action: onBack)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                contentOpacity = 1.0
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Text("03  COLOR THEME")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(selected.accentDeep)

            Text("Choose your Covela palette")
                .font(.system(size: 31, weight: .semibold, design: .rounded))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text("This sets the color language for your shared space. You can switch anytime in Settings.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.66))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Live preview

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LIVE PREVIEW")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(selected.accentDeep)

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white, selected.blushSoft],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(selected.accent.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: selected.accent.opacity(0.14), radius: 20, y: 10)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        previewPill(icon: "photo.on.rectangle.angled", title: "Select")
                        previewPill(icon: "camera.viewfinder", title: "Scan")
                        previewPill(icon: "calendar.badge.plus", title: "Planner")
                    }

                    previewSearchBar

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [selected.cardLight, selected.cardDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 72)
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Our Garden")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.72))
                                    .frame(width: 88, height: 7)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.45))
                                    .frame(width: 120, height: 6)
                            }
                            .padding(.leading, 14)
                        }

                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(index == 0 ? selected.accent : selected.accent.opacity(0.22))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
                .padding(18)

                Circle()
                    .fill(selected.buttonGradient)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: selected.accent.opacity(0.35), radius: 10, y: 5)
                    .padding(16)
            }
            .frame(height: 188)
            .animation(.easeInOut(duration: 0.35), value: selected)
        }
    }

    private func previewPill(icon: String, title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(selected.buttonGradient, in: Capsule())
        .shadow(color: selected.accent.opacity(0.18), radius: 5, y: 2)
    }

    private var previewSearchBar: some View {
        Capsule()
            .fill(Color(red: 0.66, green: 0.66, blue: 0.68))
            .frame(height: 32)
            .overlay(alignment: .leading) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 72, height: 6)
                }
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.leading, 12)
            }
    }

    // MARK: - Theme options

    private var themeOptions: some View {
        VStack(spacing: 14) {
            ForEach(ColorTheme.allCases, id: \.self) { theme in
                themeOptionCard(theme)
            }
        }
    }

    private func themeOptionCard(_ theme: ColorTheme) -> some View {
        let isSelected = selected == theme

        return Button {
            guard selected != theme else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                selected = theme
            }
        } label: {
            HStack(spacing: 16) {
                themeSwatch(theme, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                    Text(theme.tagline)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .stroke(isSelected ? theme.accent : Color(.systemGray4), lineWidth: isSelected ? 0 : 1.5)
                        .frame(width: 26, height: 26)

                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 26, height: 26)
                            .matchedGeometryEffect(id: "checkmark", in: selectionNamespace)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: isSelected ? theme.accent.opacity(0.18) : .black.opacity(0.04),
                        radius: isSelected ? 14 : 6,
                        y: isSelected ? 6 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected
                            ? LinearGradient(
                                colors: [theme.accent, theme.accentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color(.systemGray4), Color(.systemGray4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .scaleEffect(isSelected ? 1 : 0.98)
            .opacity(isSelected ? 1 : 0.92)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityHint(theme.tagline)
    }

    private func themeSwatch(_ theme: ColorTheme, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.cardLight, theme.cardDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [theme.accent, theme.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 22, height: 22)
                .shadow(color: theme.accent.opacity(0.4), radius: 4, y: 2)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.accent.opacity(isSelected ? 0.35 : 0.15), lineWidth: 1)
        )
    }

    // MARK: - Chrome

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [.white, selected.blushSoft, selected.accent.opacity(0.07)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.22).opacity(0.8))
                    Spacer()
                }
                .padding(.top, 88)
                .padding(.leading, 56)

                Spacer()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.4), value: selected)
    }

    private var continueButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onContinue(selected)
        } label: {
            Text("Continue")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(selected.buttonGradient)
                        .shadow(color: selected.accent.opacity(0.3), radius: 12, y: 6)
                )
        }
        .animation(.easeInOut(duration: 0.3), value: selected)
    }
}

#Preview {
    ColorThemeView(onBack: {}, onContinue: { print("theme: \($0)") })
}
