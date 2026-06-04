import SwiftUI

/// Names a newly imported track or renames an existing playlist entry.
struct CoupleSongNameSheet: View {
    let title: String
    let subtitle: String
    let initialName: String
    let confirmTitle: String
    var onCancel: () -> Void
    var onConfirm: (String) -> Void

    @State private var nameInput = ""
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canConfirm: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField(
                    "",
                    text: $nameInput,
                    prompt: Text(initialName).foregroundStyle(Color.secondary)
                )
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isNameFocused)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)

                Button(action: confirm) {
                    Text(confirmTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(canConfirm ? BabyTownTheme.accent : Color.gray.opacity(0.4))
                        )
                }
                .disabled(!canConfirm)
                .padding(.horizontal)

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear {
                nameInput = initialName
                isNameFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func confirm() {
        guard canConfirm else { return }
        onConfirm(trimmedName)
    }
}
