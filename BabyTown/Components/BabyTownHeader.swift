import SwiftUI
import Combine

struct BabyTownHeader: View {

    var onSettingsTap: (() -> Void)? = nil
    var onNotificationsTap: (() -> Void)? = nil
    var onMapTap: (() -> Void)? = nil
    var isNightMode: Bool = false
    var showsUnreadBadge: Bool = false

    var body: some View {
        ZStack {
            Image("BabyTownLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
            
            HStack {
                if let onSettingsTap = onSettingsTap {
                    Button {
                        onSettingsTap()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(isNightMode ? .white.opacity(0.9) : BabyTownTheme.textPrimary.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                
                Spacer()
                
                if let onMapTap = onMapTap {
                    Button {
                        onMapTap()
                    } label: {
                        Image(systemName: "map.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(isNightMode ? .white.opacity(0.9) : BabyTownTheme.textPrimary.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                
                Button {
                    onNotificationsTap?()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(isNightMode ? .white.opacity(0.9) : BabyTownTheme.textPrimary.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())

                        if showsUnreadBadge {
                            Circle()
                                .fill(BabyTownTheme.accent)
                                .frame(width: 8, height: 8)
                                .offset(x: -8, y: 10)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: 56)
    }
}

#Preview {
    ZStack {
        HomeBackgroundView(isNightMode: false)
        BabyTownHeader()
    }
}
