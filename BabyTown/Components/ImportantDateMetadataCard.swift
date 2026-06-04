import SwiftUI

/// Important-date title and date on the light scrapbook moment page.
struct ImportantDateMetadataCard: View {
    let title: String
    let date: Date

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .multilineTextAlignment(.leading)
            }

            Text(dateFormatter.string(from: date))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black.opacity(0.65))
                .padding(.leading, 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        )
    }
}
