import SwiftUI

struct PreludeSettingsSheet: View {

    var onReturnToOnboarding: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            onReturnToOnboarding()
                        }
                    } label: {
                        Label("Return to Onboarding", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("This will take you back to the beginning. Your captures are kept safe.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }
}

#Preview {
    PreludeSettingsSheet(onReturnToOnboarding: { print("return to onboarding") })
}
