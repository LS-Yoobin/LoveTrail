import SwiftUI

struct SettingsSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    var onResetApp: () -> Void
    
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16))
                            Text("Reset App")
                                .font(.system(size: 16))
                        }
                    }
                } header: {
                    Text("App")
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Reset Baby Town?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset App", role: .destructive) {
                    onResetApp()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all your saved memories, photos, and data. You will start fresh from the welcome screen. This action cannot be undone.")
            }
        }
    }
}

#Preview {
    SettingsSheet(onResetApp: {})
}
