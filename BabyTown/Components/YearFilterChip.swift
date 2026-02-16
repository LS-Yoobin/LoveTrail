import SwiftUI

struct YearFilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : BabyTownTheme.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? AnyShapeStyle(BabyTownTheme.accentGradient) : AnyShapeStyle(Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : BabyTownTheme.textPrimary.opacity(0.3), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    HStack(spacing: 12) {
        YearFilterChip(title: "All", isSelected: true) {}
        YearFilterChip(title: "2025", isSelected: false) {}
        YearFilterChip(title: "2026", isSelected: false) {}
    }
    .padding()
    .background(BabyTownTheme.background)
}

