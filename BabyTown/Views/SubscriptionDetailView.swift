import SwiftUI
import StoreKit

/// Settings ▸ Subscription detail. Shows the partner perks again, the current
/// plan status, and links to manage (cancel via Apple) or restore.
struct SubscriptionDetailView: View {

    @ObservedObject var store: StoreManager

    @State private var showManageSubscriptions = false
    @State private var showInvite = false

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
                Label("Watch Together with your partner", systemImage: "tv.and.mediabox")
                    .foregroundStyle(.primary)
                Label("Unlimited important dates", systemImage: "calendar.badge.plus")
                    .foregroundStyle(.primary)
                Label("Invite your partner to your Cove", systemImage: "person.2.fill")
                    .foregroundStyle(.primary)
                Label("Unlock all pet skins and accessories", systemImage: "pawprint.fill")
                    .foregroundStyle(.primary)
                Label("Priority access to new features", systemImage: "sparkles")
                    .foregroundStyle(.primary)
            } header: {
                Text("Covela Forever perks")
            }

            Section {
                Button {
                    showInvite = true
                } label: {
                    Label("Invite your partner", systemImage: "heart.fill")
                        .foregroundStyle(accent)
                }
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
                    Text("You have lifetime access — there's nothing to cancel. 💞")
                }
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .fullScreenCover(isPresented: $showInvite) {
            InvitePartnerFlowView(onDone: { showInvite = false })
        }
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
