import SwiftUI

/// The five "Invite Partner to Town" perks. Shared by the paywall and the
/// Settings ▸ Subscription screen so the benefit copy lives in one place.
struct PartnerPerksList: View {

    var accent: Color = Color(red: 0.88, green: 0.22, blue: 0.38)

    private let perks: [(emoji: String, title: String, description: String)] = [
        ("☁️", "Private cloud backup", "Every memory safe forever — never lose a moment"),
        ("🔒", "Just the two of you", "A private vault no one else can ever see"),
        ("📸", "Add moments together", "You both upload to the same timeline, in real time"),
        ("💌", "Unlimited history", "Letters you write each other never expire"),
        ("📍", "Places you've been", "Watch your shared map of memories grow")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(perks, id: \.title) { perk in
                row(perk.emoji, perk.title, perk.description)
            }
        }
    }

    private func row(_ emoji: String, _ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 15))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(accent.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.88))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    PartnerPerksList()
        .padding()
}
