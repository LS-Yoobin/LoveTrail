import SwiftUI
import UserNotifications

struct SettingsSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var store = StoreManager.shared
    var onResetApp: () -> Void
    var onReplayStory: () -> Void
    var onVisitPet: () -> Void
    var onOpenCoupleProfile: () -> Void = {}
    
    @State private var showResetConfirmation = false
    @State private var showAppIconViewer = false
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            List {
                BackgroundMusicSettingsSection()

                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Image(systemName: "heart.circle")
                                .font(.system(size: 16))
                            Text("Subscription")
                                .font(.system(size: 16))
                            Spacer()
                            Text(store.isPartnerUnlocked ? (store.activePlan?.displayName ?? "Active") : "Free")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Subscription")
                }

                Section {
                    Button {
                        dismiss()
                        onVisitPet()
                    } label: {
                        HStack {
                            Image(systemName: "pawprint.circle")
                                .font(.system(size: 16))
                            Text("Visit Pet")
                                .font(.system(size: 16))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)

                    Button {
                        dismiss()
                        onOpenCoupleProfile()
                    } label: {
                        HStack {
                            Image(systemName: "leaf.circle")
                                .font(.system(size: 16))
                            Text("Our Garden")
                                .font(.system(size: 16))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Pet")
                }

                Section {
                    HStack {
                        Text("Notifications")
                        Spacer()
                        
                        switch notificationManager.permissionStatus {
                        case .authorized, .provisional, .ephemeral:
                            Text("On")
                                .foregroundStyle(.secondary)
                        case .denied:
                            Button("Enable in Settings") {
                                notificationManager.openAppSettings()
                            }
                            .font(.system(size: 14, weight: .medium))
                        case .notDetermined:
                            Button("Enable") {
                                notificationManager.requestAuthorization()
                            }
                            .font(.system(size: 14, weight: .medium))
                        @unknown default:
                            Text("Unknown")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    if notificationManager.permissionStatus == .denied {
                        Text("Turn on notifications to get daily reminders to capture memories.")
                    }
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    NavigationLink {
                        LegalDocumentView(document: .privacyPolicy)
                    } label: {
                        Text("Privacy Policy")
                    }
                    
                    NavigationLink {
                        LegalDocumentView(document: .termsOfService)
                    } label: {
                        Text("Terms of Service")
                    }
                } header: {
                    Text("About me")
                }

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

#if DEBUG
                Section("Debug · Partner notifications") {
                    Button("Test: partner joined") {
                        NotificationManager.shared.handlePartnerEvent(.joined(partnerName: "Alex"))
                    }
                    Button("Test: love letter received") {
                        NotificationManager.shared.handlePartnerEvent(
                            .loveLetterReceived(title: "Thinking of you", sentAt: Date()))
                    }
                    Button("Test: partner added a moment") {
                        NotificationManager.shared.handlePartnerEvent(.partnerAddedMoment)
                    }
                    Button("Test: partner added a date") {
                        NotificationManager.shared.handlePartnerEvent(.partnerAddedSpecialDate)
                    }
                }
#endif
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
                        .onTapGesture {
                            showAppIconViewer = true
                        }

                    Text("BabyTown 2026")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
            }
            .fullScreenCover(isPresented: $showAppIconViewer) {
                AppIconViewerOverlay()
            }
            .fullScreenCover(isPresented: $showPaywall) {
                InvitePartnerPaywallView(
                    store: store,
                    onUnlock: { showPaywall = false },
                    onDismiss: { showPaywall = false }
                )
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await notificationManager.checkPermissionStatus()
                }
            }
        }
    }
}

private struct AppIconViewerOverlay: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("BabyTownFullIcon")
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .padding(40)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
        }
    }
}

#Preview {
    SettingsSheet(onResetApp: {}, onReplayStory: {}, onVisitPet: {})
}
