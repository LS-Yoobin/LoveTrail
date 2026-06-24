import SwiftUI

struct DailyCheckInStreakView: View {
    let streak: Int
    let checkedInToday: Bool

    @State private var pulsed = false

    private var todayIndex: Int {
        if checkedInToday && streak == 0 { return 7 }
        if checkedInToday { return streak }
        return min(streak + 1, 7)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { index in
                dot(for: index)
            }
        }
        .frame(height: 20)
    }

    @ViewBuilder
    private func dot(for index: Int) -> some View {
        switch dotState(for: index) {
        case .completed:
            Circle()
                .fill(BabyTownTheme.accent)
                .frame(width: 14, height: 14)
        case .todayDone:
            Circle()
                .fill(BabyTownTheme.accent)
                .frame(width: 14, height: 14)
                .scaleEffect(pulsed ? 1.0 : 1.3)
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                        pulsed = true
                    }
                }
        case .todayPending:
            ZStack {
                Circle()
                    .stroke(BabyTownTheme.accent.opacity(0.4), lineWidth: 1.5)
                PetCoinIcon(size: 6)
                    .opacity(0.5)
            }
            .frame(width: 14, height: 14)
        case .future:
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                .frame(width: 14, height: 14)
        }
    }

    private enum DotState { case completed, todayDone, todayPending, future }

    private func dotState(for index: Int) -> DotState {
        if index < todayIndex { return .completed }
        if index == todayIndex { return checkedInToday ? .todayDone : .todayPending }
        return .future
    }
}

#Preview("Day 3, not yet checked in") {
    DailyCheckInStreakView(streak: 2, checkedInToday: false)
        .padding()
        .background(Color.black)
}

#Preview("Day 3, just checked in") {
    DailyCheckInStreakView(streak: 3, checkedInToday: true)
        .padding()
        .background(Color.black)
}

#Preview("Day 7 complete (streak reset)") {
    DailyCheckInStreakView(streak: 0, checkedInToday: true)
        .padding()
        .background(Color.black)
}

#Preview("No streak yet") {
    DailyCheckInStreakView(streak: 0, checkedInToday: false)
        .padding()
        .background(Color.black)
}
