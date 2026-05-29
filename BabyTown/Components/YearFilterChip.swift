import SwiftUI

struct YearFilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isSelected
                                ? AnyShapeStyle(BabyTownTheme.accentGradient)
                                : AnyShapeStyle(Color(white: 0.88))
                        )
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

