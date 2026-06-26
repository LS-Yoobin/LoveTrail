import SwiftUI

struct DatePlannerHubView: View {
    var initialPlanID: UUID? = nil
    let onUnlockForever: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: HubTab = .plans
    @State private var plans: [DatePlan] = []
    @State private var selectedPlanID: UUID?
    @State private var showNewPlan = false
    @State private var vaultedPlan: DatePlan?

    private enum HubTab { case plans, log }

    private var selectedPlan: Binding<DatePlan>? {
        guard let id = selectedPlanID,
              let idx = plans.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { plans[idx] },
            set: { plans[idx] = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar

                Divider()

                Group {
                    if selectedTab == .plans {
                        plansTab
                    } else {
                        logTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(PlannerBackgroundView().ignoresSafeArea())
            .navigationTitle("Date Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                        .foregroundStyle(BabyTownTheme.accent)
                }
                ToolbarItem(placement: .principal) {
                    if selectedTab == .plans, plans.count > 1, let selectedPlanID {
                        Menu {
                            ForEach(plans) { plan in
                                Button {
                                    self.selectedPlanID = plan.id
                                    DatePlanStore.shared.setLastSelectedPlanID(plan.id)
                                } label: {
                                    if plan.id == selectedPlanID {
                                        Label(plan.title, systemImage: "checkmark")
                                    } else {
                                        Text(plan.title)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(plans.first(where: { $0.id == selectedPlanID })?.title ?? "Date Planner")
                                    .font(.headline)
                                    .foregroundStyle(BabyTownTheme.textPrimary)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.black)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PlannerCircleButton(systemImage: "plus", size: 36, style: .glass) {
                        showNewPlan = true
                    }
                }
            }
        }
        .sheet(isPresented: $showNewPlan) {
            NewPlanSheet { newPlan in
                plans.append(newPlan)
                selectedPlanID = newPlan.id
                selectedTab = .plans
                DatePlanStore.shared.setLastSelectedPlanID(newPlan.id)
            }
        }
        .sheet(item: $vaultedPlan) { _ in
            PlanVaultSheet(onUnlockForever: {
                vaultedPlan = nil
                onUnlockForever()
            })
        }
        .onAppear { loadPlans() }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Upcoming", tab: .plans)
            tabButton("Old Plans", tab: .log)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func tabButton(_ title: String, tab: HubTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedTab == tab ? BabyTownTheme.accent : Color(.systemGray3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    if selectedTab == tab {
                        Rectangle()
                            .fill(BabyTownTheme.accent)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plans tab

    private var plansTab: some View {
        VStack(spacing: 0) {
            if plans.isEmpty {
                emptyPlansState
            } else if let binding = selectedPlan {
                DatePlanDetailView(plan: binding, onPlanUpdated: { updated in
                    if let idx = plans.firstIndex(where: { $0.id == updated.id }) {
                        plans[idx] = updated
                    }
                }, onPlanDeleted: {
                    let deletedID = selectedPlanID
                    plans.removeAll { $0.id == deletedID }
                    let next = plans.sorted { $0.createdAt > $1.createdAt }.first
                    selectedPlanID = next?.id
                    DatePlanStore.shared.setLastSelectedPlanID(next?.id)
                })
            }
        }
    }

    private var emptyPlansState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.6))

            VStack(spacing: 8) {
                Text("Plan your next date")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.black)
                Text("Tap the + button in the top right to create your first date")
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showNewPlan = true
            } label: {
                Label("New Date Plan", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(BabyTownTheme.accentGradient, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Log tab

    private var logTab: some View {
        List {
            ForEach(plans.sorted { $0.createdAt > $1.createdAt }) { plan in
                logRow(plan)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onTapGesture {
                        if plan.isVaulted {
                            vaultedPlan = plan
                        } else {
                            selectedPlanID = plan.id
                            selectedTab = .plans
                            DatePlanStore.shared.setLastSelectedPlanID(plan.id)
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private func logRow(_ plan: DatePlan) -> some View {
        HStack(spacing: 12) {
            // Cover thumbnail
            ZStack {
                if plan.isVaulted {
                    Rectangle()
                        .fill(BabyTownTheme.accentSoft)
                        .overlay(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(BabyTownTheme.accent)
                        }
                } else if let data = plan.coverPhotoData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .saturation(plan.isPast ? 0.4 : 1.0)
                } else {
                    BabyTownTheme.accentSoft
                        .overlay {
                            Image(systemName: "calendar")
                                .foregroundStyle(BabyTownTheme.accent.opacity(0.5))
                        }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(plan.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(plan.isPast ? BabyTownTheme.textSecondary : BabyTownTheme.textPrimary)
                        .lineLimit(1)

                    if plan.isVaulted {
                        Text("Locked")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BabyTownTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BabyTownTheme.accentSoft, in: Capsule())
                    } else if plan.isPast {
                        Text("Past")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BabyTownTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5), in: Capsule())
                    }
                }

                Text(plan.dateRangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(BabyTownTheme.textSecondary)

                if !plan.itinerary.isEmpty {
                    Text("\(plan.itinerary.count) stop\(plan.itinerary.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(BabyTownTheme.accent)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BabyTownTheme.textSecondary)
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func loadPlans() {
        plans = DatePlanStore.shared.allPlans()
        if let initialPlanID, plans.contains(where: { $0.id == initialPlanID }) {
            selectedPlanID = initialPlanID
            selectedTab = .plans
            DatePlanStore.shared.setLastSelectedPlanID(initialPlanID)
            return
        }
        let lastID = DatePlanStore.shared.lastSelectedPlanID
        if let lastID, plans.contains(where: { $0.id == lastID }) {
            selectedPlanID = lastID
        } else {
            selectedPlanID = plans.sorted { $0.createdAt > $1.createdAt }.first?.id
        }
    }
}
