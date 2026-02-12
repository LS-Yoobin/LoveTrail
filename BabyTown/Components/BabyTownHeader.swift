import SwiftUI
import Combine

struct BabyTownHeader: View {
    
    var onSettingsTap: (() -> Void)? = nil

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
                            .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                
                Spacer()
            }
            .padding(.leading, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: 56)
        .background(BabyTownTheme.background.opacity(0.96))
    }
}

#Preview {
    BabyTownHeader()
}
