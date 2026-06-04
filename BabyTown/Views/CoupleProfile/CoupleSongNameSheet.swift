import SwiftUI

/// Names a newly imported track or renames an existing playlist entry.
struct CoupleSongNameSheet: View {
    let title: String
    let subtitle: String
    let initialName: String
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

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: confirm) {
                        Text("SAVE")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                canConfirm
                                    ? AnyShapeStyle(BabyTownTheme.savePillFill)
                                    : AnyShapeStyle(Color.black.opacity(0.18)),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canConfirm)
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
