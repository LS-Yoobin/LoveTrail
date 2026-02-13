import SwiftUI

struct Scene3ChecklistView: View {
    @Binding var isInteractionComplete: Bool
    @State private var checkedItems: Set<Int> = [0, 1, 2, 3]
    
    let items = [
        (id: 0, icon: "key.fill", text: "G35 Keys"),
        (id: 1, icon: "wrench.and.screwdriver.fill", text: "Tools"),
        (id: 2, icon: "wallet.pass.fill", text: "Wallet"),
        (id: 3, icon: "person.fill", text: "BJ")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.indigo.opacity(0.15))
                    .frame(width: 300, height: 340)
                
                VStack(spacing: 20) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.indigo)
                        .padding(.bottom, 10)
                    
                    VStack(spacing: 14) {
                        ForEach(items, id: \.id) { item in
                            ChecklistItemRow(
                                icon: item.icon,
                                text: item.text,
                                isChecked: true
                            ) {
                                // Items are pre-checked and non-interactive
                            }
                        }
                    }
                }
            }
            .frame(height: 340)
        }
        .onAppear {
            isInteractionComplete = true
        }
    }
}

struct ChecklistItemRow: View {
    let icon: String
    let text: String
    let isChecked: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Heart checkbox
                ZStack {
                    Circle()
                        .stroke(isChecked ? StoryOnboardingTheme.primaryRed : Color.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if isChecked {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16))
                            .foregroundColor(StoryOnboardingTheme.primaryRed)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Item icon
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isChecked ? StoryOnboardingTheme.textDark : .gray.opacity(0.6))
                    .frame(width: 24)
                
                // Item text
                Text(text)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isChecked ? StoryOnboardingTheme.textDark : .gray.opacity(0.6))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isChecked ? Color.white.opacity(0.9) : Color.white.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isChecked ? StoryOnboardingTheme.primaryRed.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 260)
    }
}

#Preview {
    Scene3ChecklistView(isInteractionComplete: .constant(false))
        .padding()
        .background(StoryOnboardingTheme.backgroundBlush)
}
