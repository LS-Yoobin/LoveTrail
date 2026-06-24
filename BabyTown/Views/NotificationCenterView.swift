import SwiftUI

struct NotificationCenterView: View {

    var onNotificationRead: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store: StoreManager = .shared
    @State private var notifications: [AppNotification] = []
    @State private var userLetters: [UserLetter] = []
    @State private var openedWelcomeCard = false
    @State private var showComposeLetter = false
    @State private var showForeverPaywall = false

    private var thirtyDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    }

    private var hasContent: Bool {
        !notifications.isEmpty || !userLetters.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                BabyTownTheme.backgroundGradient
                    .ignoresSafeArea()

                if hasContent {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(userLetters.sorted { $0.sortDate > $1.sortDate }) { letter in
                                if store.isForeverUnlocked || letter.createdAt >= thirtyDaysAgo {
                                    UserLetterRow(letter: letter)
                                } else {
                                    VaultedLetterRow(letter: letter) {
                                        showForeverPaywall = true
                                    }
                                }
                            }

                            ForEach(notifications) { notification in
                                NotificationRow(notification: notification) {
                                    handleTap(notification)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 96)
                    }
                } else {
                    emptyState
                }

                composeLetterButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
            }
            .navigationTitle("Letters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                    }
                }
            }
            .fullScreenCover(isPresented: $openedWelcomeCard) {
                BabyTownWelcomeCardDetailView()
            }
            .fullScreenCover(isPresented: $showComposeLetter, onDismiss: reloadContent) {
                ComposeLetterView()
            }
            .fullScreenCover(isPresented: $showForeverPaywall) {
                CovelaForeverPaywallView(
                    store: store,
                    onUnlock: { showForeverPaywall = false },
                    onDismiss: { showForeverPaywall = false }
                )
            }
            .onAppear {
                reloadContent()
            }
        }
    }

    private var composeLetterButton: some View {
        Button {
            showComposeLetter = true
        } label: {
            Image(systemName: "envelope.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(BabyTownTheme.accentGradient)
                .clipShape(Circle())
                .shadow(color: BabyTownTheme.buttonShadow, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func reloadContent() {
        notifications = AppNotification.seededNotifications(
            userNickname: DataPersistenceManager.shared.loadUserNickname()
        )
        userLetters = DataPersistenceManager.shared.loadUserLetters()
    }

    private func handleTap(_ notification: AppNotification) {
        switch notification.type {
        case .welcomeCard:
            markRead(notification)
            openedWelcomeCard = true
        case .valentinesCard:
            markRead(notification)
        }
    }

    private func markRead(_ notification: AppNotification) {
        DataPersistenceManager.shared.markInAppNotificationRead(id: notification.id)
        onNotificationRead?()
        reloadContent()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.open")
                .font(.system(size: 48))
                .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.25))

            Text("No letters yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.5))

            Text("Tap the envelope to write your first letter.")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.bottom, 72)
    }
}

// MARK: - User Letter Row

private struct UserLetterRow: View {

    let letter: UserLetter

    private var timestampText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let referenceDate = letter.sentAt ?? letter.scheduledFor ?? letter.createdAt
        if Calendar.current.isDateInToday(referenceDate) {
            return "Today"
        }
        return formatter.string(from: referenceDate)
    }

    private var statusLabel: String {
        if letter.isScheduled, let scheduledFor = letter.scheduledFor {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d • h:mm a"
            return "Scheduled \(formatter.string(from: scheduledFor))"
        }
        return "Sent"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BabyTownTheme.accent.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "envelope.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(BabyTownTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(letter.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text(letter.bodyPreview)
                    .font(.system(size: 13))
                    .foregroundStyle(.black.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(timestampText)
                    .font(.system(size: 12))
                    .foregroundStyle(.black.opacity(0.4))

                Text(statusLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(letter.isScheduled ? BabyTownTheme.accent : .black.opacity(0.55))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        )
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {

    let notification: AppNotification
    let onTap: () -> Void

    @State private var pressed = false

    private var timestampText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(notification.date) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: notification.date)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(BabyTownTheme.accent.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: notification.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(BabyTownTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    Text(notification.bodyPreview)
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(timestampText)
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.4))

                    Text("Open")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(BabyTownTheme.accentGradient)
                        )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressed)
    }
}

#Preview {
    NotificationCenterView()
}
