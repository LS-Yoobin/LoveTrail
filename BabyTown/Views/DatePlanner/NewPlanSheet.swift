import SwiftUI

struct NewPlanSheet: View {
    let onCreate: (DatePlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedDates: Set<DateComponents> = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return [calendar.dateComponents([.calendar, .year, .month, .day], from: today)]
    }()
    @State private var showTime = false
    @State private var selectedTime = Date()

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BabyTownTheme.textSecondary)
                        TextField("Name this date", text: $title)
                            .font(.body)
                            .padding(12)
                            .background(BabyTownTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                            .onChange(of: title) { _, new in
                                if new.count > 40 { title = String(new.prefix(40)) }
                            }
                    }

                    PlannerTripDatePicker(
                        selectedDates: $selectedDates,
                        showTime: $showTime,
                        selectedTime: $selectedTime
                    )
                }
                .padding(20)
            }
            .navigationTitle("New date plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Plan") {
                        guard let span = PlannerDateRange.span(from: selectedDates) else { return }
                        let userID = DataPersistenceManager.shared.loadUserEmail() ?? ""
                        let now = Date()
                        let plan = DatePlan(
                            id: UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: span.start,
                            numberOfDays: span.numberOfDays,
                            time: showTime ? selectedTime : nil,
                            notes: nil,
                            coverPhotoData: nil,
                            itinerary: [],
                            createdByUserID: userID,
                            createdAt: now,
                            updatedAt: now
                        )
                        DatePlanStore.shared.createPlan(plan)
                        onCreate(plan)
                        dismiss()
                    }
                    .disabled(!canCreate)
                    .fontWeight(.semibold)
                    .foregroundStyle(canCreate ? BabyTownTheme.accent : BabyTownTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Text("Home")
        .sheet(isPresented: .constant(true)) {
            NewPlanSheet(onCreate: { _ in })
        }
}
