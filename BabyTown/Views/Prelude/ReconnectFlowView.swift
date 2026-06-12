import SwiftUI

struct ReconnectFlowView: View {

    @ObservedObject var viewModel: PreludeViewModel
    var onDismiss: () -> Void

    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BabyTownTheme.accent)

                VStack(spacing: 12) {
                    Text("Reconnect")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)

                    Text("Your archive chapter will be preserved.\nGarden and pet resume from where they were.")
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showConfirmation = true
                    } label: {
                        Text("Reconnect")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule().fill(BabyTownTheme.accentGradient)
                            )
                    }
                    .buttonStyle(.plain)

                    Button("Not yet", action: onDismiss)
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
            .navigationTitle("Reconnect")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Reconnect with your partner?", isPresented: $showConfirmation) {
            Button("Reconnect") {
                viewModel.reconnect()
                onDismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Both users must confirm to reactivate the relationship.")
        }
    }
}
