import SwiftUI

struct SettingsSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    var onResetApp: () -> Void
    var onReplayStory: () -> Void
    
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onReplayStory()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle")
                                .font(.system(size: 16))
                            Text("Replay Our Story")
                                .font(.system(size: 16))
                        }
                    }
                    
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
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Image("BabyTownFullIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 13.5))
                    
                    Text("BabyTown 2026")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
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
    SettingsSheet(onResetApp: {}, onReplayStory: {})
}
