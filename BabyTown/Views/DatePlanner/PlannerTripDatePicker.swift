import SwiftUI

struct PlannerTripDatePicker: View {
    @Binding var selectedDates: Set<DateComponents>
    @Binding var showTime: Bool
    @Binding var selectedTime: Date

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Trip dates")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                PlannerRangeCalendarView(selectedDates: $selectedDates)
                    .frame(minHeight: 360)
            }

            if let rangeLabel = PlannerDateRange.rangeLabel(for: selectedDates) {
                Text(rangeLabel)
                    .font(.caption)
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle(isOn: $showTime) {
                Label("Add a time", systemImage: "clock")
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }
            .tint(BabyTownTheme.accent)

            if showTime {
                DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .tint(BabyTownTheme.accent)
            }
        }
        .onChange(of: selectedDates) { _, newValue in
            guard newValue.isEmpty else { return }
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            selectedDates = [PlannerDateRange.dateComponents(for: today, calendar: calendar)]
        }
    }
}

struct PlannerDateEditorSheet: View {
    @Binding var plan: DatePlan
    let onPlanUpdated: (DatePlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDates: Set<DateComponents> = []
    @State private var showTime = false
    @State private var selectedTime = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                PlannerTripDatePicker(
                    selectedDates: $selectedDates,
                    showTime: $showTime,
                    selectedTime: $selectedTime
                )
                .padding(20)
            }
            .navigationTitle("Edit date and time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BabyTownTheme.accent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            selectedDates = PlannerDateRange.dateComponents(for: plan)
            showTime = plan.time != nil
            selectedTime = plan.time ?? Date()
        }
        .onChange(of: selectedDates) { _, _ in
            applyDateSelection()
        }
        .onChange(of: showTime) { _, _ in
            applyTimeSelection()
        }
        .onChange(of: selectedTime) { _, _ in
            applyTimeSelection()
        }
    }

    private func applyDateSelection() {
        guard let span = PlannerDateRange.span(from: selectedDates) else { return }

        var updated = plan
        updated.date = span.start
        updated.numberOfDays = span.numberOfDays
        for index in updated.itinerary.indices where updated.itinerary[index].day > span.numberOfDays {
            updated.itinerary[index].day = span.numberOfDays
        }
        updated.updatedAt = Date()
        DatePlanStore.shared.updatePlan(updated)
        plan = updated
        onPlanUpdated(updated)
    }

    private func applyTimeSelection() {
        var updated = plan
        updated.time = showTime ? selectedTime : nil
        updated.updatedAt = Date()
        DatePlanStore.shared.updatePlan(updated)
        plan = updated
        onPlanUpdated(updated)
    }
}
