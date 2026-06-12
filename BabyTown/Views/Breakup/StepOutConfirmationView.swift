import SwiftUI

struct StepOutConfirmationView: View {
    var onConfirmed: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "figure.walk.departure")
                    .font(.system(size: 52))
                    .foregroundStyle(.secondary)
                VStack(spacing: 10) {
                    Text("Start Fresh")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                    Text("You'll lose access to your shared memories. This can't be undone.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 14) {
                Button {
                    showAlert = true
                } label: {
                    Text("Leave my memories behind")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Color.red.opacity(0.75)))
                }
                .buttonStyle(.plain)
                Button("Keep browsing") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 44)
        }
        .alert("Are you sure?", isPresented: $showAlert) {
            Button("Start Fresh", role: .destructive) { performStepOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll lose access to your shared memories. This cannot be undone.")
        }
    }

    private func performStepOut() {
        ArchiveService.shared.stepOut()
        onConfirmed()
    }
}
