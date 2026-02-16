import SwiftUI

struct NotificationCenterView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var notifications = AppNotification.seededNotifications
    @State private var openedValentine = false

    var body: some View {
        NavigationStack {
            ZStack {
                BabyTownTheme.backgroundGradient
                    .ignoresSafeArea()

                if notifications.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notifications) { notification in
                                NotificationRow(notification: notification) {
                                    handleTap(notification)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Notifications")
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
            .fullScreenCover(isPresented: $openedValentine) {
                ValentineCardDetailView()
            }
        }
    }

    private func handleTap(_ notification: AppNotification) {
        switch notification.type {
        case .valentinesCard:
            openedValentine = true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.25))

            Text("No notifications yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.5))
        }
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
