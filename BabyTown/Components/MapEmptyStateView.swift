import SwiftUI

struct MapEmptyStateView: View {
    let selectedYear: Int
    let onScanPhotos: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 50))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.4))
                
                Text(selectedYear == 0 ? "No adventures yet." : "No adventures yet this year.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.7))
                
                Text(selectedYear == 0 ? "Scan your photos to find memories" : "Memories from \(selectedYear) will appear here")
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.5))

                
                Button(action: onScanPhotos) {
                    Text("Scan Photos")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(BabyTownTheme.accentGradient)
                        )
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(BabyTownTheme.background.opacity(0.95))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            )
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .allowsHitTesting(true)
    }
}

#Preview {
    MapEmptyStateView(selectedYear: 2024) {
        print("Scan photos tapped")
    }
}
