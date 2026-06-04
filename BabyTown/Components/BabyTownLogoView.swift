import SwiftUI

struct BabyTownLogoView: View {
    
    var size: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            BabyTownTheme.accent.opacity(0.10),
                            BabyTownTheme.accent.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Heart trails (multiple hearts getting smaller)
            ForEach(0..<3) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.35 * (1.0 - CGFloat(index) * 0.25)))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                BabyTownTheme.accent.opacity(1.0 - CGFloat(index) * 0.3),
                                BabyTownTheme.accentDeep.opacity(1.0 - CGFloat(index) * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(
                        x: CGFloat(index) * size * 0.08,
                        y: CGFloat(index) * size * 0.08
                    )
                    .blur(radius: CGFloat(index) * 0.5)
            }
            
            // Main heart
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            BabyTownTheme.accent,
                            BabyTownTheme.accentDeep
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: BabyTownTheme.accentDeep.opacity(0.4), radius: 8, y: 4)
        }
    }
}

// MARK: - App Icon Generator View

struct AppIconGeneratorView: View {
    
    var body: some View {
        VStack(spacing: 40) {
            Text("BabyTown App Icon")
                .font(.title)
                .fontWeight(.bold)
            
            // 1024x1024 App Store icon
            VStack(spacing: 8) {
                iconView(size: 300)
                Text("1024x1024 App Store")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Various sizes
            HStack(spacing: 20) {
                VStack {
                    iconView(size: 120)
                    Text("180x180")
                        .font(.caption2)
                }
                
                VStack {
                    iconView(size: 80)
                    Text("120x120")
                        .font(.caption2)
                }
                
                VStack {
                    iconView(size: 60)
                    Text("87x87")
                        .font(.caption2)
                }
            }
        }
        .padding(40)
        .background(Color(.systemBackground))
    }
    
    private func iconView(size: CGFloat) -> some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: size * 0.2237)
                .fill(
                    LinearGradient(
                        colors: [
                            BabyTownTheme.accent.opacity(0.10),
                            BabyTownTheme.accent.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Heart trails
            ForEach(0..<4) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.32 * (1.0 - CGFloat(index) * 0.2)))
                    .foregroundStyle(
                        BabyTownTheme.accentDeep.opacity(0.9 - CGFloat(index) * 0.2)
                    )
                    .offset(
                        x: CGFloat(index) * size * 0.06,
                        y: CGFloat(index) * size * 0.06
                    )
                    .blur(radius: CGFloat(index) * 0.8)
            }
            
            // Main heart
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            BabyTownTheme.accent,
                            BabyTownTheme.accentDeep
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: BabyTownTheme.accentDeep.opacity(0.5), radius: size * 0.03, y: size * 0.015)
        }
        .frame(width: size, height: size)
    }
}

#Preview("Logo") {
    VStack(spacing: 40) {
        BabyTownLogoView(size: 120)
        BabyTownLogoView(size: 80)
        BabyTownLogoView(size: 60)
    }
    .padding()
}

#Preview("App Icon Generator") {
    AppIconGeneratorView()
}
