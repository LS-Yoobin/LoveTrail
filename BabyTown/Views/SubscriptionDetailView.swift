import SwiftUI
import StoreKit

/// Settings ▸ Subscription detail. Shows the partner perks again, the current
/// plan status, and links to manage (cancel via Apple) or restore.
struct SubscriptionDetailView: View {

    @ObservedObject var store: StoreManager

    @State private var showManageSubscriptions = false
    @State private var showPaywall = false
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
                PartnerPerksList(accent: accent)
                    .padding(.vertical, 4)
            } header: {
                Text("What's included")
            }

            Section {
                if store.isForeverUnlocked {
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
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("Invite your partner", systemImage: "heart.fill")
                            .foregroundStyle(accent)
                    }
                    Button("Restore Purchases") {
                        Task { await store.restore() }
                    }
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
        .fullScreenCover(isPresented: $showPaywall) {
            InvitePartnerPaywallView(
                store: store,
                onUnlock: { showPaywall = false },
                onDismiss: { showPaywall = false }
            )
        }
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
