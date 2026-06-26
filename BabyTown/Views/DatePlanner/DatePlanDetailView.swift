import SwiftUI
import PhotosUI

struct DatePlanDetailView: View {
    @Binding var plan: DatePlan
    let onPlanUpdated: (DatePlan) -> Void
    let onPlanDeleted: () -> Void

    @State private var isEditing = false
    @State private var isEditingTitle = false
    @State private var draftTitle = ""
    @State private var showNotesEditor = false
    @State private var showDateEditor = false
    @State private var showStopSearch = false
    @State private var showFullMap = false
    @State private var showAIToast = false
    @State private var showDeleteConfirmation = false
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var showDeleteStopID: UUID?
    @State private var selectedStop: ItineraryStop?
    @State private var selectedDayFilter: Int?
    @State private var draggingStopID: UUID?

    private var displayedStops: [ItineraryStop] {
        guard let selectedDayFilter else { return plan.itinerary }
        return plan.itinerary.filter { $0.day == selectedDayFilter }
    }

    private var geoStops: [ItineraryStop] {
        displayedStops.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var addStopDay: Int {
        selectedDayFilter ?? 1
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    if plan.numberOfDays > 1 {
                        dayFilterStrip
                    }
                    heroSection
                    dateStripSection
                    notesSection
                    if geoStops.count >= 2 {
                        mapSection
                    }
                    itinerarySection
                    deletePlanSection
                    Spacer(minLength: 80)
                }
            }
            .background(PlannerBackgroundView().ignoresSafeArea())

            aiFAB
                .padding(20)
        }
        .sheet(isPresented: $showNotesEditor) {
            NoteEditorSheet(initialText: plan.notes ?? "") { newNotes in
                var updated = plan
                updated.notes = newNotes
                updated.updatedAt = Date()
                DatePlanStore.shared.updatePlan(updated)
                plan = updated
                onPlanUpdated(updated)
            }
        }
        .sheet(isPresented: $showDateEditor) {
            PlannerDateEditorSheet(plan: $plan, onPlanUpdated: onPlanUpdated)
        }
        .sheet(isPresented: $showStopSearch) {
            StopSearchSheet(onAdd: { stop in
                var updated = plan
                updated.itinerary.append(stop)
                updated.updatedAt = Date()
                DatePlanStore.shared.updatePlan(updated)
                plan = updated
                onPlanUpdated(updated)
            }, nextOrder: plan.itinerary.count + 1, assignDay: addStopDay)
        }
        .fullScreenCover(isPresented: $showFullMap) {
            PlannerFullMapView(stops: displayedStops)
        }
        .sheet(item: $selectedStop) { stop in
            StopDetailSheet(stop: stop) {
                deleteStop(id: stop.id)
            }
        }
        .onChange(of: coverPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    var updated = plan
                    updated.coverPhotoData = data
                    updated.updatedAt = Date()
                    DatePlanStore.shared.updatePlan(updated)
                    await MainActor.run {
                        plan = updated
                        onPlanUpdated(updated)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showAIToast {
                Text("Coming soon")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(BabyTownTheme.textPrimary.opacity(0.85), in: Capsule())
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showAIToast = false }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showAIToast)
        .onChange(of: plan.id) { _, _ in
            selectedDayFilter = nil
        }
        .onChange(of: plan.numberOfDays) { _, newCount in
            if let selectedDayFilter, selectedDayFilter > newCount {
                self.selectedDayFilter = nil
            }
        }
        .confirmationDialog(
            "Delete this plan?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Plan", role: .destructive) {
                deletePlan()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove \"\(plan.title)\" and all of its stops. This cannot be undone.")
        }
    }

    // MARK: - Day filter

    private var dayFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                dayFilterPill(title: "Show All", isSelected: selectedDayFilter == nil) {
                    selectedDayFilter = nil
                }

                ForEach(1...plan.numberOfDays, id: \.self) { day in
                    dayFilterPill(title: "Day \(day)", isSelected: selectedDayFilter == day) {
                        selectedDayFilter = day
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func dayFilterPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : BabyTownTheme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(
                        isSelected
                            ? AnyShapeStyle(BabyTownTheme.accentGradient)
                            : AnyShapeStyle(BabyTownTheme.accentSoft)
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let data = plan.coverPhotoData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                } else {
                    BabyTownTheme.accentSoft
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "camera")
                                    .font(.system(size: 32))
                                    .foregroundStyle(BabyTownTheme.accent)
                                Text("Add cover photo")
                                    .font(.subheadline)
                                    .foregroundStyle(BabyTownTheme.accent)
                            }
                        }
                }
            }
            .frame(height: 280)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
            }

            // Title
            Group {
                if isEditingTitle {
                    TextField("Date title", text: $draftTitle, onCommit: {
                        let trimmed = draftTitle.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { plan.title = trimmed }
                        isEditingTitle = false
                        onPlanUpdated(plan)
                    })
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .submitLabel(.done)
                } else {
                    Text(plan.title)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .onTapGesture {
                            draftTitle = plan.title
                            isEditingTitle = true
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(height: 280)
        .overlay(alignment: .topTrailing) {
            ZStack(alignment: .topTrailing) {
                PhotosPicker(selection: $coverPickerItem, matching: .images) {
                    EmptyView()
                }
                .opacity(0)
                .frame(width: 0, height: 0)

                Button {
                    isEditing.toggle()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(16)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                coverPickerItem = nil
            }
        }
        .overlay(alignment: .topTrailing) {
            if isEditing {
                PhotosPicker(selection: $coverPickerItem, matching: .images) {
                    Color.clear
                        .frame(height: 280)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Date strip

    private var dateStripSection: some View {
        Button {
            showDateEditor = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(BabyTownTheme.accent)
                    .font(.body.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.dateRangeDetailLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BabyTownTheme.textPrimary)

                    if plan.numberOfDays > 1 {
                        Text("\(plan.numberOfDays) days")
                            .font(.caption)
                            .foregroundStyle(BabyTownTheme.textSecondary)
                    } else if let time = plan.time {
                        Text(time, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(BabyTownTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notes

    private var notesSection: some View {
        Button {
            showNotesEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                let hasNotes = !(plan.notes ?? "").isEmpty
                if hasNotes {
                    Text(plan.notes ?? "")
                        .font(.body)
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Add notes, vibes, or anything you're excited about")
                        .font(.body)
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(Color(.systemBackground).opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Itinerary

    private var itinerarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ITINERARY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.black)
                .kerning(1.2)
                .padding(.horizontal, 16)
                .padding(.top, 20)

            Button {
                showStopSearch = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add a stop")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BabyTownTheme.accent)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .overlay(
                    Capsule()
                        .strokeBorder(BabyTownTheme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                )
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            if !displayedStops.isEmpty {
                VStack(spacing: 0) {
                    ForEach(displayedStops) { stop in
                        itineraryStopRow(stop, showsDay: plan.numberOfDays > 1 && selectedDayFilter == nil)
                    }
                }
                .frame(height: CGFloat(displayedStops.count) * 80)
            }
        }
    }

    // MARK: - Delete plan

    private var deletePlanSection: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            Text("Delete Plan")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    // MARK: - Map

    private var mapSection: some View {
        PlannerMapView(stops: displayedStops)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .contentShape(Rectangle())
            .onTapGesture { showFullMap = true }
    }

    // MARK: - AI FAB

    private var aiFAB: some View {
        PlannerCircleButton(systemImage: "sparkles", size: 48, iconWeight: .semibold) {
            withAnimation { showAIToast = true }
        }
    }

    // MARK: - Helpers

    private func itineraryStopRow(_ stop: ItineraryStop, showsDay: Bool = false) -> some View {
        Button {
            selectedStop = stop
        } label: {
            ItineraryStopCard(
                stop: stop,
                itineraryStops: displayedStops,
                showsReorderHandle: true,
                dayLabel: showsDay ? "Day \(stop.day)" : nil
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .opacity(draggingStopID == stop.id ? 0.45 : 1)
        .draggable(stop.id.uuidString) {
            ItineraryStopCard(
                stop: stop,
                itineraryStops: displayedStops,
                showsReorderHandle: true,
                dayLabel: showsDay ? "Day \(stop.day)" : nil
            )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .onAppear { draggingStopID = stop.id }
                .onDisappear { draggingStopID = nil }
        }
        .dropDestination(for: String.self) { droppedIDs, _ in
            guard let sourceID = droppedIDs.first.flatMap(UUID.init(uuidString:)) else { return false }
            reorderStop(from: sourceID, toBefore: stop.id)
            draggingStopID = nil
            return true
        }
    }

    private func reorderStop(from sourceID: UUID, toBefore targetID: UUID) {
        let stops = displayedStops
        guard let fromIndex = stops.firstIndex(where: { $0.id == sourceID }),
              let toIndex = stops.firstIndex(where: { $0.id == targetID }),
              fromIndex != toIndex else { return }

        let destination = fromIndex < toIndex ? toIndex + 1 : toIndex
        moveStops(from: IndexSet(integer: fromIndex), to: destination)
    }

    private func moveStops(from source: IndexSet, to destination: Int) {
        var updated = plan

        if let selectedDayFilter {
            var dayIndices = updated.itinerary.indices.filter { updated.itinerary[$0].day == selectedDayFilter }
            var dayStops = dayIndices.map { updated.itinerary[$0] }
            dayStops.move(fromOffsets: source, toOffset: destination)
            for (offset, index) in dayIndices.enumerated() {
                updated.itinerary[index] = dayStops[offset]
            }
        } else {
            updated.itinerary.move(fromOffsets: source, toOffset: destination)
        }

        for i in updated.itinerary.indices { updated.itinerary[i].order = i + 1 }
        updated.updatedAt = Date()
        DatePlanStore.shared.updatePlan(updated)
        plan = updated
        onPlanUpdated(updated)
    }

    private func deleteStop(id: UUID) {
        var updated = plan
        updated.itinerary.removeAll { $0.id == id }
        for i in updated.itinerary.indices { updated.itinerary[i].order = i + 1 }
        updated.updatedAt = Date()
        DatePlanStore.shared.updatePlan(updated)
        plan = updated
        onPlanUpdated(updated)
    }

    private func deletePlan() {
        DatePlanStore.shared.deletePlan(id: plan.id)
        onPlanDeleted()
    }
}

