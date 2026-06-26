import SwiftUI

struct PlanVaultSheet: View {
    let onUnlockForever: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(BabyTownTheme.accent)

            VStack(spacing: 10) {
                Text("This date is in the vault")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Date plans are kept safe after 30 days. Unlock Forever to relive every date you planned together.")
                    .font(.subheadline)
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 12) {
                Button {
                    dismiss()
                    onUnlockForever()
                } label: {
                    Text("Unlock Forever")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(BabyTownTheme.accentGradient, in: Capsule())
                }
                .buttonStyle(.plain)

                Button("Later") { dismiss() }
                    .font(.body.weight(.medium))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }

            Spacer()
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Text("Home")
        .sheet(isPresented: .constant(true)) {
            PlanVaultSheet(onUnlockForever: {})
        }
}
