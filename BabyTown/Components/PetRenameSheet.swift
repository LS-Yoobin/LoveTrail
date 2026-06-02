import SwiftUI

/// Bottom panel for renaming the adopted cat. Tapping the coin CTA once arms confirmation.
struct PetRenameSheet: View {

    let defaultName: String
    let currentName: String
    let cost: Int
    let coinBalance: Int
    var onCancel: () -> Void
    /// Returns an error message to show in-panel, or `nil` on success.
    var onConfirm: (String) -> String?

    @State private var nameInput = ""
    @State private var awaitingConfirm = false
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAfford: Bool {
        coinBalance >= cost
    }

    private var isValidName: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 24 && trimmedName != currentName
    }

    private var primaryEnabled: Bool {
        guard isValidName, canAfford else { return false }
        return true
    }

    private var panelBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.93, blue: 0.95),
                BabyTownTheme.cardBackground,
                Color(red: 0.97, green: 0.82, blue: 0.87),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(BabyTownTheme.accentDeep.opacity(0.28))
                .frame(width: 36, height: 5)
                .padding(.top, 4)

            VStack(spacing: 8) {
                Text("Change Name")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.88))

                Text("You can change your kitty's name for \(cost) coins.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            TextField("", text: $nameInput, prompt: Text(defaultName).foregroundStyle(Color.black.opacity(0.35)))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.88))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isNameFocused)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .overlay(
                            Capsule()
                                .strokeBorder(BabyTownTheme.accent.opacity(0.25), lineWidth: 1.5)
                        )
                )
                .padding(.horizontal, 4)
                .onChange(of: nameInput) { _, _ in
                    awaitingConfirm = false
                    errorMessage = nil
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .multilineTextAlignment(.center)
            } else if !canAfford {
                Text("You need \(cost - coinBalance) more coins.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.55))
            }

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.accentDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .strokeBorder(BabyTownTheme.accent.opacity(0.35), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)

                Button(action: handlePrimaryTap) {
                    Group {
                        if awaitingConfirm {
                            Text("Confirm")
                        } else {
                            HStack(spacing: 5) {
                                Image(systemName: "bitcoinsign.circle.fill")
                                Text("\(cost) Coins")
                            }
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(primaryEnabled ? AnyShapeStyle(BabyTownTheme.accentGradient) : AnyShapeStyle(Color.black.opacity(0.18)))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!primaryEnabled)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
        .background(panelBackground)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                topTrailingRadius: 24,
                style: .continuous
            )
        )
        .shadow(color: BabyTownTheme.accent.opacity(0.15), radius: 16, y: -4)
        .onAppear {
            nameInput = currentName == defaultName ? "" : currentName
            awaitingConfirm = false
            errorMessage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isNameFocused = true
            }
        }
    }

    private func handlePrimaryTap() {
        guard primaryEnabled else { return }

        if awaitingConfirm {
            if let error = onConfirm(trimmedName) {
                withAnimation {
                    errorMessage = error
                    awaitingConfirm = false
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                awaitingConfirm = true
            }
        }
    }
}
