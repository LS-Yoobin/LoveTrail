import SwiftUI

struct ArchiveFlowView: View {

    @ObservedObject var viewModel: PreludeViewModel
    var onDismiss: () -> Void

    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "archivebox")
                    .font(.system(size: 56))
                    .foregroundStyle(BabyTownTheme.textSecondary)

                VStack(spacing: 12) {
                    Text("Archive Your Relationship")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)

                    Text("This will end your active relationship.\nYour memories are preserved forever.")
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
                        Text("Archive Relationship")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.gray))
                    }
                    .buttonStyle(.plain)

                    Button("Cancel", action: onDismiss)
                        .foregroundStyle(BabyTownTheme.accent)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Archive this relationship?", isPresented: $showConfirmation) {
            Button("Archive", role: .destructive) {
                viewModel.archiveRelationship()
                onDismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Garden and pet will freeze. Your shared timeline and Prelude chapter become read-only.")
        }
    }
}
