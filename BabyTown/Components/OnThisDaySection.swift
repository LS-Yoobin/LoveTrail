import SwiftUI

struct OnThisDaySection: View {
    let matches: [DaySection]
    let isNightMode: Bool
    let onCardTap: (DaySection) -> Void
    
    private func yearsAgo(from date: Date) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let years = calendar.dateComponents([.year], from: date, to: now).year ?? 0
        return years
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16))
                    .foregroundStyle(isNightMode ? .white.opacity(0.9) : .black.opacity(0.9))
                Text("On This Day")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isNightMode ? .white : .black)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            if matches.count == 1 {
                // Single card fills width
                OnThisDayCard(
                    section: matches[0],
                    yearsAgo: yearsAgo(from: matches[0].date),
                    isFullWidth: true,
                    onTap: { onCardTap(matches[0]) }
                )
                .padding(.horizontal, 20)
            } else {
                // Horizontal scroll for multiple cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(matches, id: \.id) { section in
                            OnThisDayCard(
                                section: section,
                                yearsAgo: yearsAgo(from: section.date),
                                onTap: { onCardTap(section) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
