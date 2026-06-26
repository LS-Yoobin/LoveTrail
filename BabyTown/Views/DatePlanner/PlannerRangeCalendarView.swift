import SwiftUI
import UIKit

struct PlannerRangeCalendarView: UIViewRepresentable {
    @Binding var selectedDates: Set<DateComponents>

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedDates: $selectedDates)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar.current
        calendarView.locale = Locale.current
        calendarView.fontDesign = .rounded
        calendarView.tintColor = UIColor(BabyTownTheme.accent)

        let today = Calendar.current.startOfDay(for: Date())
        calendarView.availableDateRange = DateInterval(start: today, end: .distantFuture)

        let selection = UICalendarSelectionMultiDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selection
        context.coordinator.selection = selection
        context.coordinator.applySelection(selectedDates, animated: false)

        return calendarView
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.applySelection(selectedDates, animated: false)
    }

    final class Coordinator: NSObject, UICalendarSelectionMultiDateDelegate {
        @Binding var selectedDates: Set<DateComponents>
        weak var selection: UICalendarSelectionMultiDate?
        private var isApplyingProgrammaticSelection = false

        init(selectedDates: Binding<Set<DateComponents>>) {
            _selectedDates = selectedDates
        }

        func multiDateSelection(
            _ selection: UICalendarSelectionMultiDate,
            canSelectDate dateComponents: DateComponents
        ) -> Bool {
            guard let date = Calendar.current.date(from: dateComponents) else { return false }
            return Calendar.current.startOfDay(for: date) >= Calendar.current.startOfDay(for: Date())
        }

        func multiDateSelection(
            _ selection: UICalendarSelectionMultiDate,
            canDeselectDate dateComponents: DateComponents
        ) -> Bool {
            false
        }

        func multiDateSelection(
            _ selection: UICalendarSelectionMultiDate,
            didSelectDate dateComponents: DateComponents
        ) {
            guard !isApplyingProgrammaticSelection,
                  let tappedDate = Calendar.current.date(from: dateComponents) else { return }

            let updated = PlannerDateRange.selectionAfterTapping(tappedDate, currentSelection: selectedDates)
            selectedDates = updated
            applySelection(updated, animated: true)
        }

        func multiDateSelection(
            _ selection: UICalendarSelectionMultiDate,
            didDeselectDate dateComponents: DateComponents
        ) {
            guard !isApplyingProgrammaticSelection,
                  let tappedDate = Calendar.current.date(from: dateComponents) else { return }

            let updated = PlannerDateRange.selectionAfterTapping(tappedDate, currentSelection: selectedDates)
            selectedDates = updated
            applySelection(updated, animated: true)
        }

        func applySelection(_ dates: Set<DateComponents>, animated: Bool) {
            guard let selection else { return }

            let calendar = Calendar.current
            let target = dates.compactMap { components -> DateComponents? in
                guard let date = calendar.date(from: components) else { return nil }
                return PlannerDateRange.dateComponents(for: date, calendar: calendar)
            }

            let current = selection.selectedDates.compactMap { components -> DateComponents? in
                guard let date = calendar.date(from: components) else { return nil }
                return PlannerDateRange.dateComponents(for: date, calendar: calendar)
            }

            guard Set(current) != Set(target) else { return }

            isApplyingProgrammaticSelection = true
            defer { isApplyingProgrammaticSelection = false }

            selection.setSelectedDates(target, animated: animated)
        }
    }
}
