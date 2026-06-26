import SwiftUI

struct UpcomingDateSection: View {
    let plans: [DatePlan]
    let isNightMode: Bool
    let onPlanTap: (DatePlan) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16))
                    .foregroundStyle(isNightMode ? .white.opacity(0.9) : .black.opacity(0.9))
                Text("Upcoming Plans")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isNightMode ? .white : .black)
                Spacer()
            }
            .padding(.horizontal, 20)

            if plans.count == 1 {
                UpcomingDatePlanCard(plan: plans[0], isNightMode: isNightMode) {
                    onPlanTap(plans[0])
                }
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(plans) { plan in
                            UpcomingDatePlanCard(plan: plan, isNightMode: isNightMode) {
                                onPlanTap(plan)
                            }
                            .frame(width: 300)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

private struct UpcomingDatePlanCard: View {
    let plan: DatePlan
    let isNightMode: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                coverThumbnail

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isNightMode ? .white : BabyTownTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(plan.dateRangeLabel)
                        .font(.subheadline)
                        .foregroundStyle(isNightMode ? .white.opacity(0.75) : BabyTownTheme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isNightMode ? .white.opacity(0.6) : BabyTownTheme.textSecondary)
            }
            .padding(12)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        ZStack {
            if let data = plan.coverPhotoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
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
    }

    private var cardBackground: some ShapeStyle {
        if isNightMode {
            AnyShapeStyle(Color.white.opacity(0.12))
        } else {
            AnyShapeStyle(Color(.systemBackground).opacity(0.85))
        }
    }
}
