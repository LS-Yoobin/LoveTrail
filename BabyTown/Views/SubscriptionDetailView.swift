import SwiftUI
import StoreKit

/// Settings ▸ Subscription detail. Shows the partner perks again, the current
/// plan status, and links to manage (cancel via Apple) or restore.
struct SubscriptionDetailView: View {

    @ObservedObject var store: StoreManager

    @State private var showManageSubscriptions = false

    private var accent: Color { BabyTownTheme.accentDeep }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Plan")
                    Spacer()
                    Text(statusText)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Status")
            }

            Section {
                Label("Every moment, always. Your full timeline, no limits", systemImage: "photo.stack")
                    .foregroundStyle(.primary)
                Label("Letters that last. Read and write beyond 30 days", systemImage: "envelope.fill")
                    .foregroundStyle(.primary)
                Label("Unlimited important dates. Every milestone, saved forever", systemImage: "calendar")
                    .foregroundStyle(.primary)
                Label("Unlimited pinned moments. Keep what matters most", systemImage: "pin.fill")
                    .foregroundStyle(.primary)
                Label("One purchase for both of you. Covers you and your partner", systemImage: "person.2.fill")
                    .foregroundStyle(.primary)
            } header: {
                Text("Covela Forever perks")
            }

            Section {
                if store.activePlan?.isSubscription == true {
                    Button("Manage Subscription") {
                        showManageSubscriptions = true
                    }
                }
                Button("Restore Purchases") {
                    Task { await store.restore() }
                }
            } footer: {
                if store.activePlan?.isSubscription == true {
                    Text("Cancel anytime from Manage Subscription. Cancellation is handled by the App Store.")
                } else if store.activePlan == .lifetime {
                    Text("You have lifetime access. Nothing to cancel. 💞")
                }
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    private var statusText: String {
        guard store.isForeverUnlocked else { return "Not subscribed" }
        return store.activePlan?.displayName ?? "Active"
    }
}

#Preview {
    NavigationStack {
        SubscriptionDetailView(store: .shared)
    }
}
