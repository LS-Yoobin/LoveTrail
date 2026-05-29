import SwiftUI

struct MapPullHintView: View {
    let progress: CGFloat
    let isVisible: Bool
    let isNightMode: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 11, weight: .semibold))
            Text("Pull down to explore your map")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(isNightMode ? .white.opacity(0.55) : BabyTownTheme.textPrimary.opacity(0.45))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .opacity(isVisible ? Double(1 - min(progress * 2.5, 1)) : 0)
        .animation(.easeOut(duration: 0.2), value: isVisible)
    }
}
