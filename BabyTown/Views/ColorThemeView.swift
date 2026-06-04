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
            ambientOrbs

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
        VStack(spacing: 14) {
            Text("Choose your palette")
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)

            Text("Sets the mood for memories, buttons, and every little detail. You can switch anytime in Settings.")
                .font(.system(size: 15))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Live preview

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PREVIEW")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.black)

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
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(selected.accent.opacity(0.35))
                                    .frame(width: 88, height: 8)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.systemGray4))
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(theme.tagline)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
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
        LinearGradient(
            colors: [.white, selected.accent.opacity(0.07)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: selected)
    }

    private var ambientOrbs: some View {
        ZStack {
            Circle()
                .fill(selected.accent.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: -120, y: -280)

            Circle()
                .fill(selected.accentDeep.opacity(0.08))
                .frame(width: 180, height: 180)
                .blur(radius: 50)
                .offset(x: 140, y: 120)
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.5), value: selected)
    }

    private var continueButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onContinue(selected)
        } label: {
            Text("Continue")
                .font(.system(size: 17, weight: .medium))
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
