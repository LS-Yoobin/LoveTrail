import SwiftUI

struct ColorThemeView: View {

    /// Called with the chosen theme once the user confirms.
    var onContinue: (ColorTheme) -> Void

    @State private var selected: ColorTheme = .pink
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, (selected == .blue ? Color.blue : Color.pink).opacity(0.06)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.3), value: selected)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    Text("What color theme do you prefer?")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .multilineTextAlignment(.center)
                    Text("You can enjoy the app in pink or blue")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                HStack(spacing: 20) {
                    swatch(.pink, label: "Pink", color: .pink)
                    swatch(.blue, label: "Blue", color: Color(red: 0.22, green: 0.48, blue: 0.96))
                }
                .padding(.horizontal, 32)

                Spacer()

                continueButton
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) { contentOpacity = 1.0 }
        }
    }

    private func swatch(_ theme: ColorTheme, label: String, color: Color) -> some View {
        let isSelected = selected == theme
        return Button {
            selected = theme
        } label: {
            VStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(colors: [color, color.opacity(0.8)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: color.opacity(0.35), radius: 10, y: 4)
                Text(label)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : Color(.systemGray4),
                            lineWidth: isSelected ? 3 : 1)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var continueButton: some View {
        Button {
            onContinue(selected)
        } label: {
            Text("Continue")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: selected == .blue
                                ? [Color(red: 0.22, green: 0.48, blue: 0.96), Color(red: 0.14, green: 0.34, blue: 0.78)]
                                : [.pink, .pink.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
        }
    }
}

#Preview {
    ColorThemeView { print("theme: \($0)") }
}
