import SwiftUI
import UserNotifications

struct SettingsSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var store = StoreManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    var onResetApp: () -> Void
    var onReplayStory: () -> Void
    var onVisitPet: () -> Void
    var onOpenCoupleProfile: () -> Void = {}
    var onLogOut: () -> Void = {}

    @State private var showResetConfirmation = false
    @State private var showAppIconViewer = false
    @State private var showPlaylistEditor = false
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            List {
                BackgroundMusicSettingsSection(onManagePlaylist: { showPlaylistEditor = true })

                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Covela Forever")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(store.isForeverUnlocked
                                     ? (store.activePlan?.displayName ?? "Active")
                                     : "Free plan")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            Spacer()
                            if !store.isForeverUnlocked {
                                Text("Upgrade")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(BabyTownTheme.accentDeep))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(BabyTownTheme.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Subscription")
                }

                Section {
                    Picker("Color", selection: Binding(
                        get: { themeManager.theme },
                        set: { themeManager.setTheme($0) }
                    )) {
                        Text("Pink").tag(ColorTheme.pink)
                        Text("Blue").tag(ColorTheme.blue)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Color Theme")
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
                    NavigationLink {
                        ProfileSettingsView(onLogOut: {
                            onLogOut()
                            dismiss()
                        })
                    } label: {
                        Text("Profile Settings")
                    }

                    // Temporarily hidden: Replay Our Story
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

                    Text("Covela 2026")
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
                CovelaForeverPaywallView(
                    store: store,
                    onUnlock: { showPaywall = false },
                    onDismiss: { showPaywall = false }
                )
            }
            .sheet(isPresented: $showPlaylistEditor) {
                CouplePlaylistEditorSheet(dismissOnSelect: false)
            }
            .confirmationDialog(
                "Reset Covela?",
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
    SettingsSheet(onResetApp: {}, onReplayStory: {}, onVisitPet: {}, onLogOut: {})
}
